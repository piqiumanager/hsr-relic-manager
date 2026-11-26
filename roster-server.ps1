function Get-AccountRoster {
    $file=Join-Path $dataBase 'account-roster.json'
    if(-not(Test-Path -LiteralPath $file)){return @{state='empty';complete=$false;characters=@()}}
    try{$value=ConvertFrom-Json ([IO.File]::ReadAllText($file,$utf8));if($value.state-eq'complete'){$data=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $base 'source/data.json'),$utf8));Assert-AccountRoster $value $data|Out-Null};return $value}
    catch{return @{state='invalid';complete=$false;characters=@();message=$_.Exception.Message}}
}
function Start-AccountRoster {
    Assert-MarkerIdle
    $id='roster-'+(Get-Date -Format 'yyyyMMdd-HHmmss')+'-'+[Guid]::NewGuid().ToString('N').Substring(0,8)
    $dir=Join-Path (Join-Path $dataBase 'marker-runs') $id;[IO.Directory]::CreateDirectory($dir)|Out-Null
    # Invalidate the previous scan immediately. A stopped/failed refresh cannot reactivate stale ownership.
    [IO.File]::WriteAllText((Join-Path $dataBase 'account-roster.json'),(Json @{state='reading';complete=$false;characters=@()}),$utf8)
    $args='-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File "'+(Join-Path $base 'roster.ps1')+'" -JobDirectory "'+$dir+'" -DataRoot "'+$dataBase+'"'
    try{$p=Start-GameWorker $args;$script:markerJob=@{id=$id;directory=$dir;process=$p;started=Get-Date;kind='roster'}}
    catch{[IO.File]::WriteAllText((Join-Path $dataBase 'account-roster.json'),(Json @{state='failed';complete=$false;characters=@();message=$_.Exception.Message}),$utf8);throw}
    return @{kind='roster';state='starting';jobId=$id}
}
