# Local Simplified Chinese OCR of generated labels; no window capture or game input.
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'marker-core.ps1');. (Join-Path $root 'live-core.ps1')
Initialize-MarkerOcr;Add-Type -AssemblyName System.Drawing;Add-Type -AssemblyName System.Windows.Forms
Add-Type -Path (Join-Path $root 'marker-native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
$scratch=Join-Path $root 'work/label-ocr';[IO.Directory]::CreateDirectory($scratch)|Out-Null;$checks=0
foreach($key in @($MarkerStatNames.Keys|Where-Object{$_-notin @('HP%','ATK%','DEF%')})){
    $label=$MarkerStatNames[$key];$b=New-Object Drawing.Bitmap(415,60);$g=[Drawing.Graphics]::FromImage($b)
    $g.Clear([Drawing.Color]::FromArgb(68,59,47));$font=New-Object Drawing.Font('Microsoft YaHei',22,[Drawing.FontStyle]::Regular,[Drawing.GraphicsUnit]::Pixel);$brush=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(242,177,80));$g.DrawString($label,$font,$brush,10,8);$g.Dispose();$font.Dispose();$brush.Dispose()
    $file=Join-Path $scratch ($checks.ToString()+'-raw.png');$b.Save($file,[Drawing.Imaging.ImageFormat]::Png);$lines=Read-MarkerOcr $file;$actual=Get-LiveStatLabel (($lines|ForEach-Object{$_.text})-join'')
    $processed=[RelicNative]::NumericOcrImage($b,140);$b.Dispose()
    try{if(-not$actual){$file=Join-Path $scratch ($checks.ToString()+'.png');$processed.Save($file,[Drawing.Imaging.ImageFormat]::Png);$lines=Read-MarkerOcr $file;$actual=Get-LiveStatLabel (($lines|ForEach-Object{$_.text})-join'')};if($actual-ne$key){throw ('Label OCR mismatch: '+$label+' => '+$actual+' text: '+(($lines|ForEach-Object{$_.text})-join' '))};$checks++}finally{$processed.Dispose()}
}
$data=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $root 'source/data.json')))
$subs=@(@{text='暴击率 3.2%'},@{text='攻击力 4.3%'},@{text='速度 2'})
foreach($entry in @(@('Head','HP'),@('Hands','ATK'))){$part=$entry[0];$panel=@(@{text=$data.pieceNames.'117'.$part;y=20},@{text='+0';y=100},@{text=$data.sets.'117'.name;y=400});$r=ConvertFrom-LivePanel $panel $subs $data 336 -NumbersPending -MainLines @();if($r.mainstat-ne$entry[1]){throw 'Fixed main-stat fallback failed'};$checks++}
$panel=@(@{text=$data.pieceNames.'117'.Body;y=20},@{text='+0';y=100},@{text=$data.sets.'117'.name;y=400});$rejected=$false;try{ConvertFrom-LivePanel $panel $subs $data 336 -NumbersPending -MainLines @()}catch{$rejected=$true};if(-not$rejected){throw 'Ambiguous body main was guessed'};$checks++
Write-Output ('Generated Chinese label OCR and fixed-main fallback passed: '+$checks+' checks; actual game input: 0.')
