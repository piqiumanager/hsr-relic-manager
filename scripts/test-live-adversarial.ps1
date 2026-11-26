$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;. (Join-Path $root 'marker-core.ps1');. (Join-Path $root 'live-core.ps1');$checks=0
function Clone($v){ConvertFrom-Json (ConvertTo-Json -InputObject $v -Depth 20)}
function Assert($v,$label){if(-not$v){throw $label};$script:checks++}
$raw=@{_uid='synthetic';rarity=5;pieceName='synthetic';set_id='117';slot='Head';mainstat='HP';level=12;mainstat_value=587;substats=@(@{key='ATK';value=55},@{key='SPD';value=6},@{key='CRIT DMG';value=5.1},@{key='DEF';value=16});preview_substats=@();lock=$false;discard=$false;location=''}
foreach($value in @([double]::NaN,[double]::PositiveInfinity,[double]::NegativeInfinity,$null,0,-1,'55',$true)){
 $r=Clone $raw;$r.substats[0].value=$value;Assert (-not(Test-LiveIdentity $raw $r)) 'Identity rejects malformed substat'
 $r=Clone $raw;$r.mainstat_value=$value;Assert (-not(Test-LiveIdentity $raw $r)) 'Identity rejects malformed main'
}
foreach($key in @('set_id','pieceName','slot','mainstat','_uid','lock','discard','location')){
 $r=Clone $raw;switch($key){'lock'{$r.lock=$true};'discard'{$r.discard=$true};default{$r.$key='other'}}
 $bad=$false;try{Assert-LiveDecision @{requestId='a';observation=$raw} @{requestId='a';action='markDiscard';verified=$true;observation=$r;averagePotential=1}|Out-Null}catch{$bad=$true};Assert $bad ('Decision binding: '+$key)
}
$pixels=Clone $raw;$pixels|Add-Member -NotePropertyName numericImages -NotePropertyValue @('synthetic-only');$pixels|Add-Member -NotePropertyName numericFingerprint -NotePropertyValue 'current-pixels';$pixels.level=-1;$pixels.mainstat_value=0
$resolved=Clone $raw;$resolved|Add-Member -NotePropertyName numericFingerprint -NotePropertyValue 'current-pixels'
Assert (Assert-LiveObservation $pixels $resolved) 'Numeric handoff accepts matching frame and labels'
$resolved.numericFingerprint='old-pixels';$bad=$false;try{Assert-LiveObservation $pixels $resolved}catch{$bad=$true};Assert $bad 'Numeric handoff rejects another frame'
$resolved.numericFingerprint='current-pixels';$resolved.substats[0].key='DEF';$bad=$false;try{Assert-LiveObservation $pixels $resolved}catch{$bad=$true};Assert $bad 'Numeric handoff rejects changed stat labels'
$req=@{requestId='a';upgrade=$true;observation=$raw}
foreach($lower in @($null,79.99,[double]::NaN,[double]::PositiveInfinity,91)){$bad=$false;try{Assert-LiveDecision $req @{requestId='a';action='enhance';verified=$true;observation=(Clone $raw);targetLevel=15;averagePotential=90;averageLower=$lower} $true $true|Out-Null}catch{$bad=$true};Assert $bad 'Enhancement requires a valid lower bound of at least 80'}
Assert (Assert-LiveDecision $req @{requestId='a';action='enhance';verified=$true;observation=(Clone $raw);targetLevel=15;averagePotential=90;averageLower=80} $true $true) 'Exact lower boundary 80 permits the next stage'
foreach($n in @(0,3000)){Assert ((Get-LiveInventoryCount @(@{text=('遗器数量 '+$n+'/3000')}))-eq$n) 'Valid inventory capacity boundary'}
$bad=$false;try{Get-LiveInventoryCount @(@{text='遗器数量 9999/3000'})}catch{$bad=$true};Assert $bad 'OCR count beyond inventory capacity is rejected'
foreach($value in @('1',$true)){$bad=$false;try{Assert-LiveDecision @{requestId='a';observation=$raw} @{requestId='a';action='markDiscard';verified=$true;observation=(Clone $raw);averagePotential=$value}|Out-Null}catch{$bad=$true};Assert $bad 'Score must be a numeric value'}
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'server.ps1'),[ref]$tokens,[ref]$errors)
foreach($f in $ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$true)|Where-Object{$_.Name-eq'Get-MarkerStatus'}){Invoke-Expression $f.Extent.Text}
$job=Join-Path $root ('work/dead-worker-'+[Guid]::NewGuid().ToString('N'));[IO.Directory]::CreateDirectory($job)|Out-Null;$utf8=New-Object Text.UTF8Encoding($false)
$script:markerJob=@{kind='live';directory=$job;process=[pscustomobject]@{HasExited=$true};started=Get-Date}
[IO.File]::WriteAllText((Join-Path $job 'status.json'),(ConvertTo-Json @{state='awaitingScore';marked=2;request=@{requestId='stale'}} -Compress),$utf8)
[IO.File]::WriteAllText((Join-Path $job 'failure.log'),"Original worker error`nstack trace",$utf8)
$dead=Get-MarkerStatus;Assert ($dead.state-eq'failed'-and$dead.message-match'Original worker error'-and-not$dead.request) 'An exited worker reports its real error and removes the obsolete request'
Write-Output ('Adversarial identity/decision checks passed: '+$checks+'; no native input or window access.')
