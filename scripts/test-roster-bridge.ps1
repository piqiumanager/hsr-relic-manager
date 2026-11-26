$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$base=$root;$utf8=New-Object Text.UTF8Encoding($false);$checks=0;$starts=0
. (Join-Path $root 'roster-core.ps1');. (Join-Path $root 'roster-server.ps1');. (Join-Path $root 'live-core.ps1');. (Join-Path $root 'live-server.ps1')
$dataBase=Join-Path $root ('work/roster-bridge-'+[Guid]::NewGuid().ToString('N'));[IO.Directory]::CreateDirectory($dataBase)|Out-Null;$ValidationMarks=0
function Json($v){ConvertTo-Json -InputObject $v -Depth 30 -Compress}
function Assert($v,$m){if(-not$v){throw $m};$script:checks++}
function Bad($fn,$name){$bad=$false;try{& $fn|Out-Null}catch{$bad=$true};Assert $bad $name}
function Assert-MarkerIdle {}
function Start-GameWorker($Arguments){$script:starts++;$script:lastArgs=$Arguments;return [pscustomobject]@{HasExited=$false}}
Assert ((Get-AccountRoster).state-eq'empty') 'Fresh install has no invented ownership'
$body=@{settings=@{current=80;average=80;best=0;scope='all'};upgrade=$true;previewOnly=$false}
Bad {Start-LiveWorker $body} 'Neither all-character settings nor missing roster can start worker';Assert ($starts-eq 0) 'Missing roster launches no process'
$chars=@(@{id='1003';name='姬子';rarity=5;path='智识';level=80});$r=@{state='complete';complete=$true;source='game-character-ocr';accountUid='900000001';characters=$chars;visitedCount=2;digest=(Get-RosterDigest '900000001' $chars)}
[IO.File]::WriteAllText((Join-Path $dataBase 'account-roster.json'),(Json $r),$utf8)
Assert ((Get-AccountRoster).characters.Count-eq 1) 'Completed scan reloads from local storage'
$job=Start-LiveWorker $body;$plan=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $markerJob.directory 'plan.json'),$utf8))
Assert ($plan.settings.scope-eq'owned'-and$plan.characters[0].id-eq'1003'-and$plan.characters.Count-eq 1) 'Backend forces the stored account roster rather than client all settings'
Assert ($plan.requireOwned-eq$true-and$plan.accountUid-eq'900000001'-and$plan.rosterDigest-eq$r.digest) 'Live plan binds UID and roster digest'
Assert ($plan.upgrade-eq$true) 'Enhancement uses the same owned list'
$job=Start-AccountRoster;Assert ($job.kind-eq'roster'-and$lastArgs-match'roster.ps1') 'Dedicated reader worker starts'
Assert ((Get-AccountRoster).state-eq'reading') 'Refresh immediately invalidates previous account roster'
$before=$starts;Bad {Start-LiveWorker $body} 'Partial refresh cannot fall back to old or all characters';Assert ($starts-eq$before) 'Incomplete refresh cannot launch a relic worker'
[IO.File]::WriteAllText((Join-Path $dataBase 'account-roster.json'),'{broken',$utf8);Assert ((Get-AccountRoster).state-eq'invalid') 'Corrupt roster is not used'
Add-Type -TypeDefinition 'public static class RelicNative {public static int Taps;public static void TapNavigation(object w,string key){Taps++;}}'
. (Join-Path $root 'roster-navigation.ps1')
function Check-Stop {}
function Start-Sleep {}
function Open-GameAccountMenu {return @{accountUid='900000001'}}
Bad {Assert-RosterAccount '900000002'} 'Current game account mismatch blocks before returning to relic execution'
Assert ([RelicNative]::Taps-eq 0) 'Account mismatch causes no follow-up game input'
Assert-RosterAccount '900000001';Assert ([RelicNative]::Taps-eq 1) 'Matching account returns from the read-only menu check'
Write-Output ('Roster persistence/API checks passed: '+$checks+'; worker starts mocked, no game input.')
