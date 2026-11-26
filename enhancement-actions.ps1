# Shared, screen-verified enhancement controls. No input is issued when this file is loaded.
function Read-Frame($Rect,[string]$Name){
    Check-Stop;$b=[RelicNative]::Capture($window)
    try{$crop=[RelicNative]::Crop($b,$Rect.x,$Rect.y,$Rect.width,$Rect.height);try{$file=Join-Path $JobDirectory ($Name+'.png');$crop.Save($file,[Drawing.Imaging.ImageFormat]::Png);$lines=Read-MarkerOcr $file;foreach($line in $lines){$line.x+=$Rect.x;$line.y+=$Rect.y;foreach($word in $line.words){$word.x+=$Rect.x;$word.y+=$Rect.y}};return ,$lines}finally{$crop.Dispose()}}finally{$b.Dispose()}
}
function Text-Of($Lines){return Normalize-MarkerText (($Lines|ForEach-Object{$_.text})-join'')}
function Click-Control($Control){if(-not$Control){throw '未找到所需游戏控件。'};Check-Stop;[RelicNative]::ClickVerifiedControl($window,$Control.cx,$Control.cy);Start-Sleep -Milliseconds 350}
function Click-Text([string[]]$Texts,$Region,[string]$Name){$lines=Read-Frame $Region $Name;$c=Find-UpgradeControl $lines $Texts $Region;if(-not$c){throw ('未找到简体中文控件：'+($Texts-join'/'))};Click-Control $c;return $c}
function Is-Inventory {
    $text=Text-Of (Read-Frame $layout.header 'header')
    return ($text-match'背包'-and$text-notmatch'详情|强化|重掷')
}
function Assert-EnhancementScreen {
    $head=Text-Of (Read-Frame @{x=25;y=15;width=530;height=125} 'upgrade-header')
    $body=Text-Of (Read-Frame $materialHeader 'material-header')
    if($head-notmatch'遗器详情|遗器强化'-or$body-notmatch'消耗材料'-or$body-notmatch'自动置入|自动添加'){throw '无法确认遗器强化界面。'}
}
function Assert-OldStats($Expected){
    $lines=Read-Frame @{x=1340;y=185;width=550;height=365} 'old-stats';$observed=@($lines|ForEach-Object{Get-StatObservation $_.text}|Where-Object{$null-ne$_})
    foreach($s in $Expected){$v=Get-DisplayValue $s.stat $s.value;$matches=@($observed|Where-Object{$_.stat-eq$s.stat-and[Math]::Abs($_.value-[double]$v)-lt 0.011});if($matches.Count-ne 1){throw '强化界面的原词条与选中遗器不一致。'}}
}
function Set-MaterialRules([int]$Target){
    $grades=@('2星及以下','二星及以下','二星以下','3星及以下','三星及以下','三星以下','4星及以下','四星及以下','四星以下','5星及以下','五星及以下','五星以下','仅强化材料','仅经验材料')
    $lines=Read-Frame $materialHeader 'material-header';$drop=Find-UpgradeControl $lines $grades $materialHeader
    if(-not$drop){throw '未识别到自动置入的材料星级规则。'}
    Click-Control $drop
    $menu=Read-Frame $rulesRegion 'material-rules';$text=Text-Of $menu
    if($text-notmatch'置入规则|强化上限'){throw '未打开自动置入规则面板。'}
    $grade=Find-UpgradeControl $menu @('4星及以下','四星及以下','四星以下') $rulesRegion $drop
    if(-not$grade){throw '无法将强化材料限定到四星及以下。'};Click-Control $grade
    $menu=Read-Frame $rulesRegion 'material-rules'
    $stage=Find-UpgradeControl $menu @('下一阶段','强化至下一阶段','下一个词条刷新节点','下次词条刷新','下次副属性提升') $rulesRegion
    if(-not$stage){throw '未找到强化至下一阶段选项。'};Click-Control $stage
    $menu=Read-Frame $rulesRegion 'material-rules'
    $confirm=Find-UpgradeControl $menu @('确认','确定') $rulesRegion
    if($confirm){Click-Control $confirm}else{
      # A harmless heading outside the popover closes compact rule panels.
      $heading=Find-UpgradeControl (Read-Frame $materialHeader 'material-header') @('消耗材料') $materialHeader
      if(-not$heading){throw '无法关闭置入规则面板。'};Click-Control $heading
    }
    $caption=Read-Frame $materialHeader 'material-caption'
    if(-not(Test-UpgradeMaterialCaption $caption)){throw '材料规则未确认为四星及以下。'}
}
function Count-EmptySlots {
    $b=[RelicNative]::Capture($window);try{$crop=[RelicNative]::Crop($b,$materialSlots.x,$materialSlots.y,$materialSlots.width,$materialSlots.height);try{return [RelicNative]::CountEmptyMaterialSlots($crop)}finally{$crop.Dispose()}}finally{$b.Dispose()}
}
function Prepare-Enhancement($Candidate,$Observation,[int]$Target,$ActiveStats){
    Click-Text @('强化') @{x=1400;y=915;width=500;height=160} 'open-enhance'|Out-Null
    Start-Sleep -Milliseconds 650;Assert-EnhancementScreen;Assert-OldStats $ActiveStats
    if((Count-EmptySlots)-ne 8){
      $clear=Find-UpgradeControl (Read-Frame $materialHeader 'material-header') @('清空','全部移除','全部清除') $materialHeader
      if($clear){Click-Control $clear}
      if((Count-EmptySlots)-ne 8){throw '材料槽未确认为八个空槽，未自动添加或强化。'}
    }
    Set-MaterialRules $Target
    Click-Text @('自动置入','自动添加') $materialHeader 'auto-fill'|Out-Null
    Start-Sleep -Milliseconds 400
    Get-UpgradeProjection (Read-Frame $levelRow 'level-preview') $Observation.enhance $Target|Out-Null
    if(-not(Test-UpgradeMaterialCaption (Read-Frame $materialHeader 'material-caption'))){throw '自动添加后材料规则发生变化。'}
    if((Count-EmptySlots)-eq 8){throw '没有添加到可用强化材料。'}
    Assert-OldStats $ActiveStats
    # Persist the actual selected-material/target preview before spending anything.
    $b=[RelicNative]::Capture($window);try{$b.Save((Join-Path $JobDirectory ('prepared-'+$state.confirmedSteps+'.png')),[Drawing.Imaging.ImageFormat]::Png)}finally{$b.Dispose()}
}
function Confirm-Enhancement($Observation,[int]$Target){
    Assert-EnhancementScreen
    Get-UpgradeProjection (Read-Frame $levelRow 'level-preview-final') $Observation.enhance $Target|Out-Null
    if(-not(Test-UpgradeMaterialCaption (Read-Frame $materialHeader 'material-caption-final'))){throw '强化前材料规则无法核实。'}
    Check-Stop
    Click-Text @('强化') @{x=1350;y=900;width=540;height=165} 'confirm-enhance'|Out-Null
    $script:state.submittedSteps=[int]$script:state.submittedSteps+1;Save-State 'running' ('已提交强化至 +'+$Target+'，正在核对结果…')
    Start-Sleep -Milliseconds 650
    $notice=Read-Frame @{x=380;y=240;width=1160;height=650} 'material-notice';$noticeText=Text-Of $notice
    if($noticeText-match'消耗|使用'-and$noticeText-match'已强化|强化过'-and$noticeText-match'遗器'){
      if($noticeText-match'5星|五星|已锁定|已装备'){throw '出现不允许的材料确认提示，已停止。'}
      $confirm=Find-UpgradeControl $notice @('确认','确定') @{x=380;y=240;width=1160;height=650}
      if(-not$confirm){throw '强化材料确认控件不唯一或缺失。'};Click-Control $confirm;Start-Sleep -Milliseconds 650
    }
    for($n=0;$n-lt 4;$n++){
      if(Is-Inventory){return}
      $lines=Read-Frame @{x=400;y=500;width=1100;height=540} 'upgrade-result';$close=Find-UpgradeControl $lines @('点击空白处关闭','点击任意空白处关闭') @{x=400;y=500;width=1100;height=540}
      if($close){Click-Control $close}else{Check-Stop;[RelicNative]::TapNavigation($window,'Escape');Start-Sleep -Milliseconds 650}
    }
    if(-not(Is-Inventory)){throw '强化后未返回遗器背包，已停止。'}
}
function Cancel-PreparedEnhancement {
    for($n=0;$n-lt 4;$n++){
      if(Is-Inventory){return}
      Check-Stop;[RelicNative]::TapNavigation($window,'Escape');Start-Sleep -Milliseconds 450
      $lines=Read-Frame @{x=380;y=240;width=1160;height=650} 'cancel-preview'
      $text=Text-Of $lines
      if($text-match'取消|放弃'-and$text-match'本次强化|已选择的材料'){
        $ok=Find-UpgradeControl $lines @('确认','确定') @{x=380;y=240;width=1160;height=650};if($ok){Click-Control $ok}
      }
    }
    if(-not(Is-Inventory)){throw '预览后未能退出强化界面。'}
}
