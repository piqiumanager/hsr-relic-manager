$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'marker-core.ps1');. (Join-Path $root 'live-core.ps1')
$data=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $root 'source/data.json')))
$piece=$data.pieceNames.'117'.Head;$set=$data.sets.'117'.name
$panel=@(@{text=$piece;y=20},@{text='+0';y=100},@{text='生命值 112';y=220},@{text=$set;y=400})
$subs=@(@{text='暴击率 3.2%'},@{text='攻击力 4.3%'},@{text='速度 2'},@{text='暴击伤害（+3激活）6.4%'})
$r=ConvertFrom-LivePanel $panel $subs $data 336
if($r.substats.Count-ne 3-or$r.preview_substats.Count-ne 1-or$r.mainstat-ne'HP'){throw 'Active/preview parsing failed'}
if((Get-LiveInventoryCount @(@{text='遗器数量 2820/3000'}))-ne 2820){throw 'Count parse failed'}
$req=@{requestId='a';observation=@{rarity=5;lock=$false;discard=$false;location=''}}
Assert-LiveDecision $req @{requestId='a';action='markDiscard';verified=$true}|Out-Null
$req.observation.lock=$null;$rejected=$false;try{Assert-LiveDecision $req @{requestId='a';action='markDiscard';verified=$true}}catch{$rejected=$true};if(-not$rejected){throw 'Unknown lock authorized'}
foreach($file in @('server.ps1','live.ps1','live-core.ps1','live-server.ps1')){$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile((Join-Path $root $file),[ref]$t,[ref]$e)|Out-Null;if($e.Count){throw ($file+': '+$e[0].Message)}}
Write-Output 'Live screen parser, preview stat, inventory count, protected-state decision and worker syntax checks passed.'
Add-Type -AssemblyName System.Drawing;Add-Type -AssemblyName System.Windows.Forms
Add-Type -Path (Join-Path $root 'marker-native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
$panelImage=New-Object Drawing.Bitmap(480,950);$g=[Drawing.Graphics]::FromImage($panelImage);$g.Clear([Drawing.Color]::FromArgb(30,30,30));$g.Dispose()
if([RelicNative]::EquippedFooterState($panelImage)-ne 0){throw 'Empty footer incorrectly marked equipped'}
$g=[Drawing.Graphics]::FromImage($panelImage);$pen=New-Object Drawing.Pen([Drawing.Color]::FromArgb(150,150,150),2);$g.DrawRectangle($pen,20,783,440,39);$g.Dispose();$pen.Dispose()
if([RelicNative]::EquippedFooterState($panelImage)-ne 1){throw 'Equipped border not protected'}
$g=[Drawing.Graphics]::FromImage($panelImage);$g.Clear([Drawing.Color]::FromArgb(30,30,30));$pen=New-Object Drawing.Pen([Drawing.Color]::FromArgb(58,58,58),2);$g.DrawRectangle($pen,20,783,440,39);$g.Dispose();$pen.Dispose()
if([RelicNative]::EquippedFooterState($panelImage)-ne -1){throw 'Uncertain footer not protected'};$panelImage.Dispose()
$a=@{set_id='117';slot='Head';mainstat='HP';pieceName='x';level=15;mainstat_value=705;substats=@(@{key='ATK';value=55},@{key='SPD';value=6},@{key='CRIT DMG';value=5.1},@{key='DEF';value=16});preview_substats=@();numericFingerprint='same'}
$b=ConvertFrom-Json (ConvertTo-Json $a -Depth 10);$b.numericFingerprint='different pixels'
if(-not(Test-LiveIdentity $a $b)){throw 'Identical attributes with different pixels rejected'}
$b.substats[0].value=76;if(Test-LiveIdentity $a $b){throw 'Changed live numbers accepted'}
$b=ConvertFrom-Json (ConvertTo-Json $a -Depth 10);$b.level=12;if(Test-LiveIdentity $a $b){throw 'Changed level accepted'}
$b=ConvertFrom-Json (ConvertTo-Json $a -Depth 10);$b.preview_substats=@(@{key='ATK%';value=4.3});if(Test-LiveIdentity $a $b){throw 'Changed active/preview structure accepted'}
Write-Output 'Visual equipped protection and strict pre/post-mark identity checks passed; no game input.'
