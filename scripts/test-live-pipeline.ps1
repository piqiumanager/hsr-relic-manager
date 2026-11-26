# Production Process -> file IPC -> JS scoring -> API validation -> marking/upgrade -> snapshot.
# Only screen/input and enhancement materials are simulated. This script never loads user32.dll.
param([string]$Node='node')
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$utf8=New-Object Text.UTF8Encoding($false)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;using System.Drawing;using System.Collections.Generic;
public static class RelicNative {
 public static bool Traversal,AcceptUnlock=true,AcceptMark=true;public static int Unlocks,Marks,Index;
 static bool locked,marked;public static string[] Keys;
 public static Dictionary<string,bool> LockMap=new Dictionary<string,bool>(),MarkMap=new Dictionary<string,bool>();
 public static Dictionary<string,int> Rarities=new Dictionary<string,int>();
 public static bool Locked{get{return Traversal?LockMap[Keys[Index]]:locked;}set{if(Traversal)LockMap[Keys[Index]]=value;else locked=value;}}
 public static bool Marked{get{return Traversal?MarkMap[Keys[Index]]:marked;}set{if(Traversal)MarkMap[Keys[Index]]=value;else marked=value;}}
 public static Bitmap Capture(object w){var b=new Bitmap(40,40);using(var g=Graphics.FromImage(b))g.Clear(Marked?Color.Red:Color.FromArgb(128+(Traversal?Index:0),128,128));return b;}
 public static Bitmap Crop(Bitmap b,int x,int y,int width,int height){return (Bitmap)b.Clone();}
 public static void ClickVerifiedControl(object w,int x,int y){Unlocks++;if(AcceptUnlock)Locked=false;}
 public static void ClickDiscard(object w,int x,int y){Marks++;if(AcceptMark)Marked=true;}
 public static void HoverControl(object w,int x,int y){}
 public static int RedPixels(Bitmap b){return b.GetPixel(0,0).R>200?100:0;}
 public static bool FiveStarPanel(Bitmap b){return !Traversal||Rarities[Keys[Index]]==5;}
 public static string ImageHash(Bitmap b){return b.GetPixel(0,0).ToArgb().ToString();}
 public static double Difference(Bitmap a,Bitmap b){return a.GetPixel(0,0)==b.GetPixel(0,0)?0:1;}
 public static void TapNavigation(object w,string key){if(key=="D")Index++;else if(key=="A")Index--;else if(key=="S")Index+=9;}
 public static void ScrollToTop(object w,int x,int y){Index=0;}
 public static void ClickGrid(object w,int x,int y){Index=0;}
}
'@
. (Join-Path $root 'marker-core.ps1');. (Join-Path $root 'live-core.ps1');. (Join-Path $root 'live-server.ps1');. (Join-Path $root 'layout-1080.ps1')
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'live.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw $errors[0].Message}
foreach($f in $ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$true)){Invoke-Expression $f.Extent.Text}
$realSaveState=${function:Save-State};$checks=0
function Assert($v,$name){if(-not$v){throw $name};$script:checks++}
function Json($o){ConvertTo-Json -InputObject $o -Depth 40 -Compress}
function Clone($o){ConvertFrom-Json (Json $o)}
function Save-State($name,$message){
    & $realSaveState $name $message
    if($name-eq'awaitingScore'){
      $out=Join-Path $JobDirectory 'scored.json'
      & $Node (Join-Path $root 'scripts/live-fixture-bridge.cjs') (Join-Path $JobDirectory 'request.json') $out
      if($LASTEXITCODE-ne 0){throw 'Offline JS scorer failed'}
      $answer=ConvertFrom-Json ([IO.File]::ReadAllText($out,$utf8))
      if($script:case-eq'stale'){$answer.requestId='outdated'}
      Accept-LiveDecision $answer|Out-Null
      $script:scoreRequests++
    }
}
function Check-Stop {if($script:case-eq'stop-score-ready'-and$script:scoreRequests-gt 0){throw(New-Object OperationCanceledException('Stopped while score response was arriving'))};if($script:case-eq'stop-after-upgrade'-and$script:confirmations-ge 1){throw(New-Object OperationCanceledException('Synthetic stop'))}}
function Check-Inventory {Check-Stop;return $script:case-ne'left-inventory'}
function Read-Selected($b,$index){
    if([RelicNative]::Traversal){$script:physical=$script:bag[[RelicNative]::Index]}
    $script:reads++;$r=Clone $script:physical;$r._uid='live-'+$index;$r.lock=[RelicNative]::Locked;$r.discard=[RelicNative]::Marked
    if($script:case-eq'changed-after-mark'-and[RelicNative]::Marks-gt 0){$r.mainstat_value=112}
    if($script:case-eq'corrupt-upgrade'-and$script:confirmations-gt 0){$r.set_id='118'}
    return $r
}
function Prepare-Enhancement($candidate,$observation,$target,$active){
    if($script:case-eq'bad-materials'){throw 'Unverified material selection'}
    $script:targets+=,$target
}
function Confirm-Enhancement($observation,$target){
    $script:confirmations++;$script:state.submittedSteps++
    $script:physical=Clone $script:sequence[$script:confirmations]
    if([RelicNative]::Traversal){
      $key=[RelicNative]::Keys[[RelicNative]::Index];$script:physical|Add-Member -NotePropertyName testKey -NotePropertyValue $key -Force
      $script:bag[[RelicNative]::Index]=$script:physical
      $script:bag=@($script:bag|Where-Object{$_.rarity-eq 5}|Sort-Object level -Descending)
      [RelicNative]::Keys=[string[]]@($script:bag|ForEach-Object{$_.testKey})
      [RelicNative]::Index=[Array]::IndexOf([RelicNative]::Keys,$key)
    }
}
$bridge=Join-Path $root 'scripts/live-fixture-bridge.cjs'
& $Node $bridge --generate;if($LASTEXITCODE-ne 0){throw 'Fixture generation failed'}
$fixture=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $root 'work/live-pipeline-fixtures.json'),$utf8))
function Reset-Case($name,$raw,[bool]$enhance=$false){
    [RelicNative]::Traversal=$false
    $script:case=$name;$script:physical=Clone $raw;$script:physical._uid='live-1';$script:reads=0;$script:confirmations=0;$script:targets=@();$script:scoreRequests=0
    [RelicNative]::Locked=($raw.lock-eq$true);[RelicNative]::Marked=($raw.discard-eq$true);[RelicNative]::Unlocks=0;[RelicNative]::Marks=0;[RelicNative]::AcceptUnlock=$true;[RelicNative]::AcceptMark=$true
    $script:JobDirectory=Join-Path $root ('work/pipeline-'+$name+'-'+[Guid]::NewGuid().ToString('N'));[IO.Directory]::CreateDirectory($JobDirectory)|Out-Null
    $script:statusPath=Join-Path $JobDirectory 'status.json';$script:records=New-Object 'Collections.Generic.List[object]'
    $script:plan=@{characters=@();allowUnlockLowPotential=$true;upgrade=$enhance};$script:PreviewOnly=$false
    $script:state=@{kind='live';scanned=1;inventoryCount=1;marked=0;unlocked=0;attempted=0;equippedLow=0;skipped=0;matched=0;unrecognized=0;confirmedSteps=0;submittedSteps=0;kept=0;passes=1;totalInspected=0}
    $script:markerJob=@{kind='live';directory=$JobDirectory;allowUnlockLowPotential=$true;upgrade=$enhance}
    $script:window=$null;$script:layout=@{panel=@{x=0;y=0;width=40;height=40};unlockRect=@{x=0;y=0;width=40;height=40};discardRect=@{x=0;y=0;width=40;height=40};discardPoint=@(2,2)}
}
function Run-Case {try{Process-LiveRecord $script:physical;Save-Snapshot;Save-State 'complete' 'Offline case complete';return $false}catch{$script:lastError=$_;Save-LiveFailure $_|Out-Null;return $true}}
$locked=Clone $fixture.junk;$locked.lock=$true
Reset-Case 'locked-low' $locked
Assert (-not(Run-Case)) 'Low locked pipeline completes'
Assert ($state.marked-eq 1-and$state.unlocked-eq 1-and[RelicNative]::Unlocks-eq 1-and[RelicNative]::Marks-eq 1) 'Exactly one verified unlock then one discard'
$snapshot=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $JobDirectory 'snapshot.json'),$utf8))
Assert ($snapshot.relics.Count-eq 1-and$snapshot.relics[0].lock-eq$false-and$snapshot.relics[0].discard-eq$true) 'Real Generic.List snapshot contains final flags'
Assert ($scoreRequests-eq 4) 'Score, preflight, unlocked and marked each use real IPC/scoring'
Assert ((Get-ChildItem -LiteralPath $JobDirectory -Filter 'evidence-*.png').Count-eq 9) 'Before/unlocked/marked evidence is saved'
$maxed=Clone $fixture.junk;$maxed.level=15;$maxed.mainstat_value=705
Reset-Case 'maxed-low' $maxed
Assert (-not(Run-Case)-and$state.marked-eq 1-and[RelicNative]::Marks-eq 1) 'Unequipped low +15 is really passed through marking'
$equipped=Clone $maxed;$equipped.location='equipped';$equipped.lock=$true
Reset-Case 'equipped-low' $equipped
Assert (-not(Run-Case)-and$state.marked-eq 0-and$state.equippedLow-eq 1-and[RelicNative]::Unlocks-eq 0-and[RelicNative]::Marks-eq 0) 'Equipped low +15 warning with zero input'
Assert (([IO.File]::ReadAllText((Join-Path $JobDirectory 'actions.jsonl')))-match'equipped-low-protected') 'Equipped warning logged'
foreach($name in @('unlock-not-applied','mark-not-applied','changed-after-mark','stale','left-inventory')){
    Reset-Case $name $locked
    if($name-eq'unlock-not-applied'){[RelicNative]::AcceptUnlock=$false}
    if($name-eq'mark-not-applied'){[RelicNative]::AcceptMark=$false}
    Assert (Run-Case) ('Failure detected: '+$name)
    $status=ConvertFrom-Json ([IO.File]::ReadAllText($statusPath,$utf8))
    Assert ($status.state-eq'failed'-and$state.marked-eq 0-and[RelicNative]::Marks-le 1-and[RelicNative]::Unlocks-le 1) ('Failure never increments success or retries: '+$name)
}
Reset-Case 'stop-score-ready' $locked
Assert (Run-Case) 'Cancellation during an immediately delivered score is detected'
$status=ConvertFrom-Json ([IO.File]::ReadAllText($statusPath,$utf8));Assert ($status.state-eq'stopped'-and[RelicNative]::Marks-eq 0-and[RelicNative]::Unlocks-eq 0) 'A ready score cannot bypass cancellation'
$cancelled=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $JobDirectory 'snapshot.json'),$utf8));Assert $cancelled.metadata.partial 'Cancellation before saving the final record cannot create a complete snapshot'
Reset-Case 'preview' $locked $true;$script:PreviewOnly=$true
Assert (-not(Run-Case)-and$state.marked-eq 0-and[RelicNative]::Unlocks-eq 0-and[RelicNative]::Marks-eq 0-and$confirmations-eq 0) 'Preview cannot mark, unlock or spend'
Reset-Case 'high-to-15' $fixture.high[0] $true;$script:sequence=$fixture.high
Assert (-not(Run-Case)) ('High pipeline completes: '+$lastError)
Assert (($targets-join',')-eq'3,6,9,12,15'-and$state.confirmedSteps-eq 5-and$state.kept-eq 1-and[RelicNative]::Marks-eq 0) 'Real per-step scorer reaches +15 only after five verified upgrades'
$saved=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $JobDirectory 'snapshot.json'),$utf8));Assert ($saved.relics[0].level-eq 15-and$saved.relics[0].discard-eq$false) 'Final high +15 persisted'
Reset-Case 'becomes-low' $fixture.low[0] $true;$script:sequence=$fixture.low
Assert (-not(Run-Case)-and($targets-join',')-eq'3,6'-and$state.confirmedSteps-eq 2-and$state.marked-eq 1-and[RelicNative]::Marks-eq 1) 'Actual scoring turns a +6 into discard and stops all further upgrades'
foreach($name in @('bad-materials','corrupt-upgrade','stop-after-upgrade')){
    Reset-Case $name $fixture.high[0] $true;$script:sequence=$fixture.high
    Assert (Run-Case) ('Enhancement failure detected: '+$name)
    Assert ($confirmations-le 1-and[RelicNative]::Marks-eq 0-and$state.confirmedSteps-eq 0) ('No repeated spend or unsafe discard: '+$name)
}
Reset-Case 'snapshot-failure' $fixture.junk;$script:records.Add($fixture.junk)
[IO.Directory]::CreateDirectory((Join-Path $JobDirectory 'snapshot.json'))|Out-Null
try{throw 'Original marking error'}catch{Save-LiveFailure $_|Out-Null}
$status=ConvertFrom-Json ([IO.File]::ReadAllText($statusPath,$utf8))
Assert ($status.state-eq'failed'-and$status.message-match'Original marking error') 'Snapshot save failure cannot hide the original error or leave awaitingScore'
Reset-Case 'reordered-bag' $fixture.high[0] $true;$script:sequence=$fixture.high
$lower=Clone $fixture.junk;$lower.rarity=4
$script:bag=@((Clone $locked),(Clone $fixture.high[0]),(Clone $equipped),$lower)
for($i=0;$i-lt$bag.Count;$i++){$key='physical-'+$i;$bag[$i]|Add-Member -NotePropertyName testKey -NotePropertyValue $key;[RelicNative]::LockMap[$key]=($bag[$i].lock-eq$true);[RelicNative]::MarkMap[$key]=$false;[RelicNative]::Rarities[$key]=$bag[$i].rarity}
[RelicNative]::Keys=[string[]]@($bag|ForEach-Object{$_.testKey});[RelicNative]::Traversal=$true;[RelicNative]::Index=0
$script:state.scanned=0;$script:state.inventoryCount=$bag.Count;$script:layout.first=@(2,2)
function Read-Region($bitmap,$rect,$name){if($name-eq'count'){return ,@(@{text=('遗器数量 '+$script:bag.Count+'/3000')})};return ,@()}
Invoke-LiveTraversal
$saved=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $JobDirectory 'snapshot.json'),$utf8))
Assert ($state.state-eq'complete'-and$state.passes-eq 2-and$state.inventoryCount-eq 3-and$saved.relics.Count-eq 3) 'Full traversal restarts after sorting and recounts consumed materials'
Assert ($state.marked-eq 1-and$state.unlocked-eq 1-and[RelicNative]::Marks-eq 1-and$state.confirmedSteps-eq 5) 'Already marked items are not toggled on the second pass; upgrade is never repeated'
Assert (@($saved.relics|Where-Object{$_.level-eq 15-and$_.location-eq''-and$_.discard-eq$false}).Count-eq 1-and$state.equippedLow-eq 1) 'Final inventory contains the high +15 and the protected equipped warning'
Assert ($saved.metadata.partial-eq$false-and$state.totalInspected-eq 5) 'Completion requires a whole stable pass after mutation'
[RelicNative]::Traversal=$false
Reset-Case 'empty-bag' $fixture.junk;$state.scanned=0;$state.inventoryCount=0;Invoke-LiveTraversal
$empty=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $JobDirectory 'snapshot.json'),$utf8));Assert ($state.state-eq'complete'-and$empty.relics.Count-eq 0-and[RelicNative]::Marks-eq 0) 'An empty inventory serializes a complete empty snapshot with no input'
Write-Output ('Offline live pipeline passed: '+$checks+' checks; production JS scoring, API/file IPC, worker orchestration and snapshots; simulated input only, actual game input: 0.')
