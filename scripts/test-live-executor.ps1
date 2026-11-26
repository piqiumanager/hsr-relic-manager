# Calls the real worker functions against an in-memory native double. No P/Invoke.
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;using System.Drawing;
public static class RelicNative {
 public static int Clicks,Unlocks;public static bool Marked,Locked,AcceptClick=true,AcceptUnlock=true;
 public static Bitmap Capture(object window){var b=new Bitmap(40,40);using(var g=Graphics.FromImage(b))g.Clear(Marked?Color.Red:Color.Gray);return b;}
 public static Bitmap Crop(Bitmap b,int x,int y,int width,int height){return (Bitmap)b.Clone();}
 public static void ClickDiscard(object w,int x,int y){Clicks++;if(AcceptClick)Marked=true;}
 public static void ClickVerifiedControl(object w,int x,int y){Unlocks++;if(AcceptUnlock)Locked=false;}
 public static void HoverControl(object w,int x,int y){}
 public static int RedPixels(Bitmap b){return b.GetPixel(0,0).R>200?100:0;}
}
'@
. (Join-Path $root 'marker-core.ps1');. (Join-Path $root 'live-core.ps1')
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'live.ps1'),[ref]$t,[ref]$e)
if($e.Count){throw $e[0].Message}
foreach($f in $ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$true)){Invoke-Expression $f.Extent.Text}
$realAsk=${function:Ask-LiveScore}
$window=$null;$layout=@{discardRect=@{x=0;y=0;width=40;height=40};discardPoint=@(2,2);unlockRect=@{x=0;y=0;width=40;height=40}};$utf8=New-Object Text.UTF8Encoding($false);$plan=@{allowUnlockLowPotential=$true}
$JobDirectory=Join-Path $root ('work/live-executor-'+[Guid]::NewGuid().ToString('N'));[IO.Directory]::CreateDirectory($JobDirectory)|Out-Null
$template=@{set_id='117';slot='Head';mainstat='HP';pieceName='synthetic';level=12;mainstat_value=587;substats=@(@{key='ATK';value=55},@{key='SPD';value=6},@{key='CRIT DMG';value=5.1},@{key='DEF';value=16});preview_substats=@();numericFingerprint='numbers';lock=$false;discard=$false;location=''}
$script:checks=0
function Assert($condition,$label){if(-not$condition){throw $label};$script:checks++}
function Reset-Case([string]$Name){$script:case=$Name;$script:selectedTemplate=$template;$script:reads=0;$script:state=@{scanned=1;marked=0;unlocked=0};[RelicNative]::Clicks=0;[RelicNative]::Unlocks=0;[RelicNative]::Locked=$false;[RelicNative]::Marked=$false;[RelicNative]::AcceptClick=$true;[RelicNative]::AcceptUnlock=$true;$script:plan.allowUnlockLowPotential=$true}
function Check-Stop {if($script:case-eq'cancel'-or($script:case-eq'cancel-during-score'-and$script:reads-gt 0)-or($script:case-eq'cancel-after-unlock'-and[RelicNative]::Unlocks-gt 0)){throw(New-Object OperationCanceledException)}}
function Check-Inventory {return $script:case-ne'left-inventory'}
function Read-Selected($b,$index){
 $script:reads++;$r=ConvertFrom-Json (ConvertTo-Json $selectedTemplate -Depth 10);$r.discard=[RelicNative]::Marked;$r.lock=[RelicNative]::Locked;$r.numericFingerprint='different pixels'
 switch($script:case){'locked'{$r.lock=$true};'equipped'{$r.location='equipped'};'changed-before'{$r.substats[0].value=76};'changed-after'{if($script:reads-eq 2){$r.mainstat_value=112}};'changed-after-unlock'{if($script:reads-eq 2){$r.mainstat_value=112}}};return $r
}
function Ask-LiveScore($raw,$intent){return @{action=$(if($raw.discard){'skip'}else{'markDiscard'});verified=$true;averagePotential=79.9;currentScore=79.9;unlockFirst=$raw.lock;observation=$raw;raw=$raw}}
Reset-Case 'success';Mark-LiveRelic $template $template;Assert ($state.marked-eq 1-and[RelicNative]::Clicks-eq 1) 'Exactly one confirmed mark'
Reset-Case 'full-level';$maxed=$template.Clone();$maxed.level=15;$maxed.mainstat_value=705;$script:selectedTemplate=$maxed;Mark-LiveRelic $maxed $maxed;Assert ($state.marked-eq 1-and[RelicNative]::Clicks-eq 1) 'Real marking function marks an unequipped low +15 exactly once'
$lockedTarget=$template.Clone();$lockedTarget.lock=$true
Reset-Case 'unlock-success';[RelicNative]::Locked=$true;$record=$lockedTarget.Clone();Mark-LiveRelic $lockedTarget $lockedTarget $record;Assert ([RelicNative]::Unlocks-eq 1-and[RelicNative]::Clicks-eq 1-and$state.unlocked-eq 1-and$state.marked-eq 1-and$record.lock-eq$false) 'Confirmed unlock followed by exactly one discard; snapshot lock is updated'
foreach($name in @('unlock-no-change','changed-after-unlock','unauthorized-unlock','cancel-after-unlock')){Reset-Case $name;[RelicNative]::Locked=$true;if($name-eq'unlock-no-change'){[RelicNative]::AcceptUnlock=$false};if($name-eq'unauthorized-unlock'){$plan.allowUnlockLowPotential=$false};$bad=$false;try{Mark-LiveRelic $lockedTarget $lockedTarget}catch{$bad=$true};Assert ($bad-and[RelicNative]::Clicks-eq 0-and$state.marked-eq 0-and[RelicNative]::Unlocks-eq$(if($name-eq'unauthorized-unlock'){0}else{1})) ('Unlock failure never discards or retries: '+$name)}
foreach($name in @('locked','equipped','changed-before','cancel','cancel-during-score','left-inventory')){Reset-Case $name;$bad=$false;try{Mark-LiveRelic $template $template}catch{$bad=$true};Assert ($bad-and[RelicNative]::Clicks-eq 0-and$state.marked-eq 0) ('Protected preflight: '+$name)}
Reset-Case 'no-visual-change';[RelicNative]::AcceptClick=$false;$bad=$false;try{Mark-LiveRelic $template $template}catch{$bad=$true};Assert ($bad-and[RelicNative]::Clicks-eq 1-and$state.marked-eq 0) 'Unconfirmed result never retried'
Reset-Case 'changed-after';$bad=$false;try{Mark-LiveRelic $template $template}catch{$bad=$true};Assert ($bad-and[RelicNative]::Clicks-eq 1-and$state.marked-eq 0) 'Post-click changed identity rejected'
# Exercise the real file-based scoring handoff, including stale-response rejection.
Reset-Case 'score'
function Save-State($name,$message){if($name-eq'awaitingScore'){$req=$script:state.request;$answer=@{requestId=$(if($script:case-eq'stale-score'){'old'}else{$req.requestId});action='keep'};[IO.File]::WriteAllText((Join-Path $JobDirectory ('decision-'+$req.requestId+'.json')),(ConvertTo-Json $answer -Compress),$utf8)}}
$plan=@{characters=@()};$observation=$template.Clone();$observation._uid='synthetic'
$answer=& $realAsk $observation;Assert ($answer.action-eq'keep') 'Live scoring IPC accepted matching request'
Reset-Case 'stale-score';$bad=$false;try{& $realAsk $observation}catch{$bad=$true};Assert $bad 'Live scoring IPC rejects old response'
function Ask-LiveScore($raw){return @{action='markDiscard';verified=$true;raw=$raw.Clone();observation=$raw}}
function Mark-LiveRelic($raw){$script:state.marked++;$script:applied++}
$script:records=New-Object 'Collections.Generic.List[object]';$script:state=@{scanned=1;matched=0;marked=0;unrecognized=0;skipped=0};$script:applied=0;$PreviewOnly=$true
Process-LiveRecord $template;Assert ($script:applied-eq 0-and$script:state.matched-eq 1) 'Preview cannot apply a discard decision'
$PreviewOnly=$false;Process-LiveRecord $template;Assert ($script:applied-eq 1-and$script:state.marked-eq 1) 'Active mode applies exactly one verified discard'
Write-Output ('Actual live worker function checks passed: '+$script:checks+'; native input is an in-memory double, real game input: 0')
