$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$utf8=New-Object Text.UTF8Encoding($false)
. (Join-Path $root 'marker-core.ps1');. (Join-Path $root 'roster-core.ps1');Initialize-MarkerOcr;Add-Type -AssemblyName System.Drawing
$data=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $root 'source/data.json'),$utf8));$dir=Join-Path $root ('work/roster-ocr-'+[Guid]::NewGuid().ToString('N'));[IO.Directory]::CreateDirectory($dir)|Out-Null
$b=New-Object Drawing.Bitmap(410,180);$g=[Drawing.Graphics]::FromImage($b);$font=New-Object Drawing.Font('Microsoft YaHei',22)
try{$g.Clear([Drawing.Color]::Black);$g.DrawString('阮·梅',$font,[Drawing.Brushes]::White,50,7);$g.DrawString('同谐',$font,[Drawing.Brushes]::White,50,63);$g.DrawString('等级80/80',$font,[Drawing.Brushes]::White,50,123);$file=Join-Path $dir 'summary.png';$b.Save($file,[Drawing.Imaging.ImageFormat]::Png)}finally{$g.Dispose();$font.Dispose();$b.Dispose()}
$lines=Read-MarkerOcr $file;$r=ConvertFrom-RosterSummary $lines $data;if($r.id-ne'1303'-or$r.level-ne 80){throw 'Generated Chinese character summary failed'}
$b=New-Object Drawing.Bitmap(1920,1080);$g=[Drawing.Graphics]::FromImage($b);$font=New-Object Drawing.Font('Microsoft YaHei',24)
try{$g.Clear([Drawing.Color]::Black);$g.DrawString('角色',$font,[Drawing.Brushes]::White,1300,400);$g.DrawString('背包',$font,[Drawing.Brushes]::White,1550,400);$g.DrawString('UID:900000001',$font,[Drawing.Brushes]::White,25,1020);$file=Join-Path $dir 'menu.png';$b.Save($file,[Drawing.Imaging.ImageFormat]::Png)}finally{$g.Dispose();$font.Dispose();$b.Dispose()}
$lines=Read-MarkerOcr $file;$uid=Get-RosterAccountUid $lines;$entries=Get-RosterMenuEntries $lines
if($uid-ne'900000001'-or@($entries|Where-Object{(Normalize-RosterText $_.text)-ceq'角色'}).Count-ne 1-or@($entries|Where-Object{(Normalize-RosterText $_.text)-ceq'背包'}).Count-ne 1){throw ('Generated menu OCR failed: '+(ConvertTo-Json $lines -Depth 6 -Compress))}
Write-Output 'Roster Windows Simplified Chinese OCR passed: name, path, level, UID and separated menu labels; generated images, no game input.'
