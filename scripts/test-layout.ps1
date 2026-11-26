$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'layout-1080.ps1');$c=Get-RelicLayout1080 1920 1080
if($c.first[0]-ne 136-or$c.panel.width-ne 480){throw 'Layout incorrect'}
$bad=$false;try{Get-RelicLayout1080 2560 1440}catch{$bad=$true};if(-not$bad){throw 'Unsupported resolution accepted'}
$keys=@(0..17|ForEach-Object{Get-RelicNavigationKey $_});if(($keys-join'')-ne'DDDDDDDDSAAAAAAAAS'){throw 'Snake traversal incorrect'}
Add-Type -AssemblyName System.Drawing;Add-Type -AssemblyName System.Windows.Forms
Add-Type -Path (Join-Path $root 'marker-native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
$b=New-Object Drawing.Bitmap(38,38);$g=[Drawing.Graphics]::FromImage($b);$g.Clear([Drawing.Color]::FromArgb(170,140,100));$g.FillRectangle([Drawing.Brushes]::White,14,13,10,13);$g.Dispose();if([RelicNative]::LockState($b)-ne 0){throw 'Pale glyph on banner must mean unlocked'};$b.Dispose()
$b=New-Object Drawing.Bitmap(38,38);$g=[Drawing.Graphics]::FromImage($b);$g.Clear([Drawing.Color]::Goldenrod);$g.FillEllipse([Drawing.Brushes]::White,3,3,32,32);$g.FillRectangle([Drawing.Brushes]::Black,14,13,10,13);$g.Dispose();if([RelicNative]::LockState($b)-ne 1){throw 'Dark glyph on pale disk must mean locked'};$b.Dispose()
$b=New-Object Drawing.Bitmap(38,38);$g=[Drawing.Graphics]::FromImage($b);$g.Clear([Drawing.Color]::Goldenrod);$g.Dispose();if([RelicNative]::LockState($b)-ne -1){throw 'Missing glyph must remain unknown'};$b.Dispose()
Write-Output 'Fixed layout, keyboard sequence and native icon recognition passed; no game input sent.'
