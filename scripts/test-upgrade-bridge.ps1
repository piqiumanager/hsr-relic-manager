$ErrorActionPreference='Stop';$base=Split-Path $PSScriptRoot -Parent;$utf8=New-Object Text.UTF8Encoding($false)
. (Join-Path $base 'upgrade-core.ps1')
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $base 'server.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Server syntax failed'}
foreach($f in $ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$true)){Invoke-Expression $f.Extent.Text}
$script:checks=0;function Assert($v,$name){if(-not$v){throw $name};$script:checks++}
$planText=[IO.File]::ReadAllText((Join-Path $base 'work/upgrade-plan-fixture.json'),$utf8);$plan=ConvertFrom-Json $planText
$script:capture=@{state='complete';id='synthetic-capture';started=Get-Date;json=[IO.File]::ReadAllText((Join-Path $base 'work/upgrade-snapshot-fixture.json'),$utf8)}
Assert (Validate-UpgradePlan $plan) 'Actual upgrade plan accepted'
function Reject($p,$name){$bad=$false;try{Validate-UpgradePlan $p}catch{$bad=$true};Assert $bad $name}
$p=ConvertFrom-Json $planText;$p.policy.threshold=79;Reject $p 'Threshold mutation rejected'
$p=ConvertFrom-Json $planText;$p.policy.maxRelicMaterialRarity=5;Reject $p 'Five-star material policy rejected'
$p=ConvertFrom-Json $planText;$p.allowSalvage=$true;Reject $p 'Salvage rejected'
$dir=Join-Path $base ('work/upgrade-bridge-'+[Guid]::NewGuid().ToString('N'));[IO.Directory]::CreateDirectory($dir)|Out-Null
$requestText=[IO.File]::ReadAllText((Join-Path $base 'work/upgrade-request-fixture.json'),$utf8);[IO.File]::WriteAllText((Join-Path $dir 'request.json'),$requestText,$utf8)
$req=ConvertFrom-Json $requestText;$script:markerJob=@{kind='upgrade';directory=$dir;process=[pscustomobject]@{HasExited=$false};started=Get-Date}
$answer=@{requestId=$req.requestId;action='enhance';targetLevel=3;lower=90;upper=90}
$accepted=Accept-UpgradeDecision $answer;Assert ($accepted.state-eq'accepted') 'Score response accepted'
Assert (Test-Path -LiteralPath (Join-Path $dir ('decision-'+$req.requestId+'.json'))) 'Decision atomically delivered'
$bad=$false;try{Accept-UpgradeDecision @{requestId='outdated';action='enhance';targetLevel=3;lower=90;upper=90}}catch{$bad=$true};Assert $bad 'Old request rejected'
[IO.File]::WriteAllText((Join-Path $dir 'status.json'),(Json @{kind='upgrade';state='awaitingScore';confirmedSteps=0;marked=0;request=$req}),$utf8)
$bad=$false;try{Assert-MarkerIdle}catch{$bad=$true};Assert $bad 'Parallel job blocked while scoring'
[IO.File]::WriteAllText((Join-Path $dir 'status.json'),(Json @{kind='upgrade';state='running';confirmedSteps=1;marked=0}),$utf8)
Get-MarkerStatus|Out-Null;Assert ($script:capture.invalidated-eq$true) 'Old capture invalidated after enhancement'
Reject $plan 'Stale capture cannot restart enhancement'
Write-Output ('Upgrade snapshot/IPC checks passed: '+$script:checks+'; no worker started.')
