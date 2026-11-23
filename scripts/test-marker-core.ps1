$ErrorActionPreference='Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'marker-core.ps1')
$script:Tests=0
function Assert($condition,[string]$message){if(-not $condition){throw $message};$script:Tests++}
$candidate=@{key='a';setName='死水深潜的先驱';enhance=15;main=@{stat='CRIT Rate';value=32.4};substats=@(@{stat='ATK%';value=8.64},@{stat='CRIT DMG';value=19.44},@{stat='SPD';value=6.9},@{stat='DEF';value=21.168754})}
$panel=@(@{text='死水深潜的先驱';y=500},@{text='+15';y=110},@{text='暴击率 32.4%';y=180})
$subs=@(@{text='攻击力 8.6%';y=10},@{text='暴击伤害 19.4%';y=40},@{text='速度 6';y=70},@{text='防御力 21';y=100})
$match=Find-MarkerMatch @($candidate) $panel $subs 230
Assert ($match.key -eq 'a') 'complete fingerprint matches'
Assert ((Find-MarkerMatch @($candidate) $panel @($subs[0],$subs[1],$subs[2]) 230) -eq $null) 'missing substat rejected'
$wrong=@($subs[0],$subs[1],@{text='速度 7';y=70},$subs[3])
Assert ((Find-MarkerMatch @($candidate) $panel $wrong 230) -eq $null) 'different speed rejected'
Assert ((Find-MarkerMatch @($candidate,$candidate) $panel $subs 230) -eq $null) 'ambiguous fingerprint rejected'
$wrongPanel=@(@{text='死水深潜的先驱';y=500},@{text='+12';y=110},@{text='暴击率 32.4%';y=180})
Assert ((Find-MarkerMatch @($candidate) $wrongPanel $subs 230) -eq $null) 'wrong enhancement rejected'
Assert ((Get-DisplayValue 'CRIT Rate' 3.24) -eq '3.2') 'game percent display truncated'
Assert ((Get-DisplayValue 'SPD' 6.9) -eq '6') 'hidden speed decimals excluded from visual check'
Assert ((Get-StatObservation '防御力 + 5.4%').stat -eq 'DEF%') 'flat and percent disambiguated'
Assert ((Get-StatObservation '防御力 + 21').stat -eq 'DEF') 'flat stat recognized'
Assert ((Get-StatObservation '暴击率 3.2').stat -eq $null) 'missing percent rejected'
$c=@{schema='hsr-marker-calibration-v1';width=1920;height=1080;grid=@{x=160;y=220;dx=110;dy=130;cols=9;rows=5};panel=@{x=1200;y=100;width=650;height=750};substats=@{x=1250;y=360;width=400;height=200};anchor=@{x=50;y=40;width=250;height=40};discardRect=@{x=1750;y=120;width=30;height=30};unlockRect=@{x=1700;y=120;width=30;height=30};discardPoint=@(1765,135);unlockPoint=@(1715,135)}
$c.rarityRect=@{x=126;y=253;width=68;height=14}
Assert (Test-MarkerCalibration $c) 'valid calibrated geometry accepted'
$c.discardPoint=@(1600,1000);$rejected=$false;try{Test-MarkerCalibration $c}catch{$rejected=$true};Assert $rejected 'bottom salvage/confirm region rejected'
$c.discardPoint=@(600,300);$rejected=$false;try{Test-MarkerCalibration $c}catch{$rejected=$true};Assert $rejected 'grid cannot be configured as discard control'
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'marker-native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
# Compile-only: no window activation, screenshots, or input calls in this test.
Assert ($null -ne ('RelicNative' -as [Type])) 'native bridge compiles'
$gray=New-Object Drawing.Bitmap(30,30);$red=New-Object Drawing.Bitmap(30,30);$changed=New-Object Drawing.Bitmap(30,30)
$g=[Drawing.Graphics]::FromImage($gray);$g.Clear([Drawing.Color]::Gray);$g.Dispose()
$g=[Drawing.Graphics]::FromImage($red);$g.Clear([Drawing.Color]::Gray);$g.FillRectangle([Drawing.Brushes]::Red,7,7,15,15);$g.Dispose()
$g=[Drawing.Graphics]::FromImage($changed);$g.Clear([Drawing.Color]::Black);$g.Dispose()
Assert (Test-UnmarkedVisual $gray $gray $gray $gray) 'same unmarked and unlocked icons accepted'
Assert (-not (Test-UnmarkedVisual $red $gray $gray $gray)) 'already discarded icon never toggled'
Assert (-not (Test-UnmarkedVisual $gray $changed $gray $gray)) 'changed lock icon rejected'
Assert (Test-MarkedVisual $red $gray) 'red state change verified'
Assert (-not (Test-MarkedVisual $gray $gray)) 'unchanged state is not claimed marked'
$gray.Dispose();$red.Dispose();$changed.Dispose()
Write-Output ('Marker matching/geometry checks passed: '+$script:Tests)
