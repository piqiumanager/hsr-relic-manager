param([string]$JobDirectory,[string]$DataRoot)
$ErrorActionPreference='Stop';$base=$PSScriptRoot;$utf8=New-Object Text.UTF8Encoding($false)
$state=@{kind='roster';state='starting';scanned=0;ownedFiveStar=0;pages=0;message='正在读取当前账号角色…'}
$characters=New-Object 'Collections.Generic.List[object]';$visited=@{}
function Check-Stop {if((Test-Path -LiteralPath (Join-Path $JobDirectory 'stop'))-or[RelicNative]::StopPressed()){throw(New-Object OperationCanceledException('已停止角色读取，未应用不完整名单。'))}}
function Save-RosterState([string]$Status,[string]$Message){$state.state=$Status;$state.message=$Message;[IO.File]::WriteAllText((Join-Path $JobDirectory 'status.json.tmp'),(ConvertTo-Json $state -Depth 20 -Compress),$utf8);Move-Item -LiteralPath (Join-Path $JobDirectory 'status.json.tmp') -Destination (Join-Path $JobDirectory 'status.json') -Force}
function Save-AccountRoster($Value){$file=Join-Path $DataRoot 'account-roster.json';[IO.File]::WriteAllText($file+'.tmp',(ConvertTo-Json $Value -Depth 25 -Compress),$utf8);Move-Item -LiteralPath ($file+'.tmp') -Destination $file -Force}
function Add-RosterCharacter($Item){
    if($visited.ContainsKey($Item.id)){return};$visited[$Item.id]=$true;$state.scanned=$visited.Count
    if($Item.rarity-eq 5){$characters.Add($Item);$state.ownedFiveStar=$characters.Count}
    Save-RosterState 'running' ('已读取 '+$state.scanned+' 位角色，已有五星 '+$state.ownedFiveStar+' 位。')
}
function Invoke-RosterTraversal {
    $previous=$null;$lastSelected=''
    for($page=0;$page-lt 40;$page++){
        Check-Stop;$state.pages=$page+1;$slots=Get-RosterSlots;$pageIds=@()
        foreach($x in $slots){$item=Select-RosterAvatar $x
            if($lastSelected-ceq$item.id-and$pageIds.Count-gt 0){throw '点击头像后没有切换角色，读取未完成。'}
            if($pageIds-contains$item.id){throw '本页重复识别同一头像，读取未完成。'}
            $pageIds+=,$item.id;$lastSelected=$item.id;Add-RosterCharacter $item
        }
        $first=$pageIds[0];$moved=$false
        for($retry=0;$retry-lt 2;$retry++){
            Check-Stop;[RelicNative]::DragRosterBar($window,$true);Start-Sleep -Milliseconds 350
            $nextSlots=Get-RosterSlots;$next=Select-RosterAvatar $nextSlots[0]
            if($next.id-cne$first){$moved=$true;break}
        }
        if(-not$moved){return}
        # Every page must overlap a verified character; a drag cannot jump over unseen characters.
        for($back=0;-not$visited.ContainsKey($next.id)-and$back-lt 3;$back++){
            Check-Stop;[RelicNative]::DragRosterBar($window,$false);Start-Sleep -Milliseconds 350
            $nextSlots=Get-RosterSlots;$next=Select-RosterAvatar $nextSlots[0]
        }
        if(-not$visited.ContainsKey($next.id)){throw '角色顶栏翻页缺少重叠，无法确认没有漏读。'}
        if($previous-and$previous-ceq($pageIds-join',')){throw '角色顶栏反复返回同一页，读取未完成。'}
        $previous=$pageIds-join',';$lastSelected=''
    }
    throw '角色翻页次数超过上限，读取未完成。'
}
try{
    [IO.Directory]::CreateDirectory($JobDirectory)|Out-Null;Save-RosterState 'starting' '正在连接游戏并读取账号角色…'
    Add-Type -AssemblyName System.Drawing;Add-Type -AssemblyName System.Windows.Forms
    Add-Type -Path (Join-Path $base 'marker-native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
    . (Join-Path $base 'marker-core.ps1');. (Join-Path $base 'roster-core.ps1');. (Join-Path $base 'roster-navigation.ps1')
    [RelicNative]::SetProcessDPIAware()|Out-Null;Initialize-MarkerOcr
    $window=[RelicNative]::FindGame();if($window.Width-ne 1920-or$window.Height-ne 1080){throw '角色读取需要 1920×1080 客户区。'}
    $data=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $base 'source/data.json'),$utf8));[RelicNative]::Activate($window)
    $menu=Open-GameAccountMenu;$uid=$menu.accountUid
    [RelicNative]::ClickVerifiedControl($window,$menu.rolePoint[0],$menu.rolePoint[1]);Start-Sleep -Milliseconds 800
    Invoke-RosterTraversal;Check-Stop
    # Return to the menu and bind the completed scan to the same account again.
    $after=Open-GameAccountMenu;if($after.accountUid-cne$uid){throw '读取期间账号发生变化，名单未应用。'}
    $result=@{state='complete';complete=$true;source='game-character-ocr';accountUid=$uid;characters=$characters.ToArray();visitedCount=$visited.Count;pages=$state.pages;readAt=[DateTime]::UtcNow.ToString('o');digest=(Get-RosterDigest $uid $characters.ToArray())}
    Assert-AccountRoster $result $data|Out-Null;Save-AccountRoster $result;Save-RosterState 'complete' ('已读取已有五星 '+$characters.Count+' 位，筛选与强化均只按这些角色评分。')
}catch{
    $status=if($_.Exception.GetBaseException()-is[OperationCanceledException]){'stopped'}else{'failed'}
    [IO.File]::WriteAllText((Join-Path $JobDirectory 'failure.log'),($_.ToString()+"`n"+$_.ScriptStackTrace),$utf8)
    Save-AccountRoster @{state=$status;complete=$false;source='game-character-ocr';characters=$characters.ToArray();message=$_.Exception.Message}
    Save-RosterState $status $_.Exception.Message;if($status-eq'failed'){exit 1}
}
