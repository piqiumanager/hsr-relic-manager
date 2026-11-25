$ErrorActionPreference='Stop'
$utf8=New-Object Text.UTF8Encoding($false)
$base=Split-Path $PSScriptRoot -Parent
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $base 'server.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'server syntax failed'}
$functions=$ast.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst]},$true)
foreach($f in $functions){Invoke-Expression $f.Extent.Text}
$script:capture=@{id='synthetic-test-capture';state='complete';started=Get-Date;json=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fixtures/snapshot.json'),$utf8)}
$planText=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fixtures/plan.json'),$utf8)
$plan=ConvertFrom-Json $planText
$checks=0
if(-not (Validate-MarkerPlan $plan)){throw 'valid snapshot plan rejected'};$checks++
function Must-Reject($plan,[string]$name){$reject=$false;try{Validate-MarkerPlan $plan|Out-Null}catch{$reject=$true};if(-not $reject){throw ('Invalid plan accepted: '+$name)};$script:checks++}
$p=ConvertFrom-Json $planText;$p.captureId='old';Must-Reject $p 'different capture'
$p=ConvertFrom-Json $planText;$p.allowSalvage=$true;Must-Reject $p 'salvage permission'
$p=ConvertFrom-Json $planText;$p.candidates[0].pieceName='错误遗器';Must-Reject $p 'wrong piece name'
$p=ConvertFrom-Json $planText;$p.candidates[0].visualSubstats[0].value=1;Must-Reject $p 'changed substat'
$p=ConvertFrom-Json $planText;$p.candidates[0].count=2;$p.candidates[0].ids=@('1','1');$p.total=2;Must-Reject $p 'duplicate IDs'
$p=ConvertFrom-Json $planText;$p.total=7;Must-Reject $p 'inconsistent total'
$script:capture.started=(Get-Date).AddMinutes(-31);Must-Reject $plan 'stale snapshot';$script:capture.started=Get-Date
$snapshot=ConvertFrom-Json $script:capture.json;$snapshot.relics[0].lock=$true;$script:capture.json=ConvertTo-Json $snapshot -Depth 30;Must-Reject $plan 'currently locked source'
$script:capture.json=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'fixtures/snapshot.json'),$utf8)
$snapshot=ConvertFrom-Json $script:capture.json;$snapshot.relics[0].location='1308';$script:capture.json=ConvertTo-Json $snapshot -Depth 30;Must-Reject $plan 'currently equipped source'
Write-Output ('Snapshot/API marker validation checks passed: '+$checks)
