param([string]$JobDirectory,[string]$PlanPath,[string]$DataRoot='',[switch]$PreviewOnly,[switch]$Upgrade)
$ErrorActionPreference='Stop';$base=$PSScriptRoot;$utf8=New-Object Text.UTF8Encoding($false)
$statusPath=Join-Path $JobDirectory 'status.json';$stopPath=Join-Path $JobDirectory 'stop'
$state=@{kind='live';state='starting';scanned=0;matched=0;marked=0;unlocked=0;attempted=0;equippedLow=0;upgrade=[bool]$Upgrade;confirmedSteps=0;submittedSteps=0;kept=0;passes=1;totalInspected=0;skipped=0;unrecognized=0;preview=[bool]$PreviewOnly;message='正在连接当前游戏…'}
function Save-State([string]$Name,[string]$Message){$script:state.state=$Name;$script:state.message=$Message;[IO.File]::WriteAllText($statusPath+'.tmp',(ConvertTo-Json $script:state -Depth 30 -Compress),$utf8);Move-Item -LiteralPath ($statusPath+'.tmp') -Destination $statusPath -Force}
function Check-Stop {if((Test-Path -LiteralPath $stopPath)-or[RelicNative]::StopPressed()){throw(New-Object OperationCanceledException('已停止现场扫描。'))}}
function Read-Region($Bitmap,$Rect,[string]$Name){$b=[RelicNative]::Crop($Bitmap,$Rect.x,$Rect.y,$Rect.width,$Rect.height);try{$file=Join-Path $JobDirectory ($Name+'.png');$b.Save($file,[Drawing.Imaging.ImageFormat]::Png);return ,(Read-MarkerOcr $file)}finally{$b.Dispose()}}
function Check-Inventory {
    Check-Stop;$b=[RelicNative]::Capture($window);try{$lines=Read-Region $b $layout.header 'header';$t=Normalize-MarkerText (($lines|ForEach-Object{$_.text})-join'');return ($t-match'背包'-and$t-notmatch'强化|详情|重掷')}finally{$b.Dispose()}
}
function Read-Selected($Bitmap,[int]$Index){
    $banner=[RelicNative]::Crop($Bitmap,1405,192,440,165);try{if(-not[RelicNative]::FiveStarPanel($banner)){throw '当前遗器未确认为五星。'}}finally{$banner.Dispose()}
    $panel=Read-Region $Bitmap $layout.panel 'panel';$subs=Read-Region $Bitmap $layout.substats 'subs'
    $mainLines=Read-Region $Bitmap @{x=1435;y=373;width=415;height=60} 'main-label'
    if(-not(Get-LiveStatLabel (($mainLines|ForEach-Object{$_.text})-join''))){
      $crop=[RelicNative]::Crop($Bitmap,1435,373,415,60)
      try{$mask=[RelicNative]::NumericOcrImage($crop,140);try{$retry=Join-Path $JobDirectory 'main-label-retry.png';$mask.Save($retry,[Drawing.Imaging.ImageFormat]::Png);$mainLines=Read-MarkerOcr $retry}finally{$mask.Dispose()}}finally{$crop.Dispose()}
    }
    $raw=ConvertFrom-LivePanel $panel $subs $data ($layout.substats.y-$layout.panel.y) -NumbersPending -MainLines $mainLines
    $detail=[RelicNative]::Crop($Bitmap,$layout.panel.x,$layout.panel.y,$layout.panel.width,$layout.panel.height);try{$equipped=[RelicNative]::EquippedFooterState($detail);if($equipped-ne 0){$raw.location=if($equipped-eq 1){'live-equipped'}else{'live-protected-footer'}}}finally{$detail.Dispose()}
    $numericRects=@(@{x=1405;y=310;width=170;height=50;threshold=210},@{x=1765;y=397;width=90;height=45;threshold=140})
    foreach($n in 0..($raw.substats.Count+$raw.preview_substats.Count-1)){$numericRects+=@{x=1735;y=433+$n*38;width=128;height=36;threshold=$(if($n-ge$raw.substats.Count){-1}else{165})}}
    $images=@();foreach($r in $numericRects){$crop=[RelicNative]::Crop($Bitmap,$r.x,$r.y,$r.width,$r.height);try{$mask=[RelicNative]::NumericOcrImage($crop,$r.threshold);try{$stream=New-Object IO.MemoryStream;try{$mask.Save($stream,[Drawing.Imaging.ImageFormat]::Png);$images+=('data:image/png;base64,'+[Convert]::ToBase64String($stream.ToArray()))}finally{$stream.Dispose()}}finally{$mask.Dispose()}}finally{$crop.Dispose()}}
    $raw.numericImages=$images
    $sha=[Security.Cryptography.SHA256]::Create();try{$raw.numericFingerprint=[BitConverter]::ToString($sha.ComputeHash($utf8.GetBytes(($images-join''))))}finally{$sha.Dispose()}
    $lock=[RelicNative]::Crop($Bitmap,$layout.unlockRect.x,$layout.unlockRect.y,$layout.unlockRect.width,$layout.unlockRect.height)
    $trash=[RelicNative]::Crop($Bitmap,$layout.discardRect.x,$layout.discardRect.y,$layout.discardRect.width,$layout.discardRect.height)
    try{$lockState=[RelicNative]::LockState($lock);$raw.lock=if($lockState-eq 0){$false}elseif($lockState-eq 1){$true}else{$null};$raw.discard=([RelicNative]::RedPixels($trash)-ge 7)}finally{$lock.Dispose();$trash.Dispose()}
    $raw._uid='live-'+$Index;return $raw
}
function Save-LiveEvidence($Bitmap,[string]$Stage){
    if($state.attempted-gt 8){return}
    $prefix=('evidence-'+$state.scanned+'-'+$Stage)
    foreach($entry in @(@{name='panel';rect=$layout.panel},@{name='lock';rect=$layout.unlockRect},@{name='discard';rect=$layout.discardRect})){
      $r=$entry.rect;$crop=[RelicNative]::Crop($Bitmap,$r.x,$r.y,$r.width,$r.height)
      try{$crop.Save((Join-Path $JobDirectory ($prefix+'-'+$entry.name+'.png')),[Drawing.Imaging.ImageFormat]::Png)}finally{$crop.Dispose()}
    }
}
function Ask-LiveScore($Observation,[string]$Intent='score'){
    Check-Stop
    $request=@{requestId=[Guid]::NewGuid().ToString('N');relicId=$Observation._uid;observation=$Observation;characters=@($plan.characters);intent=$Intent;pass=$state.passes;upgrade=($plan.upgrade-eq$true-and-not$PreviewOnly)}
    $script:state.request=$request;[IO.File]::WriteAllText((Join-Path $JobDirectory 'request.json'),(ConvertTo-Json $request -Depth 20 -Compress),$utf8)
    Save-State 'awaitingScore' ('正在评分 '+$state.scanned+'/'+$state.inventoryCount+'，已标记 '+$state.marked+'，已跳过 '+$state.skipped+'。')
    $file=Join-Path $JobDirectory ('decision-'+$request.requestId+'.json');$deadline=(Get-Date).AddSeconds(45)
    while(-not(Test-Path -LiteralPath $file)){Check-Stop;if((Get-Date)-gt$deadline){throw '评分界面未响应，已停止。'};Start-Sleep -Milliseconds 60}
    Check-Stop;$answer=ConvertFrom-Json ([IO.File]::ReadAllText($file,$utf8));Assert-LiveDecision $request $answer ($plan.allowUnlockLowPotential-eq$true) ($plan.upgrade-eq$true-and-not$PreviewOnly)|Out-Null;$script:state.Remove('request')
    if($answer.action-eq'stop'){throw $answer.reason};return $answer
}
function Mark-LiveRelic($Observation,$Expected,$Record=$null){
    if($null-eq$Expected.level-or$Expected.level-lt 0-or$Expected.level-gt 15){throw '遗器等级不明，不参与标记。'}
    $script:state.attempted++;Check-Stop;if(-not(Check-Inventory)){throw '已离开遗器背包。'}
    $before=[RelicNative]::Capture($window)
    try{Save-LiveEvidence $before 'before';$same=Read-Selected $before $state.scanned
      if($null-eq$same.lock-or$same.lock-ne$Expected.lock-or$same.discard-ne$false-or$same.location-cne''){throw '标记前保护状态改变。'}
      $verified=Ask-LiveScore $same 'verify-before'
      if($verified.action-ne'markDiscard'-or$verified.verified-ne$true-or-not(Test-LiveIdentity $verified.observation $Expected)){throw '标记前遗器身份或属性改变。'}
      Check-Stop
      $reference=[RelicNative]::Crop($before,$layout.discardRect.x,$layout.discardRect.y,$layout.discardRect.width,$layout.discardRect.height)
    }finally{$before.Dispose()}
    try{
      if($same.lock-eq$true){
        if($plan.allowUnlockLowPotential-ne$true-or$verified.unlockFirst-ne$true){throw '未授权解锁当前遗器。'}
        Check-Stop;[RelicNative]::ClickVerifiedControl($window,($layout.unlockRect.x+[int]($layout.unlockRect.width/2)),($layout.unlockRect.y+[int]($layout.unlockRect.height/2)));[RelicNative]::HoverControl($window,1330,110)
        Check-Stop;if(-not(Check-Inventory)){throw '解锁后已离开背包。'}
        $unlocked=[RelicNative]::Capture($window)
        try{Save-LiveEvidence $unlocked 'unlocked';$same=Read-Selected $unlocked $state.scanned
          if($same.lock-ne$false-or$same.discard-ne$false-or$same.location-cne''){throw '未确认解锁状态，已停止，不重复点击。'}
          $verified=Ask-LiveScore $same 'verify-unlocked'
          if($verified.action-ne'markDiscard'-or$verified.verified-ne$true-or-not(Test-LiveIdentity $verified.observation $Expected)){throw '解锁后属性核验不通过，未执行弃置。'}
          $script:state.unlocked++;if($Record){$Record.lock=$false};[IO.File]::AppendAllText((Join-Path $JobDirectory 'actions.jsonl'),(ConvertTo-Json @{action='low-potential-unlock-confirmed';index=$state.scanned;piece=$Observation.pieceName} -Compress)+"`n",$utf8)
        }finally{$unlocked.Dispose()}
      }
      Check-Stop
      [RelicNative]::ClickDiscard($window,$layout.discardPoint[0],$layout.discardPoint[1]);[RelicNative]::HoverControl($window,1330,110)
      $after=[RelicNative]::Capture($window)
      try{Save-LiveEvidence $after 'marked';$same=Read-Selected $after $state.scanned;$icon=[RelicNative]::Crop($after,$layout.discardRect.x,$layout.discardRect.y,$layout.discardRect.width,$layout.discardRect.height)
        try{if($same.lock-ne$false-or$same.discard-ne$true-or$same.location-cne''-or-not(Test-MarkedVisual $icon $reference)){throw '未确认弃置状态，已停止，不重复点击。'}}finally{$icon.Dispose()}
        $verified=Ask-LiveScore $same 'verify-after'
        if($verified.verified-ne$true-or-not(Test-LiveIdentity $verified.observation $Expected)){throw '弃置后属性核验不通过，已停止，不重复点击。'}
      }finally{$after.Dispose()}
      $script:state.marked++;[IO.File]::AppendAllText((Join-Path $JobDirectory 'actions.jsonl'),(ConvertTo-Json @{action='discard-mark-confirmed';index=$state.scanned;piece=$Observation.pieceName;level=$Expected.level;metric=$(if($Expected.level-eq 15){'current'}else{'average'});score=$(if($Expected.level-eq 15){$verified.currentScore}else{$verified.averagePotential})} -Compress)+"`n",$utf8)
    }finally{$reference.Dispose()}
}
function Save-Snapshot {
    if($null-eq$script:records){return};$snapshot=@{source='当前游戏画面';characters=@($plan.characters);relics=$script:records.ToArray();metadata=@{partial=($state.scanned-lt$state.inventoryCount-or$script:records.Count-lt$state.inventoryCount-or$state.unrecognized-gt 0);screenRead=$true;inventoryCount=$state.inventoryCount;unrecognized=$state.unrecognized}}
    [IO.File]::WriteAllText((Join-Path $JobDirectory 'snapshot.json'),(ConvertTo-Json $snapshot -Depth 30 -Compress),$utf8)
}
function Upgrade-LiveRelic($Initial,[int]$RecordIndex){
    $answer=$Initial
    for($step=0;$step-lt 6;$step++){
      Check-Stop
      if($answer.action-eq'markDiscard'){$script:state.matched++;$script:state.lastDecision=$answer.reason;Mark-LiveRelic $answer.observation $answer.observation $answer.raw;$answer.raw.discard=$true;$script:records[$RecordIndex]=$answer.raw;Save-Snapshot;return}
      if($answer.action-eq'keep'-and$answer.observation.level-eq 15){$script:state.kept++;return}
      if($answer.action-ne'enhance'-or$answer.verified-ne$true){throw ('强化后未得到可执行评分：'+$answer.reason)}
      $expected=$answer.observation;$target=[int]$answer.targetLevel
      if(-not(Check-Inventory)){throw '强化前已离开背包。'}
      $frame=[RelicNative]::Capture($window)
      try{$fresh=Read-Selected $frame $state.scanned}finally{$frame.Dispose()}
      $verified=Ask-LiveScore $fresh 'verify-upgrade'
      if($verified.action-ne'enhance'-or$verified.targetLevel-ne$target-or-not(Test-LiveIdentity $verified.observation $expected)){throw '强化前遗器属性或评分改变。'}
      $active=@($verified.observation.substats|ForEach-Object{@{stat=$_.key;value=$_.value}})
      $level=@{enhance=[int]$expected.level}
      Prepare-Enhancement $null $level $target $active
      Check-Stop;Confirm-Enhancement $level $target
      if(-not(Check-Inventory)){throw '强化后未回到背包。'}
      $frame=[RelicNative]::Capture($window)
      try{$fresh=Read-Selected $frame $state.scanned}finally{$frame.Dispose()}
      $answer=Ask-LiveScore $fresh 'upgrade-after';$script:state.lastDecision=$answer.reason
      if($answer.verified-ne$true){throw ('强化后识别未通过：'+$answer.reason)}
      Assert-LiveAdvance $expected $answer.observation $target|Out-Null
      $script:state.confirmedSteps++;$script:records[$RecordIndex]=$answer.raw
      [IO.File]::AppendAllText((Join-Path $JobDirectory 'enhancements.jsonl'),(ConvertTo-Json @{index=$state.scanned;from=$expected.level;to=$target;observation=$answer.observation;action=$answer.action} -Depth 15 -Compress)+"`n",$utf8)
      Save-Snapshot;Save-State 'running' ('已核实强化至 +'+$target+'，平均潜力 '+[Math]::Round($answer.averagePotential,1)+'，当前分 '+[Math]::Round($answer.currentScore,1)+'。')
    }
    throw '强化步骤超过五次，已停止。'
}
function Process-LiveRecord($Raw){
    if($Raw){
      $answer=Ask-LiveScore $Raw;$script:records.Add($answer.raw)
      if($answer.verified-ne$true){$script:state.unrecognized++}
      $script:state.lastDecision=$answer.reason
      if($answer.equippedLow-eq$true){$script:state.equippedLow++;[IO.File]::AppendAllText((Join-Path $JobDirectory 'actions.jsonl'),(ConvertTo-Json @{action='equipped-low-protected';index=$state.scanned;level=$answer.observation.level;current=$answer.currentScore;average=$answer.averagePotential;piece=$Raw.pieceName} -Compress)+"`n",$utf8)}
      if($answer.action-eq'markDiscard'){$script:state.matched++;if(-not$PreviewOnly){Mark-LiveRelic $Raw $answer.observation $answer.raw;$answer.raw.discard=$true}}
      elseif($answer.action-eq'enhance'){
        if($PreviewOnly-or$plan.upgrade-ne$true){throw '未授权强化。'}
        Upgrade-LiveRelic $answer ($script:records.Count-1);$script:restartTraversal=$true
      }
      elseif($answer.action-eq'skip'){$script:state.skipped++}
    }else{$script:records.Add(@{_uid=('live-'+$script:state.scanned);rarity=0});$script:state.skipped++;$script:state.lastDecision='非目标遗器或属性识别不完整，跳过'}
}
function Save-LiveFailure($ErrorRecord){
    $script:state.Remove('request');$failure=$ErrorRecord.Exception.GetBaseException();$trace=$ErrorRecord.ToString()+"`n"+$ErrorRecord.ScriptStackTrace
    try{[IO.File]::WriteAllText((Join-Path $JobDirectory 'failure.log'),$trace,$utf8)}catch{}
    try{Save-Snapshot}catch{try{[IO.File]::AppendAllText((Join-Path $JobDirectory 'failure.log'),"`n快照保存失败："+$_.Exception.Message,$utf8)}catch{}}
    if($failure-is[OperationCanceledException]){Save-State 'stopped' $failure.Message;return 0}
    Save-State 'failed' ($failure.Message+' 已确认标记 '+$state.marked+' 件，已核实强化 '+[int]$state.confirmedSteps+' 次。');return 1
}

