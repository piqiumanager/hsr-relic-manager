# Read-only game navigation, shared by account scanning and the pre-run account check.
function Read-RosterRegion($Bitmap,$Rect,[string]$Name){
    $b=[RelicNative]::Crop($Bitmap,$Rect.x,$Rect.y,$Rect.width,$Rect.height)
    try{if($Name-eq'summary'){$g=[Drawing.Graphics]::FromImage($b);try{$g.FillRectangle([Drawing.Brushes]::Black,4,8,32,85)}finally{$g.Dispose()}};$file=Join-Path $JobDirectory ('roster-'+$Name+'.png');$b.Save($file,[Drawing.Imaging.ImageFormat]::Png);return ,(Read-MarkerOcr $file)}finally{$b.Dispose()}
}
function Open-GameAccountMenu {
    for($attempt=0;$attempt-lt 6;$attempt++){
        Check-Stop;$frame=[RelicNative]::Capture($window)
        try{
            $lines=Read-RosterRegion $frame @{x=0;y=0;width=1920;height=1080} 'menu'
            $entries=Get-RosterMenuEntries $lines
            $role=@($entries|Where-Object{(Normalize-RosterText $_.text)-ceq'角色'-and$_.x-ge 1230-and$_.y-ge 250-and$_.y-le 1030})
            $bag=@($entries|Where-Object{(Normalize-RosterText $_.text)-ceq'背包'-and$_.x-ge 1230-and$_.y-ge 250})
            if($role.Count-eq 1-and$bag.Count-eq 1){$uid=Get-RosterAccountUid $lines;return @{accountUid=$uid;rolePoint=@([int]($role[0].x+$role[0].width/2),[int]($role[0].y+$role[0].height/2))}}
        }finally{$frame.Dispose()}
        [RelicNative]::TapNavigation($window,'Escape');Start-Sleep -Milliseconds 600
    }
    throw '未找到手机菜单的角色入口，请退出对话或战斗后重试。'
}
function Assert-RosterAccount([string]$ExpectedUid){
    $menu=Open-GameAccountMenu
    if($menu.accountUid-cne$ExpectedUid){throw '当前游戏账号与已读取的五星名单不一致，请到“账号角色”重新读取。'}
    Check-Stop;[RelicNative]::TapNavigation($window,'Escape');Start-Sleep -Milliseconds 450
}
function Assert-RosterDetailScreen($Frame){
    $lines=Read-RosterRegion $Frame @{x=90;y=120;width=270;height=460} 'tabs';$text=Normalize-RosterText (($lines|ForEach-Object{$_.text})-join'')
    if($text-notmatch'详情'-or$text-notmatch'光锥'-or$text-notmatch'星魂'){throw '未确认进入已拥有角色详情界面。'}
}
function Read-RosterCharacter {
    $last=$null
    for($retry=0;$retry-lt 3;$retry++){
        Check-Stop;$frame=[RelicNative]::Capture($window)
        try{Assert-RosterDetailScreen $frame;$lines=Read-RosterRegion $frame @{x=1480;y=112;width=410;height=180} 'summary'}finally{$frame.Dispose()}
        try{$item=ConvertFrom-RosterSummary $lines $data}catch{$item=$null;$parseError=$_}
        if($item){if($last-and$last.id-ceq$item.id-and$last.level-eq$item.level){return $item};$last=$item}
        Start-Sleep -Milliseconds 200
    }
    # The protagonist can have a custom nickname. Confirm its information text; never guess by name/path.
    Check-Stop;[RelicNative]::ClickVerifiedControl($window,243,623);Start-Sleep -Milliseconds 350
    $frame=[RelicNative]::Capture($window);try{$intro=Read-RosterRegion $frame @{x=1480;y=330;width=410;height=230} 'intro'}finally{$frame.Dispose()}
    Check-Stop;[RelicNative]::ClickVerifiedControl($window,243,155);Start-Sleep -Milliseconds 350
    if(Test-RosterTrailblazerIntro $intro){return ConvertFrom-RosterSummary $lines $data $true}
    if($parseError){throw $parseError};throw '角色名称或等级持续变化，未得到稳定结果。'
}
function Select-RosterAvatar([int]$X){
    Check-Stop;if($X-lt 470-or$X-gt 1440){throw '头像位置超出角色顶栏。'}
    [RelicNative]::ClickVerifiedControl($window,$X,65);[RelicNative]::HoverControl($window,1450,620);Start-Sleep -Milliseconds 200
    return Read-RosterCharacter
}
function Get-RosterSlots {
    Check-Stop;$frame=[RelicNative]::Capture($window)
    try{Assert-RosterDetailScreen $frame;$slots=@([RelicNative]::RosterAvatarSlots($frame));if($slots.Count-lt 1-or$slots.Count-gt 13){throw '未能识别角色顶栏头像，读取未完成。'};return ,$slots}finally{$frame.Dispose()}
}
