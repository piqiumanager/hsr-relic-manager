$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'marker-core.ps1');. (Join-Path $root 'upgrade-core.ps1')
$script:checks=0;function Assert($v,[string]$name){if(-not$v){throw $name};$script:checks++}
$region=@{x=1300;y=450;width=590;height=250}
$line=@{text='4星及以下 自动置入';x=1370;y=600;width=430;height=30;words=@(@{text='4星及以下';x=1370;y=600;width=140;height=30},@{text='自动';x=1630;y=600;width=50;height=30},@{text='置入';x=1680;y=600;width=50;height=30})}
$c=Find-UpgradeControl @($line) @('自动置入') $region;Assert ($c.cx-eq 1680) 'Simplified Chinese word-box control location'
Assert (Test-UpgradeMaterialCaption @(@{text='4星及以下'})) 'Four-star caption recognized'
Assert (-not(Test-UpgradeMaterialCaption @(@{text='5星及以下'}))) 'Five-star caption rejected'
Assert (Get-UpgradeProjection @(@{text='+0 → +3'}) 0 3) 'Exact +3 projected'
$bad=$false;try{Get-UpgradeProjection @(@{text='+0 → +15'}) 0 3}catch{$bad=$true};Assert $bad 'Full-level autofill rejected'
$bad=$false;try{Get-UpgradeProjection @(@{text='+3'}) 0 3}catch{$bad=$true};Assert $bad 'Unverified current level rejected'
$candidate=@{setId='117';part='Head';pieceName='先驱的绝热围壳';setName='死水深潜的先驱';main=@{stat='HP';value=112}}
$panel=@(@{text='先驱的绝热围壳';y=100},@{text='死水深潜的先驱';y=700},@{text='+3';y=300},@{text='生命值 214';y=400})
$subs=@(@{text='暴击率3.2%';y=450},@{text='暴击伤害6.4%';y=480},@{text='攻击力4.3%';y=510},@{text='防御力16';y=540})
$o=ConvertTo-UpgradeObservation $candidate $panel $subs 3 430;Assert ($o.enhance-eq 3-and$o.substats.Count-eq 4) 'New attributes parsed'
$bad=$false;try{ConvertTo-UpgradeObservation $candidate $panel $subs 6 430}catch{$bad=$true};Assert $bad 'Unexpected actual level rejected'
$request=@{requestId='test';initial=$false;observation=@{enhance=3}}
Assert (Assert-UpgradeDecision $request @{requestId='test';action='enhance';targetLevel=6;lower=80;upper=81}) '80-point continue accepted'
$bad=$false;try{Assert-UpgradeDecision $request @{requestId='test';action='markDiscard';lower=79;upper=80.01}}catch{$bad=$true};Assert $bad 'Potentially high score not discarded'
$bad=$false;try{Assert-UpgradeDecision $request @{requestId='old';action='enhance';targetLevel=6;lower=90;upper=90}}catch{$bad=$true};Assert $bad 'Stale response rejected'
Add-Type -AssemblyName System.Drawing;Add-Type -AssemblyName System.Windows.Forms
Add-Type -Path (Join-Path $root 'marker-native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
$b=New-Object Drawing.Bitmap(560,300);$g=[Drawing.Graphics]::FromImage($b);$g.Clear([Drawing.Color]::FromArgb(30,40,55));$pen=New-Object Drawing.Pen([Drawing.Color]::White,3)
foreach($y in @(80,220)){foreach($x in @(70,210,350,490)){$g.DrawLine($pen,$x-12,$y,$x+12,$y);$g.DrawLine($pen,$x,$y-12,$x,$y+12)}};$g.Dispose();$pen.Dispose()
Assert ([RelicNative]::CountEmptyMaterialSlots($b)-eq 8) 'Eight empty material slots recognized'
$g=[Drawing.Graphics]::FromImage($b);$g.FillRectangle([Drawing.Brushes]::Black,50,60,40,40);$g.Dispose();Assert ([RelicNative]::CountEmptyMaterialSlots($b)-ne 8) 'Preselected material blocks autofill';$b.Dispose()
# Load executor function bodies, not its startup block. All game actions below use test doubles.
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'upgrade.ps1'),[ref]$t,[ref]$e);Assert ($e.Count-eq 0) 'Executor syntax'
foreach($f in $ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$true)){Invoke-Expression $f.Extent.Text}
$realConfirm=${function:Confirm-Enhancement};$realPrepare=${function:Prepare-Enhancement}
$script:clicks=@();$script:projection='+0 → +15';$script:material='4星及以下';$levelRow=@{};$materialHeader=@{}
function Assert-EnhancementScreen {}
function Assert-OldStats($v){}
function Check-Stop {}
function Click-Text($Texts,$Region,$Name){$script:clicks+=,$Name}
function Read-Frame($Rect,$Name){if($Name-like'level-preview*'){return ,@(@{text=$script:projection})};if($Name-like'material-caption*'){return ,@(@{text=$script:material})};return ,@()}
$bad=$false;try{& $realConfirm @{enhance=0} 3}catch{$bad=$true};Assert ($bad-and$script:clicks.Count-eq 0) 'Real confirmation blocks +15 projection before any click'
$script:projection='+0 → +3';$script:material='5星及以下'
$bad=$false;try{& $realConfirm @{enhance=0} 3}catch{$bad=$true};Assert ($bad-and$script:clicks.Count-eq 0) 'Real confirmation blocks five-star material caption before any click'
function Count-EmptySlots {return 7}
$bad=$false;try{& $realPrepare $candidate @{enhance=0} 3 @()}catch{$bad=$true};Assert ($bad-and($script:clicks-join',')-eq'open-enhance') 'Real preparation refuses existing materials before autofill'
$script:level=0;$script:targets=@();$script:marks=0;$script:state=@{processed=0;kept=0;marked=0;confirmedSteps=0};$PreviewOnly=$false;$JobDirectory=Join-Path $root 'work/test-upgrade';[IO.Directory]::CreateDirectory($JobDirectory)|Out-Null;$utf8=New-Object Text.UTF8Encoding($false)
function Check-Stop {}
function Save-State($Name,$Message){}
function Read-Observation($c,$l){return @{enhance=$script:level;substats=@(@{stat='SPD';value=2.6})}}
function Ask-Score($c,$id,$o,$initial){if($o.enhance-eq 15){return @{action='keep';lower=90;upper=90}};return @{action='enhance';targetLevel=$o.enhance+3;lower=90;upper=90}}
function Prepare-Enhancement($c,$o,$target,$active){$script:targets+=,$target}
function Confirm-Enhancement($o,$target){$script:level=$target;$script:state.confirmedSteps++}
function Mark-CurrentDiscard($c,$o){$script:marks++}
$candidate.enhance=0;$candidate.substats=@(@{stat='SPD';value=2.6})
$outcome=Process-Relic $candidate 'test';Assert ($outcome-eq'keep') 'Executor completes actual orchestration'
Assert (($script:targets-join',')-eq'3,6,9,12,15') 'Executor requests each stage exactly once'
Assert ($script:state.confirmedSteps-eq 5-and$script:marks-eq 0) 'Five steps with no discard'
$script:level=0;$script:targets=@();$script:state=@{processed=0;kept=0;marked=0;confirmedSteps=0}
function Ask-Score($c,$id,$o,$initial){if($o.enhance-ge 6){return @{action='markDiscard';lower=78;upper=79}};return @{action='enhance';targetLevel=$o.enhance+3;lower=90;upper=90}}
$outcome=Process-Relic $candidate 'test';Assert ($outcome-eq'discard'-and($script:targets-join',')-eq'3,6'-and$script:marks-eq 1) 'Low score marks discard and stops spending'
$PreviewOnly=$true;$script:level=0;$script:targets=@();$script:cancelledPreview=$false;$script:state=@{processed=0;kept=0;marked=0;confirmedSteps=0}
function Cancel-PreparedEnhancement {$script:cancelledPreview=$true}
$outcome=Process-Relic $candidate 'test';Assert ($outcome-eq'preview'-and$script:state.confirmedSteps-eq 0-and$script:state.marked-eq 0-and$script:cancelledPreview) 'Preview prepares then cancels with zero confirmations or discard'
Write-Output ('Upgrade core/executor checks passed: '+$script:checks+'; game input sent: 0')
