$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;. (Join-Path $root 'marker-core.ps1');. (Join-Path $root 'live-core.ps1');$checks=0
function Assert($v,$m){if(-not$v){throw $m};$script:checks++}
function Raw([int]$level,[int]$speed){return @{_uid='synthetic';rarity=5;pieceName='wind';set_id='110';slot='Head';level=$level;mainstat='HP';mainstat_value=$(if($level-eq 15){705}else{587});substats=@(@{key='ATK';value=55},@{key='SPD';value=$speed},@{key='CRIT DMG';value=5.1},@{key='DEF';value=16});preview_substats=@();lock=$true;discard=$false;location=''}}
foreach($level in @(0,3,6,9,12,15)){foreach($speed in @(2,6,7,10,12)){$o=Raw $level $speed;$expected=($speed-ge 10-or($level-lt 15-and$speed+.999+(5-[Math]::Floor($level/3))*2.6-ge 10));Assert ((Test-LiveUniversalSpeedProtection $o)-eq$expected) 'Native speed protection follows all levels and ceilings'}}
$o=Raw 15 10;$q=@{requestId='same';observation=$o};$a=@{requestId='same';action='markDiscard';verified=$true;unlockFirst=$true;observation=$o;averagePotential=10;currentScore=10};$bad=$false;try{Assert-LiveDecision $q $a $true $false|Out-Null}catch{$bad=$_.Exception.Message-match'高速保护'};Assert $bad 'A mistaken frontend discard cannot unlock or mark a high-speed wind relic'
$o=Raw 15 6;$q.observation=$o;$a.observation=$o;Assert (Assert-LiveDecision $q $a $true $false) 'Ordinary low-speed wind junk can still be discarded'
$o=Raw 12 7;$q.observation=$o;$a.observation=$o;$bad=$false;try{Assert-LiveDecision $q $a $true $false|Out-Null}catch{$bad=$true};Assert $bad 'Unfinished viable speed embryo is protected by native gate'
$o=Raw 15 2;$o.slot='Feet';$o.mainstat='SPD';Assert (Test-LiveUniversalSpeedProtection $o) 'Wind speed main-stat boots protected'
$o.set_id='117';Assert (-not(Test-LiveUniversalSpeedProtection $o)) 'No unrequested blanket protection for other sets'
$o=Raw 15 6;$q.observation=$o;$a.observation=$o;$q.requireOwned=$true;$q.characters=@(@{id='1004'});$a.targetCharacterId='1308';$bad=$false;try{Assert-LiveDecision $q $a $true $false|Out-Null}catch{$bad=$_.Exception.Message-match'未拥有'};Assert $bad 'Native gate rejects decisions scored for an unowned character'
$a.targetCharacterId='1004b1';Assert (Assert-LiveDecision $q $a $true $false) 'Enhanced build of an owned character is allowed'
$tokens=$null;$parseErrors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'live.ps1'),[ref]$tokens,[ref]$parseErrors);if($parseErrors.Count){throw $parseErrors[0].Message};$fn=$ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]-and$n.Name-eq'Upgrade-LiveRelic'},$true)[0];Invoke-Expression $fn.Extent.Text
function Check-Stop {}
$state=@{kept=0};$o=Raw 12 7;Upgrade-LiveRelic @{action='keep';observation=$o} 0;Assert ($state.kept-eq 1) 'Enhancement stops safely on a protected speed embryo without preparing or consuming materials'
Write-Output ('Native universal-speed checks passed: '+$checks+'; no game input.')
