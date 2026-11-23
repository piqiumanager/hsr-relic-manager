param([ValidateSet('Calibrate','Run')][string]$Mode,[string]$JobDirectory,[string]$PlanPath,[switch]$PreviewOnly,[string]$DataRoot = '')
$ErrorActionPreference='Stop'
$base=$PSScriptRoot
$encoding=New-Object Text.UTF8Encoding($false)
$configDir=Join-Path $(if($DataRoot){$DataRoot}else{$base}) 'marker-config'
$statusPath=Join-Path $JobDirectory 'status.json'
$stopPath=Join-Path $JobDirectory 'stop'
$calibrationPath=Join-Path $configDir 'calibration.json'
$currentState=@{state='starting';mode=$Mode;scanned=0;matched=0;marked=0;skipped=0;page=0;message='正在准备本机识别…';preview=[bool]$PreviewOnly;events=@()}
function Save-State([string]$State,[string]$Message){
    $script:currentState.state=$State;$script:currentState.message=$Message;$script:currentState.updatedAt=(Get-Date).ToUniversalTime().ToString('o')
    $json=ConvertTo-Json -InputObject $script:currentState -Depth 20 -Compress
    $temp=$statusPath+'.tmp';[IO.File]::WriteAllText($temp,$json,$encoding);Move-Item -LiteralPath $temp -Destination $statusPath -Force
}
function Check-Stop {
    if((Test-Path -LiteralPath $stopPath) -or [RelicNative]::StopPressed()){throw (New-Object OperationCanceledException('已停止自动标记。'))}
}
function Crop-Region($Bitmap,$Rect){return [RelicNative]::Crop($Bitmap,[int]$Rect.x,[int]$Rect.y,[int]$Rect.width,[int]$Rect.height)}
function Check-Anchor($Bitmap,$Config,$Reference){$crop=Crop-Region $Bitmap $Config.anchor;try{if([RelicNative]::Difference($crop,$Reference) -gt 18){throw '背包界面标题与校准时不同，可能出现弹窗或离开背包，已停止。'}}finally{$crop.Dispose()}}
function Read-Details($Bitmap,$Config){
    $panel=Crop-Region $Bitmap $Config.panel;$sub=Crop-Region $Bitmap $Config.substats
    try{
        $panelFile=Join-Path $JobDirectory 'panel.png';$subFile=Join-Path $JobDirectory 'substats.png'
        $panel.Save($panelFile,[Drawing.Imaging.ImageFormat]::Png);$sub.Save($subFile,[Drawing.Imaging.ImageFormat]::Png)
        return @{panel=(Read-MarkerOcr $panelFile);subs=(Read-MarkerOcr $subFile)}
    }finally{$panel.Dispose();$sub.Dispose()}
}
try {
    [IO.Directory]::CreateDirectory($JobDirectory)|Out-Null
    [IO.Directory]::CreateDirectory($configDir)|Out-Null
    Save-State 'starting' '正在准备游戏内标记…'
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -Path (Join-Path $base 'marker-native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
    . (Join-Path $base 'marker-core.ps1')
    [RelicNative]::SetProcessDPIAware()|Out-Null
    Initialize-MarkerOcr
    $window=[RelicNative]::FindGame()
    [RelicNative]::Activate($window)
    if($Mode -eq 'Calibrate'){
        Save-State 'calibrating' '请在弹出的校准窗口中，依次点击提示位置。Esc 取消。'
        $bitmap=[RelicNative]::Capture($window)
        try{
            $steps=@('点左上角第一件遗器的中心','点同一行第二件遗器的中心','点第二行第一件遗器的中心','点最后一整行最右侧完整遗器的中心','点右侧详情面板左上角（含遗器名称和等级）','点右侧详情面板右下角（需包含套装名称）','点副属性文字区域左上角（不含主属性）','点副属性文字区域右下角（包含所有副属性）','点右侧未锁定图标中心','点右侧未弃置的垃圾桶图标中心','点左上方固定背包标题区域左上角','点该固定标题区域右下角（避开数量、时钟）','点第一格中五颗金色星星区域的左上角（只框星星）','点五颗星星区域的右下角（不包含物品图片或边框）')
            $p=[RelicNative]::Calibrate($bitmap,$steps,$stopPath)
            $dx=$p[1][0]-$p[0][0];$dy=$p[2][1]-$p[0][1]
            if($dx -le 0 -or $dy -le 0){throw '格子位置顺序不正确，请重新校准。'}
            $cols=[int][Math]::Round(($p[3][0]-$p[0][0])/$dx)+1;$rows=[int][Math]::Round(($p[3][1]-$p[0][1])/$dy)+1
            if([Math]::Abs(($p[3][0]-$p[0][0])-($cols-1)*$dx) -gt $dx*0.18 -or [Math]::Abs(($p[3][1]-$p[0][1])-($rows-1)*$dy) -gt $dy*0.18){throw '格子中心没有对齐，请重新校准。'}
            $iconSize=[int][Math]::Max(20,[Math]::Min(36,$window.Height/32));$half=[int][Math]::Floor($iconSize/2)
            $config=@{schema='hsr-marker-calibration-v1';width=$window.Width;height=$window.Height;grid=@{x=$p[0][0];y=$p[0][1];dx=$dx;dy=$dy;cols=$cols;rows=$rows};panel=(New-MarkerRect $p[4] $p[5]);substats=(New-MarkerRect $p[6] $p[7]);unlockPoint=$p[8];discardPoint=$p[9];unlockRect=@{x=$p[8][0]-$half;y=$p[8][1]-$half;width=$iconSize;height=$iconSize};discardRect=@{x=$p[9][0]-$half;y=$p[9][1]-$half;width=$iconSize;height=$iconSize};anchor=(New-MarkerRect $p[10] $p[11]);createdAt=(Get-Date).ToUniversalTime().ToString('o')}
            $config.rarityRect=New-MarkerRect $p[12] $p[13]
            Test-MarkerCalibration $config|Out-Null
            $discard=Crop-Region $bitmap $config.discardRect
            try{if([RelicNative]::RedPixels($discard) -gt $iconSize){throw '校准用的遗器可能已经弃置，请选一件未弃置的遗器重新校准。'};$discard.Save((Join-Path $configDir 'unmarked.png'),[Drawing.Imaging.ImageFormat]::Png)}finally{$discard.Dispose()}
            foreach($pair in @(@('unlockRect','unlocked.png'),@('anchor','anchor.png'))){$crop=Crop-Region $bitmap $config[$pair[0]];try{$crop.Save((Join-Path $configDir $pair[1]),[Drawing.Imaging.ImageFormat]::Png)}finally{$crop.Dispose()}}
            $starCrop=Crop-Region $bitmap $config.rarityRect;try{$starCrop.Save((Join-Path $configDir 'five-stars.png'),[Drawing.Imaging.ImageFormat]::Png)}finally{$starCrop.Dispose()}
            [IO.File]::WriteAllText($calibrationPath,(ConvertTo-Json $config -Depth 20),$encoding)
            Save-State 'complete' '位置校准已保存。请把背包滚动到顶部，再回到工具点击开始标记。'
        }finally{$bitmap.Dispose()}
        exit 0
    }
    if(-not (Test-Path -LiteralPath $calibrationPath)){throw '请先完成首次位置校准。'}
    $config=ConvertFrom-Json ([IO.File]::ReadAllText($calibrationPath,$encoding));Test-MarkerCalibration $config|Out-Null
    if($window.Width -ne $config.width -or $window.Height -ne $config.height){throw '游戏分辨率与校准时不同，请重新校准。'}
    $plan=ConvertFrom-Json ([IO.File]::ReadAllText($PlanPath,$encoding))
    if($plan.schema -ne 'hsr-marker-plan-v1' -or $plan.allowSalvage -ne $false -or -not $plan.candidates.Count){throw '标记清单格式不正确。'}
    $pending=@{};foreach($c in $plan.candidates){$pending[$c.key]=[int]$c.count}
    $script:currentState.total=[int]$plan.total
    $unmarked=New-Object Drawing.Bitmap((Join-Path $configDir 'unmarked.png'))
    $unlocked=New-Object Drawing.Bitmap((Join-Path $configDir 'unlocked.png'))
    $anchor=New-Object Drawing.Bitmap((Join-Path $configDir 'anchor.png'))
    $fiveStars=New-Object Drawing.Bitmap((Join-Path $configDir 'five-stars.png'))
    $baselineRed=[RelicNative]::RedPixels($unmarked)
    $grid=$config.grid;$lastSignature='';$samePages=0;$started=Get-Date;$previewed=@{}
    Save-State 'running' '已开始遍历背包。请勿操作鼠标；按 F8 或工具中的停止按钮可停止。'
    try{
      for($page=0;$page -lt 1800;$page++){
        Check-Stop;$script:currentState.page=$page+1
        $signature=@();$matchedThisPage=0;$validCells=0
        for($row=0;$row -lt $grid.rows;$row++){
          for($col=0;$col -lt $grid.cols;$col++){
            Check-Stop
            if(((Get-Date)-$started).TotalMinutes -gt 90){throw '运行已达 90 分钟，已停止。可以稍后继续。'}
            $before=[RelicNative]::Capture($window)
            try{
                Check-Anchor $before $config $anchor
                $starRect=@{x=$config.rarityRect.x+$col*$grid.dx;y=$config.rarityRect.y+$row*$grid.dy;width=$config.rarityRect.width;height=$config.rarityRect.height}
                $stars=Crop-Region $before $starRect
                try{$cellOk=[RelicNative]::Difference($stars,$fiveStars) -le 9}finally{$stars.Dispose()}
            }finally{$before.Dispose()}
            if(-not $cellOk){$script:currentState.skipped++;continue}
            $validCells++
            [RelicNative]::ClickGrid($window,[int]($grid.x+$col*$grid.dx),[int]($grid.y+$row*$grid.dy))
            Start-Sleep -Milliseconds 240
            $bitmap=[RelicNative]::Capture($window)
            try{
              Check-Anchor $bitmap $config $anchor
              $details=Read-Details $bitmap $config
              $panelText=Normalize-MarkerText (($details.panel|ForEach-Object{$_.text})-join'')
              if(($row -eq 0 -and $col -lt 3) -or ($row -eq $grid.rows-1 -and $col -lt 3)){$signature+=$panelText}
              $script:currentState.scanned++
              $candidate=Find-MarkerMatch $plan.candidates $details.panel $details.subs ($config.substats.y-$config.panel.y)
              if(-not $candidate -or $pending[$candidate.key] -le 0){$script:currentState.skipped++;continue}
              $lockImage=Crop-Region $bitmap $config.unlockRect;$discardImage=Crop-Region $bitmap $config.discardRect
              try{
                if(-not (Test-UnmarkedVisual $discardImage $lockImage $unmarked $unlocked)){$script:currentState.skipped++;continue}
              }finally{$lockImage.Dispose();$discardImage.Dispose()}
              if($PreviewOnly -and $previewed.ContainsKey($candidate.key)){continue}
              $script:currentState.matched++;$matchedThisPage++
              if($PreviewOnly){$previewed[$candidate.key]=$true;$pending[$candidate.key]=0;continue}
              # Re-read immediately before the only state-changing input.
              Check-Stop;[RelicNative]::Guard($window)
              $verify=[RelicNative]::Capture($window)
              try{
                Check-Anchor $verify $config $anchor
                $confirmed=Read-Details $verify $config
                $same=Find-MarkerMatch @($candidate) $confirmed.panel $confirmed.subs ($config.substats.y-$config.panel.y)
                if(-not $same){throw '点击弃置前属性发生变化，已停止。'}
                $flag=Crop-Region $verify $config.discardRect;$unlockCheck=Crop-Region $verify $config.unlockRect
                try{if(-not (Test-UnmarkedVisual $flag $unlockCheck $unmarked $unlocked)){throw '点击前锁定或弃置状态发生变化，已停止。'}}finally{$flag.Dispose();$unlockCheck.Dispose()}
                $evidence=Crop-Region $verify $config.panel;try{$evidence.Save((Join-Path $JobDirectory ('before-'+$script:currentState.marked+'.png')),[Drawing.Imaging.ImageFormat]::Png)}finally{$evidence.Dispose()}
              }finally{$verify.Dispose()}
              Check-Stop
              [RelicNative]::ClickDiscard($window,[int]$config.discardPoint[0],[int]$config.discardPoint[1])
              Start-Sleep -Milliseconds 350
              $after=[RelicNative]::Capture($window)
              try{
                Check-Anchor $after $config $anchor
                $afterDetails=Read-Details $after $config
                $stillSame=Find-MarkerMatch @($candidate) $afterDetails.panel $afterDetails.subs ($config.substats.y-$config.panel.y)
                $markedIcon=Crop-Region $after $config.discardRect
                try{if(-not $stillSame -or -not (Test-MarkedVisual $markedIcon $unmarked)){throw '已点击一次弃置，但未能确认红色标记。已停止，不会盲目重复点击，请检查当前遗器。'}}finally{$markedIcon.Dispose()}
                $evidence=Crop-Region $after $config.panel;try{$evidence.Save((Join-Path $JobDirectory ('after-'+$script:currentState.marked+'.png')),[Drawing.Imaging.ImageFormat]::Png)}finally{$evidence.Dispose()}
              }finally{$after.Dispose()}
              $pending[$candidate.key]--;$script:currentState.marked++
              $event=@{at=(Get-Date).ToUniversalTime().ToString('o');fingerprint=$candidate.key;referenceIds=$candidate.ids;pieceName=$candidate.pieceName;action='discard-mark-confirmed'}
              [IO.File]::AppendAllText((Join-Path $JobDirectory 'actions.jsonl'),(ConvertTo-Json $event -Depth 12 -Compress)+"`n",$encoding)
            }finally{$bitmap.Dispose();Save-State 'running' ('已扫描 '+$script:currentState.scanned+' 次，确认标记 '+$script:currentState.marked+' 件。F8 停止。')}
            if(($pending.Values | Measure-Object -Sum).Sum -le 0){break}
          }
          if(($pending.Values | Measure-Object -Sum).Sum -le 0){break}
        }
        if(($pending.Values | Measure-Object -Sum).Sum -le 0){break}
        if($validCells -eq 0){throw '没有识别到校准的五星格子，可能有弹窗或列表位置不匹配。已停止，请检查背包与校准。'}
        $pageSignature=$signature -join '|'
        if($pageSignature -eq $lastSignature){$samePages++}else{$samePages=0};$lastSignature=$pageSignature
        if($samePages -ge 2){break}
        Check-Stop
        [RelicNative]::ScrollDown($window,[int]($grid.x+($grid.cols-1)*$grid.dx/2),[int]($grid.y+($grid.rows-1)*$grid.dy/2))
        Start-Sleep -Milliseconds 400
      }
      $remaining=[int](($pending.Values|Measure-Object -Sum).Sum)
      $script:currentState.remaining=$remaining
      if($PreviewOnly){Save-State 'complete' ('预览结束，核对命中 '+$script:currentState.matched+' 组候选属性；没有点击弃置。')}
      else{Save-State 'complete' ('标记结束：已确认 '+$script:currentState.marked+' 件，'+$remaining+' 件未找到或未通过核对。分解请在游戏内自行确认。')}
    }finally{$unmarked.Dispose();$unlocked.Dispose();$anchor.Dispose();$fiveStars.Dispose()}
}catch [OperationCanceledException]{Save-State 'stopped' $_.Exception.Message;exit 2}
catch{if($_.Exception.InnerException -is [OperationCanceledException]){Save-State 'stopped' $_.Exception.InnerException.Message;exit 2};Save-State 'failed' $_.Exception.Message;exit 1}
