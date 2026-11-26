function Start-LiveWorker($Body){
    Assert-MarkerIdle
    foreach($key in @('current','average','best')){if($null-eq$Body.settings.$key-or[double]$Body.settings.$key-lt 0-or[double]$Body.settings.$key-gt 100){throw '评分门槛无效。'}}
    $Body.settings.current=80;$Body.settings.average=80;$Body.settings.best=0
    $id='live-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
    $dir=Join-Path (Join-Path $dataBase 'marker-runs') $id;[IO.Directory]::CreateDirectory($dir)|Out-Null
    $file=Join-Path $dir 'plan.json';$roster=Get-AccountRoster
    $data=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $base 'source/data.json'),$utf8));Assert-AccountRoster $roster $data|Out-Null
    $Body.settings.scope='owned';$characters=@($roster.characters)
    [IO.File]::WriteAllText($file,(Json @{settings=$Body.settings;characters=$characters;requireOwned=$true;accountUid=$roster.accountUid;rosterDigest=$roster.digest;maxMarks=$ValidationMarks;unfinishedOnly=$false;averageThreshold=80;currentThreshold=80;allowUnlockLowPotential=$true;upgrade=($Body.upgrade-eq$true-and-not$Body.previewOnly)}),$utf8)
    $args='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+(Join-Path $base 'live.ps1')+'" -JobDirectory "'+$dir+'" -PlanPath "'+$file+'" -DataRoot "'+$dataBase+'"'
    if($Body.previewOnly){$args+=' -PreviewOnly'};if($Body.upgrade-eq$true-and-not$Body.previewOnly){$args+=' -Upgrade'}
    $p=Start-GameWorker $args
    $script:markerJob=@{id=$id;directory=$dir;process=$p;started=Get-Date;kind='live';allowUnlockLowPotential=$true;upgrade=($Body.upgrade-eq$true-and-not$Body.previewOnly)}
    return @{kind='live';state='starting';jobId=$id}
}
function Accept-LiveDecision($Decision){
    if(-not$script:markerJob-or$script:markerJob.kind-ne'live'){throw '没有进行中的现场扫描。'}
    $file=Join-Path $script:markerJob.directory 'request.json';$request=ConvertFrom-Json ([IO.File]::ReadAllText($file,$utf8));Assert-LiveDecision $request $Decision ($script:markerJob.allowUnlockLowPotential-eq$true) ($script:markerJob.upgrade-eq$true)|Out-Null
    if($request.requestId-notmatch'^[a-f0-9]{32}$'){throw '评分请求无效。'}
    $answer=Join-Path $script:markerJob.directory ('decision-'+$request.requestId+'.json')
    if(-not(Test-Path -LiteralPath $answer)){[IO.File]::WriteAllText($answer+'.tmp',(Json $Decision),$utf8);Move-Item -LiteralPath ($answer+'.tmp') -Destination $answer -Force}
    return @{state='accepted'}
}
function Get-LiveSnapshot {
    if(-not$script:markerJob-or$script:markerJob.kind-ne'live'){throw '没有现场读取记录。'}
    $file=Join-Path $script:markerJob.directory 'snapshot.json';if(-not(Test-Path -LiteralPath $file)){return Json @{state='empty'}}
    $raw=[IO.File]::ReadAllText($file,$utf8);$parsed=ConvertFrom-Json $raw;$status=Get-MarkerStatus;$id=$script:markerJob.id
    if(-not$parsed.metadata.partial-and-not$parsed.metadata.unrecognized-and-not$parsed.metadata.pending-and$status.state-eq'complete'){
      $script:capture=@{id=$id;state='complete';json=$raw;started=Get-Date};$dir=Join-Path $dataBase 'captures';[IO.Directory]::CreateDirectory($dir)|Out-Null;[IO.File]::WriteAllText((Join-Path $dir ($id+'.json')),$raw,$utf8)
      return '{"state":"complete","captureId":'+(Json $id)+',"data":'+$raw+'}'
    }
    return '{"state":"partial","data":'+$raw+'}'
}
