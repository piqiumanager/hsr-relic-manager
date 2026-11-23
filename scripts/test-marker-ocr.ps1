$ErrorActionPreference='Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'marker-core.ps1')
Initialize-MarkerOcr
Add-Type -AssemblyName System.Drawing
$bmp=New-Object Drawing.Bitmap(800,350)
$g=[Drawing.Graphics]::FromImage($bmp)
$g.Clear([Drawing.Color]::White)
$font=New-Object Drawing.Font('Microsoft YaHei',26)
$items=@('攻击力 8.6%','暴击伤害 19.4%','速度 6','防御力 21')
for($i=0;$i -lt $items.Count;$i++){$g.DrawString($items[$i],$font,[Drawing.Brushes]::Black,30,(20+$i*75))}
$scratch=Join-Path (Split-Path -Parent $PSScriptRoot) 'work';[IO.Directory]::CreateDirectory($scratch)|Out-Null;$file=Join-Path $scratch 'ocr-synthetic.png'
$bmp.Save($file,[Drawing.Imaging.ImageFormat]::Png)
$g.Dispose();$font.Dispose();$bmp.Dispose()
$lines=Read-MarkerOcr $file
$observed=@($lines | ForEach-Object { Get-StatObservation $_.text })
$expected=@(@{stat='ATK%';value=8.64},@{stat='CRIT DMG';value=19.44},@{stat='SPD';value=6.9},@{stat='DEF';value=21.168754})
if(-not (Test-ObservedStats $observed $expected)){throw ('Synthetic OCR mismatch: '+(ConvertTo-Json $lines -Compress))}
Write-Output ('Windows Chinese OCR passed: '+(ConvertTo-Json $lines -Compress))
