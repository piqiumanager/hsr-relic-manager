$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$utf8=New-Object Text.UTF8Encoding($false)
. (Join-Path $root 'live-core.ps1');. (Join-Path $root 'live-server.ps1')
$dataBase=Join-Path $root ('work/live-bridge-'+[Guid]::NewGuid().ToString('N'));$base=$root;$ValidationMarks=3;$script:starts=0;$script:checks=0
function Json($v){ConvertTo-Json $v -Depth 30 -Compress}
function Assert($v,$name){if(-not$v){throw $name};$script:checks++}
function Assert-MarkerIdle {}
function Start-GameWorker($arguments){$script:starts++;$script:arguments=$arguments;return [pscustomobject]@{HasExited=$false}}
$body=@{settings=@{current=75;average=70;best=85;scope='all'};previewOnly=$true}
$job=Start-LiveWorker $body
Assert ($job.kind-eq'live'-and$script:starts-eq 1) 'One-click starts current-screen worker without capture ID'
Assert ($arguments-match'live.ps1'-and$arguments-match'PreviewOnly'-and$arguments-notmatch'Reliquary') 'Read-only start does not launch login capture'
$plan=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $markerJob.directory 'plan.json'),$utf8));Assert ($plan.maxMarks-eq 3) 'Validation mark limit is passed to worker'
$request=@{requestId='11111111111111111111111111111111';observation=@{rarity=5;lock=$false;discard=$false;location=''}}
[IO.File]::WriteAllText((Join-Path $markerJob.directory 'request.json'),(Json $request),$utf8)
$answer=@{requestId=$request.requestId;action='markDiscard';verified=$true;raw=@{};observation=@{level=12};averagePotential=79.9}
$result=Accept-LiveDecision $answer;Assert ($result.state-eq'accepted') 'Verified response delivered'
Assert ($plan.settings.average-eq 80-and$plan.settings.current-eq 80-and$plan.settings.best-eq 0-and-not$plan.unfinishedOnly) 'Old settings cannot restore the former 70/85 cleanup rule'
$answer.requestId='old';$bad=$false;try{Accept-LiveDecision $answer}catch{$bad=$true};Assert $bad 'Stale response rejected'
function Get-MarkerStatus {return @{state='stopped'}}
$raw=@{relics=@(@{_uid='synthetic';rarity=5});metadata=@{partial=$true;unrecognized=0}}
[IO.File]::WriteAllText((Join-Path $markerJob.directory 'snapshot.json'),(Json $raw),$utf8)
$snapshot=ConvertFrom-Json (Get-LiveSnapshot);Assert ($snapshot.state-eq'partial'-and-not$snapshot.captureId) 'Partial snapshot cannot authorize enhancement'
function Get-MarkerStatus {return @{state='complete'}}
$raw.metadata.partial=$false;[IO.File]::WriteAllText((Join-Path $markerJob.directory 'snapshot.json'),(Json $raw),$utf8)
$snapshot=ConvertFrom-Json (Get-LiveSnapshot);Assert ($snapshot.captureId-eq$markerJob.id-and$capture.state-eq'complete') 'Complete snapshot persisted without relogin'
$raw.metadata.unrecognized=1;[IO.File]::WriteAllText((Join-Path $markerJob.directory 'snapshot.json'),(Json $raw),$utf8)
$snapshot=ConvertFrom-Json (Get-LiveSnapshot);Assert ($snapshot.state-eq'partial'-and-not$snapshot.captureId) 'Unrecognized items cannot authorize enhancement even after full traversal'
$body.upgrade=$true;$body.previewOnly=$false;Start-LiveWorker $body|Out-Null
Assert ($arguments-match' -Upgrade'-and$markerJob.upgrade-eq$true) 'Enhancement starts without a complete inventory snapshot'
$body.settings.scope='owned';$starts=$script:starts;$bad=$false;try{Start-LiveWorker $body}catch{$bad=$true};Assert ($bad-and$script:starts-eq$starts) 'Missing owned roster rejected before worker launch'
Write-Output ('Live API/IPC checks passed: '+$script:checks+'; worker launches are mocked, real game input: 0')