function Invoke-LiveTraversal {
    try{
    $script:records=New-Object 'Collections.Generic.List[object]';$previousGrid=$null;$previousHash='';$started=Get-Date
    for($i=0;$i-lt$state.inventoryCount;$i++){
      Check-Stop;if(((Get-Date)-$started).TotalHours-ge 3){throw '已达到本次扫描时限。'}
      if(-not(Check-Inventory)){throw '已离开遗器背包，已停止。'}
      $b=[RelicNative]::Capture($window);$state.scanned++;$state.totalInspected++
      try{
        $grid=[RelicNative]::Crop($b,70,155,1250,755);$hash=[RelicNative]::ImageHash($b)
        try{if($previousGrid-and$hash-eq$previousHash-and[RelicNative]::Difference($grid,$previousGrid)-lt .005){throw '遗器选择未移动，已停止，请检查筛选或按键。'};if($previousGrid){$previousGrid.Dispose()};$previousGrid=[Drawing.Bitmap]$grid.Clone();$previousHash=$hash}finally{$grid.Dispose()}
        $rarity=[RelicNative]::Crop($b,1405,192,440,165);try{$five=[RelicNative]::FiveStarPanel($rarity)}finally{$rarity.Dispose()}
        $raw=$null
        if($five){try{$raw=Read-Selected $b $state.scanned}catch{$state.unrecognized++;[IO.File]::AppendAllText((Join-Path $JobDirectory 'recognition-errors.jsonl'),(ConvertTo-Json @{index=$state.scanned;message=$_.Exception.GetBaseException().Message} -Compress)+"`n",$utf8);if($state.unrecognized-le 8){foreach($name in @('panel','subs','main-label')){$file=Join-Path $JobDirectory ($name+'.png');if(Test-Path -LiteralPath $file){Copy-Item -LiteralPath $file -Destination (Join-Path $JobDirectory ('unrecognized-'+$state.scanned+'-'+$name+'.png')) -Force}}}}}
      }finally{$b.Dispose()}
      $script:restartTraversal=$false;Process-LiveRecord $raw
      Save-State 'running' ('已检查 '+$state.scanned+'/'+$state.inventoryCount+'，已标记 '+$state.marked+'，已跳过 '+$state.skipped+'。'+$state.lastDecision+'。F8 停止。')
      if($plan.maxMarks-gt 0-and$state.marked-ge$plan.maxMarks){Save-Snapshot;Save-State 'complete' ('小批量验证完成，已标记 '+$state.marked+' 件，未分解。');return}
      if($state.scanned%50-eq 0){Save-Snapshot}
      if($script:restartTraversal){
        # Enhancement may reorder the inventory and consuming materials changes its count.
        # Restart the pass: marked items and high +15 items are terminal, so no duplicate spending.
        Save-Snapshot;$state.passes++;if($state.passes-gt 3001){throw '强化遍历次数异常，已停止。'}
        [RelicNative]::ScrollToTop($window,700,450);[RelicNative]::ClickGrid($window,$layout.first[0],$layout.first[1]);Start-Sleep -Milliseconds 350
        $frame=[RelicNative]::Capture($window);try{$state.inventoryCount=Get-LiveInventoryCount (Read-Region $frame @{x=1490;y=30;width=360;height=65} 'count')}finally{$frame.Dispose()}
        $script:records.Clear();$state.scanned=0;$state.unrecognized=0;$state.equippedLow=0;$state.skipped=0
        if($previousGrid){$previousGrid.Dispose();$previousGrid=$null};$previousHash='';$i=-1;continue
      }
      if($state.scanned-lt$state.inventoryCount){[RelicNative]::TapNavigation($window,(Get-RelicNavigationKey $i));Start-Sleep -Milliseconds 200}
    }
    Save-Snapshot;Save-State $(if($state.unrecognized){'partial'}else{'complete'}) $(if($PreviewOnly){'读取完成，未修改遗器。'}else{'标记完成，分解由你确认。'})
    }finally{if($previousGrid){$previousGrid.Dispose()}}
}

