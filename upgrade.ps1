param([ValidateSet('Upgrade')][string]$Mode='Upgrade',[string]$JobDirectory,[string]$PlanPath,[switch]$PreviewOnly,[string]$DataRoot='')
$ErrorActionPreference='Stop';$base=$PSScriptRoot;$utf8=New-Object Text.UTF8Encoding($false)
$statusPath=Join-Path $JobDirectory 'status.json';$stopPath=Join-Path $JobDirectory 'stop'
$state=@{kind='upgrade';state='starting';message='正在连接游戏…';total=0;processed=0;kept=0;marked=0;confirmedSteps=0;scanned=0;preview=[bool]$PreviewOnly}
function Save-State([string]$Name,[string]$Message){$script:state.state=$Name;$script:state.message=$Message;$script:state.updatedAt=(Get-Date).ToUniversalTime().ToString('o');[IO.File]::WriteAllText($statusPath+'.tmp',(ConvertTo-Json $script:state -Depth 30 -Compress),$utf8);Move-Item -LiteralPath ($statusPath+'.tmp') -Destination $statusPath -Force}
function Check-Stop {if((Test-Path -LiteralPath $stopPath)-or[RelicNative]::StopPressed()){throw(New-Object OperationCanceledException('已停止强化。'))};if($script:started-and((Get-Date)-$script:started).TotalMinutes-gt 120){throw '强化任务超过两小时，已停止。'}}
function Read-Region($Bitmap,$Rect,[string]$Name){
    $b=[RelicNative]::Crop($Bitmap,$Rect.x,$Rect.y,$Rect.width,$Rect.height)
    try{$file=Join-Path $JobDirectory ($Name+'.png');$b.Save($file,[Drawing.Imaging.ImageFormat]::Png);$lines=Read-MarkerOcr $file
      foreach($line in $lines){$line.x+=$Rect.x;$line.y+=$Rect.y;foreach($word in $line.words){$word.x+=$Rect.x;$word.y+=$Rect.y}}
      return ,$lines
    }finally{$b.Dispose()}
}
function Open-Inventory {
    if(-not(Is-Inventory)){[RelicNative]::TapNavigation($window,'B');Start-Sleep -Milliseconds 1300}
    if(-not(Is-Inventory)){throw '请回到游戏主界面或遗器背包后重试。'}
    [RelicNative]::ClickGrid($window,$layout.relicTab[0],$layout.relicTab[1]);Start-Sleep -Milliseconds 500
    [RelicNative]::ClickGrid($window,$layout.allTab[0],$layout.allTab[1]);Start-Sleep -Milliseconds 350
    [RelicNative]::ScrollToTop($window,700,450);Start-Sleep -Milliseconds 500
    [RelicNative]::ClickGrid($window,$layout.first[0],$layout.first[1]);Start-Sleep -Milliseconds 400
}
function Inventory-Details {
    if(-not(Is-Inventory)){throw '已离开遗器背包，停止强化。'}
    $b=[RelicNative]::Capture($window)
    try{return @{panel=(Read-Region $b $layout.panel 'panel');subs=(Read-Region $b $layout.substats 'subs')}}finally{$b.Dispose()}
}
function Assert-UnlockedUnmarked {
    $b=[RelicNative]::Capture($window)
    try{$lock=[RelicNative]::Crop($b,$layout.unlockRect.x,$layout.unlockRect.y,$layout.unlockRect.width,$layout.unlockRect.height);$trash=[RelicNative]::Crop($b,$layout.discardRect.x,$layout.discardRect.y,$layout.discardRect.width,$layout.discardRect.height)
      try{if(-not[RelicNative]::ClearlyUnlocked($lock)-or[RelicNative]::RedPixels($trash)-ge 7){throw '遗器已锁定、已弃置或状态不清。'}}finally{$lock.Dispose();$trash.Dispose()}
    }finally{$b.Dispose()}
}
function Read-Observation($Candidate,[int]$Level){
    Assert-UnlockedUnmarked;$d=Inventory-Details
    if((Text-Of $d.panel)-match'已装备|装备中'){throw '当前遗器已装备。'}
    return ConvertTo-UpgradeObservation $Candidate $d.panel $d.subs $Level $layout.substats.y
}
function Ask-Score($Candidate,[string]$RelicId,$Observation,[bool]$Initial){
    $rid=[Guid]::NewGuid().ToString('N');$request=@{requestId=$rid;candidateKey=$Candidate.key;relicId=$RelicId;observation=$Observation;initial=$Initial}
    $script:state.request=$request
    [IO.File]::WriteAllText((Join-Path $JobDirectory 'request.json'),(ConvertTo-Json $request -Depth 20 -Compress),$utf8)
    Save-State 'awaitingScore' ('正在核验 +'+$Observation.enhance+' 属性与评分…')
    $answer=Join-Path $JobDirectory ('decision-'+$rid+'.json');$deadline=(Get-Date).AddSeconds(45)
    while(-not(Test-Path -LiteralPath $answer)){Check-Stop;if((Get-Date)-gt$deadline){throw '评分界面没有回应，已停止强化。'};Start-Sleep -Milliseconds 160}
    $decision=ConvertFrom-Json ([IO.File]::ReadAllText($answer,$utf8));Assert-UpgradeDecision $request $decision|Out-Null
    $script:state.Remove('request');$script:state.lastScore=@{level=$Observation.enhance;lower=$decision.lower;upper=$decision.upper;action=$decision.action}
    Save-State 'running' ('当前 +'+$Observation.enhance+'，评分 '+([Math]::Round($decision.lower,1))+'–'+([Math]::Round($decision.upper,1)))
    return $decision
}
function Mark-CurrentDiscard($Candidate,$Observation){
    $same=Read-Observation $Candidate $Observation.enhance
    if(-not(Test-ObservedStats $same.substats $Observation.substats)){throw '弃置前词条改变，已停止。'}
    Assert-UnlockedUnmarked
    $b=[RelicNative]::Capture($window);try{$before=[RelicNative]::Crop($b,$layout.discardRect.x,$layout.discardRect.y,$layout.discardRect.width,$layout.discardRect.height)}finally{$b.Dispose()}
    try{
      Check-Stop;[RelicNative]::ClickDiscard($window,$layout.discardPoint[0],$layout.discardPoint[1]);Start-Sleep -Milliseconds 350
      $d=Inventory-Details;$after=ConvertTo-UpgradeObservation $Candidate $d.panel $d.subs $Observation.enhance $layout.substats.y
      if(-not(Test-ObservedStats $after.substats $Observation.substats)){throw '弃置后当前遗器改变。'}
      $b=[RelicNative]::Capture($window);try{$icon=[RelicNative]::Crop($b,$layout.discardRect.x,$layout.discardRect.y,$layout.discardRect.width,$layout.discardRect.height);try{if(-not(Test-MarkedVisual $icon $before)){throw '弃置标记未确认，已停止。'}}finally{$icon.Dispose()}}finally{$b.Dispose()}
    }finally{$before.Dispose()}
}
function Process-Relic($Candidate,[string]$Id){
    $observation=Read-Observation $Candidate $Candidate.enhance;$active=$Candidate.substats;$initial=$true
    for($step=0;$step-lt 6;$step++){
      Check-Stop
      $decision=Ask-Score $Candidate $Id $observation $initial
      if($PreviewOnly){
        if($decision.action-eq'enhance'){
          Prepare-Enhancement $Candidate $observation ([int]$decision.targetLevel) $active
          Cancel-PreparedEnhancement
          $state.previewPrepared=[int]$state.previewPrepared+1
        }
        $state.processed++;return 'preview'
      }
      switch($decision.action){
        'stop'{throw $decision.reason}
        'keep'{$state.kept++;$state.processed++;return 'keep'}
        'markDiscard'{Mark-CurrentDiscard $Candidate $observation;$state.marked++;$state.processed++;return 'discard'}
        'enhance'{
          $target=[int]$decision.targetLevel
          Save-State 'running' ('准备 +'+$observation.enhance+' → +'+$target+'…')
          Prepare-Enhancement $Candidate $observation $target $active
          Confirm-Enhancement $observation $target
          $after=Read-Observation $Candidate $target
          foreach($s in $active){$next=@($after.substats|Where-Object{$_.stat-eq$s.stat});if($next.Count-ne 1-or$next[0].value+0.00001-lt[double](Get-DisplayValue $s.stat $s.value)){throw '强化后副属性减少或缺失。'}}
          [IO.File]::AppendAllText((Join-Path $JobDirectory 'enhancements.jsonl'),(ConvertTo-Json @{id=$Id;from=$observation.enhance;to=$target;observation=$after} -Depth 12 -Compress)+"`n",$utf8)
          $state.confirmedSteps++;$observation=$after;$active=$after.substats;$initial=$false
        }
        default{throw '未知强化指令。'}
      }
    }
    throw '强化步骤超过五次，已停止。'
}
try{
    [IO.Directory]::CreateDirectory($JobDirectory)|Out-Null
    Add-Type -AssemblyName System.Drawing;Add-Type -AssemblyName System.Windows.Forms
    Add-Type -Path (Join-Path $base 'marker-native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
    . (Join-Path $base 'marker-core.ps1');. (Join-Path $base 'layout-1080.ps1');. (Join-Path $base 'upgrade-core.ps1');. (Join-Path $base 'enhancement-actions.ps1')
    [RelicNative]::SetProcessDPIAware()|Out-Null;Initialize-MarkerOcr
    $window=[RelicNative]::FindGame();$layout=Get-RelicLayout1080 $window.Width $window.Height;[RelicNative]::Activate($window)
    $plan=ConvertFrom-Json ([IO.File]::ReadAllText($PlanPath,$utf8))
    if($plan.operation-ne'upgrade'-or$plan.allowSalvage-ne$false-or$plan.policy.threshold-ne 80-or$plan.policy.step-ne 3-or$plan.policy.maxRelicMaterialRarity-ne 4){throw '强化规则无效。'}
    $state.total=[int]$plan.total;$done=@{};$started=Get-Date
    $materialHeader=@{x=1320;y=450;width=575;height=230};$materialSlots=@{x=1330;y=650;width=565;height=295};$rulesRegion=@{x=950;y=180;width=940;height=800};$levelRow=@{x=1350;y=115;width=545;height=80}
    Save-State 'running' '正在查找胚子。F8 停止。'
    while($state.processed-lt$state.total){
      Check-Stop;Open-Inventory;$mutated=$false;$matchedPass=0
      for($i=0;$i-lt$plan.inventoryCount;$i++){
        Check-Stop;$d=Inventory-Details;$state.scanned++
        $remaining=@($plan.candidates|Where-Object{@($_.ids|Where-Object{-not$done.ContainsKey([string]$_)}).Count-gt 0})
        $candidate=Find-MarkerMatch $remaining $d.panel $d.subs $layout.substats.y
        if($candidate){
          $id=[string](@($candidate.ids|Where-Object{-not$done.ContainsKey([string]$_)})[0])
          $eligible=$true;try{Assert-UnlockedUnmarked}catch{$eligible=$false;Save-State 'running' '当前胚子受保护，跳过。';$done[$id]=$true;$state.processed++}
          if($eligible){
            $outcome=Process-Relic $candidate $id;$done[$id]=$true;$matchedPass++
            Save-State 'running' ('已处理 '+$state.processed+'/'+$state.total+'，保留 '+$state.kept+'，弃置 '+$state.marked+'，强化 '+$state.confirmedSteps+' 次。')
            # Preview also enters/leaves enhancement UI; restart from the first slot.
            $mutated=$true;break
          }
        }
        if($state.processed-ge$state.total){break}
        if($i+1-lt$plan.inventoryCount){[RelicNative]::TapNavigation($window,(Get-RelicNavigationKey $i));Start-Sleep -Milliseconds 250}
      }
      if(-not$mutated){if($state.processed-lt$state.total){Save-State 'partial' ('仍有 '+($state.total-$state.processed)+' 件胚子未匹配，已保留不动。');exit 0};break}
    }
    Save-State 'complete' $(if($PreviewOnly){'强化预览完成，未消耗材料。'}else{'强化完成，低分已标记弃置。请自行确认分解。'})
}catch [OperationCanceledException]{Save-State 'stopped' $_.Exception.GetBaseException().Message}catch{$failure=$_.Exception.GetBaseException();if($failure-is[OperationCanceledException]){Save-State 'stopped' $failure.Message}else{Save-State 'failed' $failure.Message;exit 1}}
