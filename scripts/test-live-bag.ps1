# Large bag and repeated-upgrade simulations. Every input/capture method is a local model.
param([string]$Node='node',[ValidateRange(20,3000)][int]$BagCount=3000)
if($BagCount%20-ne 0){throw 'BagCount must be a multiple of 20'}
$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$utf8=New-Object Text.UTF8Encoding($false)
Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;using System.Drawing;using System.Collections.Generic;
public static class RelicNative {
 public static string[] Keys;public static int Index,Frame,Marks,Unlocks,Navs;public static bool NoNavigation,AnimateOutside=true;
 public static Dictionary<string,bool> Locks=new Dictionary<string,bool>(),Discarded=new Dictionary<string,bool>();
 public static Dictionary<string,int> Rarity=new Dictionary<string,int>(),MarkClicks=new Dictionary<string,int>(),Visits=new Dictionary<string,int>();
 static string Key{get{return Keys[Index];}}
 public static Bitmap Capture(object w){if(!Visits.ContainsKey(Key))Visits[Key]=0;Visits[Key]++;var b=new Bitmap(8,8);using(var g=Graphics.FromImage(b))g.Clear(Color.Gray);b.SetPixel(0,0,Color.FromArgb((Index>>16)&255,(Index>>8)&255,Index&255));b.SetPixel(1,0,Discarded[Key]?Color.Red:Color.Gray);b.SetPixel(2,0,Locks[Key]?Color.White:Color.Black);b.SetPixel(7,7,Color.FromArgb(AnimateOutside?(++Frame%255):0,0,0));return b;}
 public static Bitmap Crop(Bitmap b,int x,int y,int width,int height){var c=(Bitmap)b.Clone();if(x==70)c.SetPixel(7,7,Color.Black);if(x==1798){using(var g=Graphics.FromImage(c))g.Clear(Discarded[Key]?Color.Red:Color.Gray);}return c;}
 public static string ImageHash(Bitmap b){return b.GetPixel(0,0).ToArgb()+":"+b.GetPixel(1,0).ToArgb()+":"+b.GetPixel(2,0).ToArgb()+":"+b.GetPixel(7,7).ToArgb();}
 public static double Difference(Bitmap a,Bitmap b){return ImageHash(a)==ImageHash(b)?0:1;}
 public static bool FiveStarPanel(Bitmap b){return Rarity[Key]==5;}
 public static int RedPixels(Bitmap b){return b.GetPixel(0,0).R>200?100:0;}
 public static void ClickDiscard(object w,int x,int y){Marks++;if(!MarkClicks.ContainsKey(Key))MarkClicks[Key]=0;MarkClicks[Key]++;Discarded[Key]=!Discarded[Key];}
 public static void ClickVerifiedControl(object w,int x,int y){Unlocks++;Locks[Key]=!Locks[Key];}
 public static void HoverControl(object w,int x,int y){}
 public static void TapNavigation(object w,string key){Navs++;if(NoNavigation)return;int row=Index/9,start=row*9,end=Math.Min(Keys.Length-1,start+8);if(key=="D")Index=Math.Min(end,Index+1);else if(key=="A")Index=Math.Max(start,Index-1);else if(key=="S"&&start+9<Keys.Length)Index=Math.Min(Keys.Length-1,Index+9);else throw new Exception("Invalid model navigation");}
 public static void ScrollToTop(object w,int x,int y){Index=0;}
 public static void ClickGrid(object w,int x,int y){Index=0;}
}
'@
. (Join-Path $root 'marker-core.ps1');. (Join-Path $root 'live-core.ps1');. (Join-Path $root 'live-server.ps1');. (Join-Path $root 'layout-1080.ps1')
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'live.ps1'),[ref]$tokens,[ref]$errors);if($errors.Count){throw $errors[0].Message}
foreach($f in $ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$true)){Invoke-Expression $f.Extent.Text}
$realSave=${function:Save-State};$checks=0
function Assert($v,$name){if(-not$v){throw $name};$script:checks++}
function Json($v){ConvertTo-Json -InputObject $v -Depth 40 -Compress}
function Clone($v){ConvertFrom-Json (Json $v)}
function Start-Sleep {}
function Check-Stop {if($script:stopAt-gt 0-and$state.scanned-ge$script:stopAt){throw(New-Object OperationCanceledException('Model cancellation'))}}
function Check-Inventory {Check-Stop;return $true}
function Read-Region($b,$r,$name){if($name-eq'count'){return ,@(@{text=('遗器数量 '+$script:bag.Count+'/3000')})};return ,@()}
function Read-Selected($b,$index){$r=Clone $script:bag[[RelicNative]::Index];$r._uid='live-'+$index;$key=$r.testKey;$r.lock=[RelicNative]::Locks[$key];$r.discard=[RelicNative]::Discarded[$key];return $r}
function Save-State($name,$message){
 & $realSave $name $message
 if($name-eq'awaitingScore'){
  $line=[IO.File]::ReadAllText((Join-Path $JobDirectory 'request.json'),$utf8);$scoreWriter.WriteLine($line);$scoreWriter.Flush()
  $task=$scoreProcess.StandardOutput.ReadLineAsync();if(-not$task.Wait(30000)-or-not$task.Result){throw 'Persistent offline scorer timed out or exited'}
  $answer=ConvertFrom-Json $task.Result;Accept-LiveDecision $answer|Out-Null;$script:requests++
 }
 if($name-eq'running'-and$state.scanned-gt 0-and$state.scanned%250-eq 0-and$script:lastPrinted-ne$state.scanned){$script:lastPrinted=$state.scanned;Write-Host ('Simulation '+$script:case+': '+$state.scanned+'/'+$state.inventoryCount+', verified marks '+$state.marked)}
}
function Prepare-Enhancement($candidate,$observation,$target,$active){Assert ($target-eq[Math]::Min(15,([Math]::Floor($observation.enhance/3)+1)*3)) 'Each enhancement requests only the next node'}
function Confirm-Enhancement($observation,$target){
 $key=[RelicNative]::Keys[[RelicNative]::Index];$script:steps[$key]++;$step=$script:steps[$key];$recipe=$script:recipes[$key]
 if(-not$recipe-or$step-ge$recipe.Count){throw 'A terminal relic was enhanced again'}
 $next=Clone $recipe[$step];$next|Add-Member -NotePropertyName testKey -NotePropertyValue $key;$script:bag[[RelicNative]::Index]=$next;$state.submittedSteps++
 # Simulate consumed low-rarity relics and level sorting after EVERY stage.
 $material=@($script:bag|Where-Object{$_.rarity-lt 5}|Select-Object -First 1);if($material.Count){$consume=$material[0].testKey;$script:bag=@($script:bag|Where-Object{$_.testKey-ne$consume})}
 $script:bag=@($script:bag|Sort-Object @{Expression={$_.rarity};Descending=$true},@{Expression={$_.level};Descending=$true},testKey)
 [RelicNative]::Keys=[string[]]@($script:bag|ForEach-Object{$_.testKey});[RelicNative]::Index=[Array]::IndexOf([RelicNative]::Keys,$key)
}
function Reset-Case($name,$items,[bool]$upgrade=$false){
 $script:case=$name;$script:bag=@($items);$script:requests=0;$script:lastPrinted=-1;$script:stopAt=0
 $script:JobDirectory=Join-Path $root ('work/bag-'+$name+'-'+[Guid]::NewGuid().ToString('N'));[IO.Directory]::CreateDirectory($JobDirectory)|Out-Null;$script:statusPath=Join-Path $JobDirectory 'status.json'
 $script:state=@{kind='live';scanned=0;inventoryCount=$bag.Count;marked=0;unlocked=0;attempted=0;equippedLow=0;skipped=0;matched=0;unrecognized=0;confirmedSteps=0;submittedSteps=0;kept=0;passes=1;totalInspected=0}
 $script:plan=@{characters=@();allowUnlockLowPotential=$true;upgrade=$upgrade;maxMarks=0};$script:markerJob=@{kind='live';directory=$JobDirectory;allowUnlockLowPotential=$true;upgrade=$upgrade};$script:PreviewOnly=$false;$script:window=$null;$script:layout=Get-RelicLayout1080 1920 1080
 [RelicNative]::Keys=[string[]]@($bag|ForEach-Object{$_.testKey});[RelicNative]::Index=0;[RelicNative]::Marks=0;[RelicNative]::Unlocks=0;[RelicNative]::Navs=0;[RelicNative]::NoNavigation=$false
 [RelicNative]::Locks.Clear();[RelicNative]::Discarded.Clear();[RelicNative]::Rarity.Clear();[RelicNative]::Visits.Clear();[RelicNative]::MarkClicks.Clear()
 foreach($r in $bag){[RelicNative]::Locks[$r.testKey]=($r.lock-eq$true);[RelicNative]::Discarded[$r.testKey]=($r.discard-eq$true);[RelicNative]::Rarity[$r.testKey]=$r.rarity}
}
function Item($raw,$key){$r=Clone $raw;$r|Add-Member -NotePropertyName testKey -NotePropertyValue $key;return $r}
function Run-Case {try{Invoke-LiveTraversal;return $false}catch{Save-LiveFailure $_|Out-Null;Write-Host ('Model stopped: '+$_.Exception.Message);return $true}}
& $Node (Join-Path $root 'scripts/live-fixture-bridge.cjs') --generate;if($LASTEXITCODE-ne 0){throw 'Fixture creation failed'}
$fixture=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $root 'work/live-pipeline-fixtures.json'),$utf8))
$psi=New-Object Diagnostics.ProcessStartInfo;$psi.FileName=$Node;$psi.Arguments='"'+(Join-Path $root 'scripts/live-stress-bridge.cjs')+'"';$psi.UseShellExecute=$false;$psi.CreateNoWindow=$true;$psi.WindowStyle=[Diagnostics.ProcessWindowStyle]::Hidden;$psi.RedirectStandardInput=$true;$psi.RedirectStandardOutput=$true;$psi.StandardOutputEncoding=$utf8
$scoreProcess=New-Object Diagnostics.Process;$scoreProcess.StartInfo=$psi
try{
 $scoreProcess.Start()|Out-Null;$scoreWriter=New-Object IO.StreamWriter($scoreProcess.StandardInput.BaseStream,$utf8);$scoreWriter.AutoFlush=$true
 $items=New-Object 'Collections.Generic.List[object]'
 for($i=0;$i-lt$BagCount;$i++){$r=Item $fixture.junk ('bag-'+$i);switch($i%20){
  {$_-ge 7-and$_-le 12}{$r.lock=$true}
  13{$r=Item $fixture.high[-1] ('bag-'+$i)}
  14{$r.level=15;$r.mainstat_value=705;$r.location='equipped';$r.lock=$true}
  15{$r.discard=$true}
  16{$r.rarity=4}
  17{$r.mainstat_value=1}
  18{$r=Item $fixture.high[-2] ('bag-'+$i)}
  19{$r=Item $fixture.high[0] ('bag-'+$i)}
 };$items.Add($r)}
 Reset-Case ('mixed-duplicates-'+$BagCount) $items.ToArray()
 Assert (-not(Run-Case)) 'The full 3000-relic simulation traverses successfully'
 Assert ($state.state-eq'partial'-and$state.scanned-eq$BagCount-and[RelicNative]::Visits.Count-eq$BagCount) 'Every physical slot is visited, including the three-cell final row'
 Assert ($state.marked-eq($BagCount/20*13)-and$state.unlocked-eq($BagCount/20*6)-and[RelicNative]::Marks-eq($BagCount/20*13)-and[RelicNative]::Unlocks-eq($BagCount/20*6)) 'All and only eligible low items are unlocked/marked'
 Assert ($state.equippedLow-eq($BagCount/20)-and$state.unrecognized-eq($BagCount/20)-and$state.confirmedSteps-eq 0) 'Equipped and unrecognized relics stay protected; cleanup does not spend materials'
 Assert (@([RelicNative]::MarkClicks.Values|Where-Object{$_-gt 1}).Count-eq 0) 'No identical-looking relic is toggled twice'
 $snapshot=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $JobDirectory 'snapshot.json'),$utf8));Assert ($snapshot.relics.Count-eq$BagCount-and$snapshot.metadata.partial) 'Full mixed inventory preserves all entries and reports recognition gaps'
 Write-Host ([string]$BagCount+'-relic simulation passed; scoring requests='+$requests)
 $items=New-Object 'Collections.Generic.List[object]';$script:recipes=@{};$script:steps=@{}
 for($i=0;$i-lt 3;$i++){foreach($kind in @('high','low')){$key=$kind+'-'+$i;$recipe=$fixture.$kind;$r=Item $recipe[0] $key;$r.lock=$true;$items.Add($r);$recipes[$key]=$recipe;$steps[$key]=0}}
 $locked=Item $fixture.junk 'locked-static';$locked.lock=$true;$items.Add($locked);$items.Add((Item $fixture.junk 'low-static'))
 $equipped=Item $fixture.junk 'equipped-static';$equipped.location='equipped';$items.Add($equipped)
 for($i=0;$i-lt 10;$i++){$r=Item $fixture.junk ('material-'+$i);$r.rarity=4;$items.Add($r)}
 Reset-Case 'two-phase-initial-cleanup' $items.ToArray()
 Assert (-not(Run-Case)) 'The first one-click cleanup finishes before enhancement'
 Assert ($state.marked-eq 2-and$state.unlocked-eq 1-and$state.confirmedSteps-eq 0) 'Initial cleanup only unlocks and marks static low items without spending'
 Assert (@($recipes.Keys|Where-Object{-not[RelicNative]::Locks[$_]}).Count-eq 0) 'High-potential locked embryos remain locked during cleanup'
 # Carry the SAME inventory and verified game flags into the second button/run.
 foreach($r in $script:bag){$key=$r.testKey;$r.lock=[RelicNative]::Locks[$key];$r.discard=[RelicNative]::Discarded[$key]}
 Reset-Case 'consecutive-upgrades-and-resorts' $script:bag $true
 Assert (-not(Run-Case)) 'Multiple identical high and deteriorating relics complete staged upgrades'
 Assert ($state.confirmedSteps-eq 21-and$state.submittedSteps-eq 21-and$state.kept-eq 3) 'Three high relics each reach +15; three low paths stop after +6'
 Assert ($state.marked-eq 3-and$state.unlocked-eq 6-and[RelicNative]::Marks-eq 3) 'Enhancement unlocks all six embryos and marks only the three deteriorating paths'
 Assert ([RelicNative]::Discarded['locked-static']-and[RelicNative]::Discarded['low-static']-and-not[RelicNative]::MarkClicks.ContainsKey('locked-static')-and-not[RelicNative]::MarkClicks.ContainsKey('low-static')) 'The second button preserves discard flags from the first run without toggling them'
 Assert ($state.inventoryCount-eq 9-and$state.passes-eq 7-and$state.state-eq'complete') 'Consumed materials and per-stage sorting cannot skip remaining items'
 Assert (@([RelicNative]::MarkClicks.Values|Where-Object{$_-gt 1}).Count-eq 0) 'Repeated scans never unmark a previous discard'
 foreach($key in $recipes.Keys){Assert ($steps[$key]-eq$(if($key-like'high-*'){5}else{2})) 'No extra enhancement after the terminal decision'}
 foreach($raw in @($fixture.junk,$fixture.high[-1])){
  Reset-Case 'no-navigation-with-animated-panel' @((Item $raw 'stuck-a'),(Item $raw 'stuck-b'));[RelicNative]::NoNavigation=$true
  Assert (Run-Case) 'Unrelated frame animation cannot disguise a stationary grid'
  Assert ($state.state-eq'failed'-and-not[RelicNative]::Discarded['stuck-b']) 'A stationary selection never produces a complete inventory'
 }
 Reset-Case 'stop-mid-bag' @((0..29|ForEach-Object{Item $fixture.junk ('stop-'+$_)}));$script:stopAt=13
 Assert (Run-Case) 'Mid-bag cancellation is honored'
 Assert ($state.state-eq'stopped'-and$state.marked-eq 12) 'Cancellation causes no action on the thirteenth item'
 Write-Output ('Large bag/consecutive-upgrade checks passed: '+$checks+'; static game model, real scoring/API/file IPC; actual game input: 0.')
}finally{if($scoreProcess-and-not$scoreProcess.HasExited){if($scoreWriter){$scoreWriter.Close()}else{$scoreProcess.StandardInput.Close()};if(-not$scoreProcess.WaitForExit(3000)){$scoreProcess.Kill()}};$scoreProcess.Dispose()}