try{
    [IO.Directory]::CreateDirectory($JobDirectory)|Out-Null;Save-State 'starting' '正在连接当前游戏，无需重新登录。'
    Add-Type -AssemblyName System.Drawing;Add-Type -AssemblyName System.Windows.Forms
    Add-Type -Path (Join-Path $base 'marker-native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
    . (Join-Path $base 'marker-core.ps1');. (Join-Path $base 'layout-1080.ps1');. (Join-Path $base 'live-core.ps1');. (Join-Path $base 'upgrade-core.ps1');. (Join-Path $base 'enhancement-actions.ps1')
    [RelicNative]::SetProcessDPIAware()|Out-Null;Initialize-MarkerOcr
    $window=[RelicNative]::FindGame();$layout=Get-RelicLayout1080 $window.Width $window.Height
    $plan=ConvertFrom-Json ([IO.File]::ReadAllText($PlanPath,$utf8));$data=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $base 'source/data.json'),$utf8))
    if(($plan.upgrade-eq$true)-ne[bool]$Upgrade){throw '强化任务参数不一致。'}
    $materialHeader=@{x=1320;y=450;width=575;height=230};$materialSlots=@{x=1330;y=650;width=565;height=295};$rulesRegion=@{x=950;y=180;width=940;height=800};$levelRow=@{x=1350;y=115;width=545;height=80}
    [RelicNative]::Activate($window)
    if(-not(Check-Inventory)){[RelicNative]::TapNavigation($window,'B');Start-Sleep -Milliseconds 1300}
    if(-not(Check-Inventory)){throw '没有识别到背包，请退出对话或菜单后重试。'}
    [RelicNative]::ClickGrid($window,$layout.relicTab[0],$layout.relicTab[1]);Start-Sleep -Milliseconds 450
    [RelicNative]::ClickGrid($window,$layout.allTab[0],$layout.allTab[1]);Start-Sleep -Milliseconds 300
    [RelicNative]::ScrollToTop($window,700,450);[RelicNative]::ClickGrid($window,$layout.first[0],$layout.first[1]);Start-Sleep -Milliseconds 350
    $b=[RelicNative]::Capture($window);try{$state.inventoryCount=Get-LiveInventoryCount (Read-Region $b @{x=1490;y=30;width=360;height=65} 'count')}finally{$b.Dispose()}
    Invoke-LiveTraversal
}catch{
    $code=Save-LiveFailure $_;if($code-ne 0){exit $code}
}
