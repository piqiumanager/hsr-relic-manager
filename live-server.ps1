function Start-LiveWorker($Body){
    Assert-MarkerIdle
    foreach($key in @('current','average','best')){if($null-eq$Body.settings.$key-or[double]$Body.settings.$key-lt 0-or[double]$Body.settings.$key-gt 100){throw '评分门槛无效。'}}
    $Body.settings.current=0;$Body.settings.average=80;$Body.settings.best=0
    $id='live-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
    $dir=Join-Path (Join-Path $dataBase 'marker-runs') $id;[IO.Directory]::CreateDirectory($dir)|Out-Null
    $file=Join-Path $dir 'plan.json';$characters=@();$saved=Join-Path $dataBase 'captures'
    if(Test-Path -LiteralPath $saved){$latest=Get-ChildItem -LiteralPath $saved -Filter '*.json' -File|Sort-Object LastWriteTime -Descending|Select-Object -First 1;if($latest){try{$characters=@((ConvertFrom-Json ([IO.File]::ReadAllText($latest.FullName,$utf8))).characters|Where-Object{$null-ne$_})}catch{}}}
    if($Body.settings.scope-eq'owned'-and$characters.Count-eq 0){throw '没有已拥有角色列表，请在设置中选择全部已收录五星。'}
    [IO.File]::WriteAllText($file,(Json @{settings=$Body.settings;characters=$characters;maxMarks=$ValidationMarks;unfinishedOnly=$true;averageThreshold=80;allowUnlockLowPotential=$true}),$utf8)
    $args='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+(Join-Path $base 'live.ps1')+'" -JobDirectory "'+$dir+'" -PlanPath "'+$file+'" -DataRoot "'+$dataBase+'"'
    if($Body.previewOnly){$args+=' -PreviewOnly'}
    $p=Start-GameWorker $args
    $script:markerJob=@{id=$id;directory=$dir;process=$p;started=Get-Date;kind='live';allowUnlockLowPotential=$true}
    return @{kind='live';state='starting';jobId=$id}
}
function Accept-LiveDecision($Decision){
    if(-not$script:markerJob-or$script:markerJob.kind-ne'live'){throw '没有进行中的现场扫描。'}
    $file=Join-Path $script:markerJob.directory 'request.json';$request=ConvertFrom-Json ([IO.File]::ReadAllText($file,$utf8));Assert-LiveDecision $request $Decision ($script:markerJob.allowUnlockLowPotential-eq$true)|Out-Null
    if($request.requestId-notmatch'^[a-f0-9]{32}$'){throw '评分请求无效。'}
    $answer=Join-Path $script:markerJob.directory ('decision-'+$request.requestId+'.json')
    if(-not(Test-Path -LiteralPath $answer)){[IO.File]::WriteAllText($answer+'.tmp',(Json $Decision),$utf8);Move-Item -LiteralPath ($answer+'.tmp') -Destination $answer -Force}
    return @{state='accepted'}
}
function Get-LiveSnapshot {
    if(-not$script:markerJob-or$script:markerJob.kind-ne'live'){throw '没有现场读取记录。'}
    $file=Join-Path $script:markerJob.directory 'snapshot.json';if(-not(Test-Path -LiteralPath $file)){return Json @{state='empty'}}
    $raw=[IO.File]::ReadAllText($file,$utf8);$parsed=ConvertFrom-Json $raw;$status=Get-MarkerStatus;$id=$script:markerJob.id
    if(-not$parsed.metadata.partial-and-not$parsed.metadata.unrecognized-and$status.state-eq'complete'){
      $script:capture=@{id=$id;state='complete';json=$raw;started=Get-Date};$dir=Join-Path $dataBase 'captures';[IO.Directory]::CreateDirectory($dir)|Out-Null;[IO.File]::WriteAllText((Join-Path $dir ($id+'.json')),$raw,$utf8)
      return '{"state":"complete","captureId":'+(Json $id)+',"data":'+$raw+'}'
    }
    return '{"state":"partial","data":'+$raw+'}'
}
