# Pure matching, geometry, OCR and manifest validation shared by worker/tests.
$script:MarkerStatNames = @{
    'HP'='生命值';'HP%'='生命值';'ATK'='攻击力';'ATK%'='攻击力';'DEF'='防御力';'DEF%'='防御力';'SPD'='速度';
    'CRIT Rate'='暴击率';'CRIT DMG'='暴击伤害';'Effect Hit Rate'='效果命中';'Effect RES'='效果抵抗';'Break Effect'='击破特攻';
    'Energy Regeneration Rate'='能量恢复效率';'Outgoing Healing Boost'='治疗量加成';'Physical DMG Boost'='物理属性伤害提高';
    'Fire DMG Boost'='火属性伤害提高';'Ice DMG Boost'='冰属性伤害提高';'Lightning DMG Boost'='雷属性伤害提高';
    'Wind DMG Boost'='风属性伤害提高';'Quantum DMG Boost'='量子属性伤害提高';'Imaginary DMG Boost'='虚数属性伤害提高'
}
function Normalize-MarkerText([string]$Text) {
    return $Text.Normalize([System.Text.NormalizationForm]::FormKC).Replace('％','%').Replace('。','.').Replace('，','.').Replace('·','.').Replace('＋','+').Replace('：',':') -replace '\s',''
}
function Get-DisplayValue([string]$Stat,[double]$Value) {
    if ($Stat -in @('HP','ATK','DEF','SPD')) { return [Math]::Floor($Value + 0.00001).ToString('0',[Globalization.CultureInfo]::InvariantCulture) }
    return ([Math]::Floor($Value*10 + 0.00001)/10).ToString('0.0',[Globalization.CultureInfo]::InvariantCulture)
}
function Get-StatObservation([string]$Text) {
    $t=Normalize-MarkerText $Text
    $keys=@($script:MarkerStatNames.Keys | Sort-Object { $script:MarkerStatNames[$_].Length } -Descending)
    foreach($key in $keys) {
        $label=$script:MarkerStatNames[$key]
        if ($t -match ([regex]::Escape($label)+'[+:]?([0-9]+(?:\.[0-9]+)?)(%?)')) {
            $num=$Matches[1];$pct=$Matches[2] -eq '%'
            $actual=$key
            if ($label -in @('生命值','攻击力','防御力')) {$actual=@{'生命值'='HP';'攻击力'='ATK';'防御力'='DEF'}[$label];if($pct){$actual+='%' } }
            elseif ($key -ne 'SPD' -and -not $pct) { return $null }
            return @{stat=$actual;value=[double]::Parse($num,[Globalization.CultureInfo]::InvariantCulture);text=$t}
        }
    }
    return $null
}
function Test-ObservedStats($Observed,$Expected) {
    if (@($Observed).Count -ne @($Expected).Count) { return $false }
    foreach($s in $Expected) {
        $found=@($Observed | Where-Object { $_.stat -eq $s.stat })
        if($found.Count -ne 1){return $false}
        $expectedValue=[double]::Parse((Get-DisplayValue $s.stat $s.value),[Globalization.CultureInfo]::InvariantCulture)
        if([Math]::Abs($found[0].value-$expectedValue) -gt 0.011){return $false}
    }
    return $true
}
function Find-MarkerMatch($Candidates,$PanelLines,$SubstatLines,[double]$SubstatsTop) {
    $observed=@();foreach($line in $SubstatLines){$s=Get-StatObservation $line.text;if($null -ne $s){$observed+=,$s}}
    if($observed.Count -lt 3 -or $observed.Count -gt 4){return $null}
    $full=Normalize-MarkerText (($PanelLines | ForEach-Object {$_.text}) -join '')
    $headLines=@($PanelLines | Where-Object {$_.y -lt $SubstatsTop})
    $head=Normalize-MarkerText (($headLines | ForEach-Object {$_.text}) -join '')
    $foundCandidates=@()
    foreach($candidate in $Candidates){
        if($candidate.pieceName -and -not $full.Contains((Normalize-MarkerText $candidate.pieceName))){continue}
        if(-not $full.Contains((Normalize-MarkerText $candidate.setName))){continue}
        if($head -notmatch ('(?<![0-9])\+'+[regex]::Escape([string]$candidate.enhance)+'(?![0-9])')){continue}
        $mainOk=$false
        foreach($line in $headLines){$ob=Get-StatObservation $line.text;if($ob -and (Test-ObservedStats @($ob) @($candidate.main))){$mainOk=$true;break}}
        if(-not $mainOk){continue}
        $visual=if($candidate.visualSubstats){$candidate.visualSubstats}else{$candidate.substats}
        if(Test-ObservedStats $observed $visual){$foundCandidates+=,$candidate}
    }
    # Fingerprint duplicates are consolidated before execution. Any ambiguity stops a match.
    if($foundCandidates.Count -eq 1){return $foundCandidates[0]}
    return $null
}
function New-MarkerRect($A,$B) {
    $x=[int][Math]::Min($A[0],$B[0]);$y=[int][Math]::Min($A[1],$B[1]);
    return @{x=$x;y=$y;width=[int][Math]::Abs($A[0]-$B[0]);height=[int][Math]::Abs($A[1]-$B[1])}
}
function Test-MarkerCalibration($c) {
    if($c.schema -ne 'hsr-marker-calibration-v1'){throw '校准文件版本不匹配，请重新校准。'}
    $g=$c.grid
    if($g.cols -lt 2 -or $g.cols -gt 18 -or $g.rows -lt 2 -or $g.rows -gt 12 -or $g.dx -lt 25 -or $g.dy -lt 30){throw '遗器网格校准无效，请重新校准。'}
    foreach($r in @($c.panel,$c.substats,$c.anchor,$c.discardRect,$c.unlockRect,$c.rarityRect)){
        if($r.width -lt 8 -or $r.height -lt 8 -or $r.x -lt 0 -or $r.y -lt 0 -or ($r.x+$r.width) -gt $c.width -or ($r.y+$r.height) -gt $c.height){throw '校准区域超出窗口或过小。'}
    }
    $lastX=$g.x+($g.cols-1)*$g.dx;$lastY=$g.y+($g.rows-1)*$g.dy
    if($lastX -ge $c.width -or $lastY -ge $c.height){throw '遗器格子超出窗口。'}
    if($lastY -ge $c.height*0.9){throw '最后一行格子中心不能落在底部操作栏。'}
    $gridRight=$lastX+$g.dx/3
    if($c.discardPoint[0] -le $gridRight -or $c.unlockPoint[0] -le $gridRight){throw '弃置及锁定按钮需要位于右侧详情面板，不能落在网格或底部功能栏。'}
    if($c.discardPoint[1] -ge $c.height*0.78 -or $c.unlockPoint[1] -ge $c.height*0.78){throw '按钮位置不能位于底部分解、强化或确认功能区。'}
    if($c.rarityRect.width -gt $g.dx*0.95 -or $c.rarityRect.height -gt $g.dy*0.3 -or [Math]::Abs(($c.rarityRect.x+$c.rarityRect.width/2)-$g.x) -gt $g.dx*0.4 -or [Math]::Abs(($c.rarityRect.y+$c.rarityRect.height/2)-$g.y) -gt $g.dy*0.55){throw '五星图案区域必须只框选第一格内的五颗星。'}
    if($c.substats.x -lt $c.panel.x -or $c.substats.y -lt $c.panel.y -or ($c.substats.x+$c.substats.width) -gt ($c.panel.x+$c.panel.width) -or ($c.substats.y+$c.substats.height) -gt ($c.panel.y+$c.panel.height)){throw '副属性框必须位于详情框内。'}
    return $true
}
function Test-UnmarkedVisual($CurrentDiscard,$CurrentUnlock,$ReferenceDiscard,$ReferenceUnlock) {
    $baseline=[RelicNative]::RedPixels($ReferenceDiscard)
    return ([RelicNative]::Difference($CurrentUnlock,$ReferenceUnlock) -le 8 -and [RelicNative]::RedPixels($CurrentDiscard) -le $baseline+4 -and [RelicNative]::Difference($CurrentDiscard,$ReferenceDiscard) -le 12)
}
function Test-MarkedVisual($CurrentDiscard,$ReferenceDiscard) {
    return [RelicNative]::RedPixels($CurrentDiscard) -gt ([RelicNative]::RedPixels($ReferenceDiscard)+6)
}
function Initialize-MarkerOcr {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    [Windows.Media.Ocr.OcrEngine,Windows.Foundation,ContentType=WindowsRuntime] | Out-Null
    [Windows.Globalization.Language,Windows.Globalization,ContentType=WindowsRuntime] | Out-Null
    [Windows.Storage.StorageFile,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
    [Windows.Storage.FileAccessMode,Windows.Storage,ContentType=WindowsRuntime] | Out-Null
    [Windows.Storage.Streams.IRandomAccessStream,Windows.Storage.Streams,ContentType=WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.BitmapDecoder,Windows.Foundation,ContentType=WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.SoftwareBitmap,Windows.Foundation,ContentType=WindowsRuntime] | Out-Null
    $language=@([Windows.Media.Ocr.OcrEngine]::AvailableRecognizerLanguages | Where-Object {$_.LanguageTag -like 'zh*'}) | Select-Object -First 1
    if(-not $language){throw '本机没有中文 OCR 语言包。请在 Windows 语言设置安装简体中文的文字识别组件后重试。'}
    $script:MarkerOcr=[Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($language)
    $script:MarkerAsTask=[System.WindowsRuntimeSystemExtensions].GetMethods() | Where-Object {$_.Name -eq 'AsTask' -and $_.IsGenericMethod -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1'} | Select-Object -First 1
}
function Wait-MarkerWinRT($Operation,[Type]$ResultType) {
    $task=$script:MarkerAsTask.MakeGenericMethod($ResultType).Invoke($null,@($Operation))
    if(-not $task.Wait(15000)){throw '本机 OCR 等待超时，已停止。'}
    return $task.Result
}
function Read-MarkerOcr([string]$File) {
    $storage=Wait-MarkerWinRT ([Windows.Storage.StorageFile]::GetFileFromPathAsync($File)) ([Windows.Storage.StorageFile])
    $stream=Wait-MarkerWinRT ($storage.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
    $bitmap=$null
    try {
        $decoder=Wait-MarkerWinRT ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
        $bitmap=Wait-MarkerWinRT ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
        $recognition=Wait-MarkerWinRT ($script:MarkerOcr.RecognizeAsync($bitmap)) ([Windows.Media.Ocr.OcrResult])
        $lines=@();foreach($line in $recognition.Lines){$words=@($line.Words);if($words.Count){$y=($words | ForEach-Object {$_.BoundingRect.Y} | Measure-Object -Minimum).Minimum;$lines+=,@{text=$line.Text;y=[double]$y}}}
        return ,$lines
    } finally {if($null -ne $bitmap){$bitmap.Dispose()};$stream.Dispose()}
}
