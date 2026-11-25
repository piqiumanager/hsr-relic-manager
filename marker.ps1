param([ValidateSet('Run')][string]$Mode='Run',[string]$JobDirectory,[string]$PlanPath,[switch]$PreviewOnly,[string]$DataRoot='')
$ErrorActionPreference='Stop';$base=$PSScriptRoot;$encoding=New-Object Text.UTF8Encoding($false)
$statusPath=Join-Path $JobDirectory 'status.json';$stopPath=Join-Path $JobDirectory 'stop'
$state=@{state='starting';mode='Run';scanned=0;matched=0;marked=0;skipped=0;page=0;preview=[bool]$PreviewOnly;message='正在检查 1920×1080 游戏窗口…'}
function Save-State([string]$Name,[string]$Message){$script:state.state=$Name;$script:state.message=$Message;$script:state.updatedAt=(Get-Date).ToUniversalTime().ToString('o');[IO.File]::WriteAllText($statusPath+'.tmp',(ConvertTo-Json $script:state -Depth 15 -Compress),$encoding);Move-Item -LiteralPath ($statusPath+'.tmp') -Destination $statusPath -Force}
function Check-Stop {if((Test-Path -LiteralPath $stopPath)-or[RelicNative]::StopPressed()){throw(New-Object OperationCanceledException('已停止标记。'))}}
function Crop($Bitmap,$Rect){return [RelicNative]::Crop($Bitmap,$Rect.x,$Rect.y,$Rect.width,$Rect.height)}
function Read-Region($Bitmap,$Rect,[string]$Name){$crop=Crop $Bitmap $Rect;try{$file=Join-Path $JobDirectory ($Name+'.png');$crop.Save($file,[Drawing.Imaging.ImageFormat]::Png);return ,(Read-MarkerOcr $file)}finally{$crop.Dispose()}}
function Read-Details($Bitmap){return @{panel=(Read-Region $Bitmap $layout.panel 'panel');subs=(Read-Region $Bitmap $layout.substats 'subs')}}
function Header-Text {Check-Stop;$b=[RelicNative]::Capture($window);try{return Normalize-MarkerText (((Read-Region $b $layout.header 'header')|ForEach-Object{$_.text})-join'')}finally{$b.Dispose()}}
function Check-Anchor($Bitmap){$a=Crop $Bitmap $layout.header;try{if([RelicNative]::Difference($a,$anchor)-gt 18){throw '已离开遗器背包或出现弹窗，已停止。'}}finally{$a.Dispose()}}
try{
    [IO.Directory]::CreateDirectory($JobDirectory)|Out-Null
    Save-State 'starting' '正在连接游戏；无需点选校准。'
    Add-Type -AssemblyName System.Drawing;Add-Type -AssemblyName System.Windows.Forms
    Add-Type -Path (Join-Path $base 'marker-native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
    . (Join-Path $base 'marker-core.ps1');. (Join-Path $base 'layout-1080.ps1')
    [RelicNative]::SetProcessDPIAware()|Out-Null;Initialize-MarkerOcr
    $window=[RelicNative]::FindGame();$layout=Get-RelicLayout1080 $window.Width $window.Height;[RelicNative]::Activate($window)
    $plan=ConvertFrom-Json ([IO.File]::ReadAllText($PlanPath,$encoding))
    if($plan.schema-ne'hsr-marker-plan-v1'-or$plan.allowSalvage-ne$false-or@($plan.candidates).Count-lt 1-or$plan.inventoryCount-lt 1-or$plan.inventoryCount-gt 3000){throw '标记清单无效，请重新读取背包。'}
    $state.total=[int]$plan.total;$state.inventoryCount=[int]$plan.inventoryCount;$pending=@{};foreach($c in $plan.candidates){$pending[$c.key]=[int]$c.count}
    $data=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $base 'source\data.json'),$encoding));$knownNames=@($data.pieceNames.PSObject.Properties|ForEach-Object{$_.Value.PSObject.Properties|ForEach-Object{Normalize-MarkerText ([string]$_.Value)}});$recognized=0
    $header=Header-Text
    if($header-notmatch'背包|遗器'){
        [RelicNative]::TapNavigation($window,'B');Start-Sleep -Milliseconds 1500;$header=Header-Text
    }
    if($header-notmatch'背包|遗器'){throw '无法确认背包界面。请退出对话或菜单，回到游戏主界面后重试（默认背包快捷键 B）。'}
    [RelicNative]::ClickGrid($window,$layout.relicTab[0],$layout.relicTab[1]);Start-Sleep -Milliseconds 650
    [RelicNative]::ClickGrid($window,$layout.allTab[0],$layout.allTab[1]);Start-Sleep -Milliseconds 450
    # Move to the first row without requiring any user-selected grid points.
    [RelicNative]::ScrollToTop($window,700,450);Start-Sleep -Milliseconds 650
    [RelicNative]::ClickGrid($window,$layout.first[0],$layout.first[1]);Start-Sleep -Milliseconds 500
    $b=[RelicNative]::Capture($window);try{$anchor=Crop $b $layout.header}finally{$b.Dispose()}
    $reference=$null;$unlocked=$null;$started=Get-Date;$previous='';$previousGrid=$null
    Save-State 'running' '已自动打开遗器背包，正在逐件核对；F8 停止。'
    try{
      for($i=0;$i-lt[int]$plan.inventoryCount;$i++){
        Check-Stop;if(((Get-Date)-$started).TotalMinutes-gt 120){throw '扫描超过两小时，已停止。'}
        $bitmap=[RelicNative]::Capture($window)
        try{
          Check-Anchor $bitmap;$details=Read-Details $bitmap
          $signature=Normalize-MarkerText (($details.panel|ForEach-Object{$_.text})-join'')
          # Identical relics are allowed; the selected grid cell must still move.
          $gridNow=Crop $bitmap @{x=70;y=155;width=1250;height=755}
          try{if($i-gt 0-and$signature-eq$previous-and[RelicNative]::Difference($gridNow,$previousGrid)-lt 0.005){throw '遗器选择没有移动，已停止；请检查是否存在筛选或导航按键不一致。'}}finally{$gridNow.Dispose()}
          if(@($knownNames|Where-Object{$signature.Contains($_)}).Count-gt 0){$recognized++}
          if($i-eq 4-and$recognized-eq 0){throw '前五件均未识别到遗器名称，当前画面或 OCR 与固定布局不匹配，已停止。'}
          $previous=$signature;if($previousGrid){$previousGrid.Dispose()};$previousGrid=Crop $bitmap @{x=70;y=155;width=1250;height=755}
          $state.scanned++;$state.page=[int][Math]::Floor($i/45)+1
          $candidate=Find-MarkerMatch $plan.candidates $details.panel $details.subs ($layout.substats.y-$layout.panel.y)
          if($candidate-and$pending[$candidate.key]-gt 0-and$signature-notmatch'已装备|装备中'){
            $lock=Crop $bitmap $layout.unlockRect;$trash=Crop $bitmap $layout.discardRect
            try{
              if([RelicNative]::ClearlyUnlocked($lock)-and[RelicNative]::RedPixels($trash)-lt 7){
                if(-not$reference){$reference=[Drawing.Bitmap]$trash.Clone();$unlocked=[Drawing.Bitmap]$lock.Clone()}
                if(Test-UnmarkedVisual $trash $lock $reference $unlocked){
                  $state.matched++
                  if($PreviewOnly){$pending[$candidate.key]--}else{
                    Check-Stop;$verify=[RelicNative]::Capture($window)
                    try{
                      Check-Anchor $verify;$v=Read-Details $verify
                      if(-not(Find-MarkerMatch @($candidate) $v.panel $v.subs ($layout.substats.y-$layout.panel.y))){throw '点击前遗器属性改变，已停止。'}
                      $vl=Crop $verify $layout.unlockRect;$vt=Crop $verify $layout.discardRect
                      try{if(-not(Test-UnmarkedVisual $vt $vl $reference $unlocked)){throw '点击前锁定或弃置状态改变，已停止。'}}finally{$vl.Dispose();$vt.Dispose()}
                    }finally{$verify.Dispose()}
                    Check-Stop;[RelicNative]::ClickDiscard($window,$layout.discardPoint[0],$layout.discardPoint[1]);Start-Sleep -Milliseconds 350
                    $after=[RelicNative]::Capture($window)
                    try{
                      Check-Anchor $after;$v=Read-Details $after;$icon=Crop $after $layout.discardRect
                      try{if(-not(Find-MarkerMatch @($candidate) $v.panel $v.subs ($layout.substats.y-$layout.panel.y))-or-not(Test-MarkedVisual $icon $reference)){throw '点击后未确认弃置标记，已停止，不会重复点击。'}}finally{$icon.Dispose()}
                    }finally{$after.Dispose()}
                    $pending[$candidate.key]--;$state.marked++
                    [IO.File]::AppendAllText((Join-Path $JobDirectory 'actions.jsonl'),(ConvertTo-Json @{action='discard-mark-confirmed';index=$i;piece=$candidate.pieceName;key=$candidate.key} -Compress)+"`n",$encoding)
                  }
                }
              }
            }finally{$lock.Dispose();$trash.Dispose()}
          }else{$state.skipped++}
        }finally{$bitmap.Dispose()}
        $remaining=($pending.Values|Measure-Object -Sum).Sum
        Save-State 'running' ('已扫描 '+$state.scanned+'/'+$plan.inventoryCount+'，核对命中 '+$state.matched+'，已标记 '+$state.marked+'，剩余候选 '+$remaining+'。F8 停止。')
        if($remaining-le 0){break}
        if($i+1-lt$plan.inventoryCount){Check-Stop;[RelicNative]::TapNavigation($window,(Get-RelicNavigationKey $i));Start-Sleep -Milliseconds 250}
      }
      $remaining=[int](($pending.Values|Measure-Object -Sum).Sum);$state.remaining=$remaining
      if($remaining-gt 0){Save-State 'partial' ('遍历结束，仍有 '+$remaining+' 件候选未能确认，已保留不动；没有执行分解。')}else{Save-State 'complete' $(if($PreviewOnly){'识别预览完成，没有修改遗器。'}else{'标记完成，请在游戏中检查弃置列表并自行确认分解。'})}
    }finally{foreach($resource in @($anchor,$reference,$unlocked,$previousGrid)){if($resource){$resource.Dispose()}}}
}catch [OperationCanceledException]{Save-State 'stopped' $_.Exception.Message}catch{Save-State 'failed' $_.Exception.Message;exit 1}
