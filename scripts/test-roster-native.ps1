$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;Add-Type -AssemblyName System.Drawing;Add-Type -AssemblyName System.Windows.Forms
Add-Type -Path (Join-Path $root 'marker-native.cs') -ReferencedAssemblies System.Drawing,System.Windows.Forms
$checks=0;function Assert($v,$m){if(-not$v){throw $m};$script:checks++}
foreach($centers in @(@(490,590,690,790,890,990,1090,1190,1290,1390),@(534,636,738,840,942,1044,1146,1248,1350),@(490))){
 $b=New-Object Drawing.Bitmap(1920,1080);$g=[Drawing.Graphics]::FromImage($b);$g.Clear([Drawing.Color]::FromArgb(23,28,42));$pen=New-Object Drawing.Pen([Drawing.Color]::FromArgb(175,187,205),3)
 try{foreach($x in $centers){$g.FillEllipse([Drawing.Brushes]::DarkSlateGray,($x-34),31,68,68);$g.DrawEllipse($pen,($x-35),30,70,70)};$slots=@([RelicNative]::RosterAvatarSlots($b));Assert ($slots.Count-eq$centers.Count) 'All portrait centers detected';foreach($x in $centers){Assert (@($slots|Where-Object{[Math]::Abs($_-$x)-le 4}).Count-eq 1) 'Portrait center accuracy'}
 }finally{$pen.Dispose();$g.Dispose();$b.Dispose()}
}
$b=New-Object Drawing.Bitmap(1920,1080);try{Assert (@([RelicNative]::RosterAvatarSlots($b)).Count-eq 0) 'Blank screen has no portraits'}finally{$b.Dispose()}
Write-Output ('Roster portrait geometry checks passed: '+$checks+'; generated images only, no native input.')
