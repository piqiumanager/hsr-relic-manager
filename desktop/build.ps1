param([string]$SourceRoot='', [string]$DependencyRoot='', [string]$OutputRoot='', [string]$BuildRoot='')
$ErrorActionPreference='Stop'
if(-not $SourceRoot){$SourceRoot=Split-Path $PSScriptRoot -Parent}
$SourceRoot=[IO.Path]::GetFullPath($SourceRoot)
& (Join-Path $SourceRoot 'scripts/prepare-ocr.ps1') -SourceRoot $SourceRoot
if(-not $DependencyRoot){$DependencyRoot=Join-Path $SourceRoot 'work\desktop-deps'}
if(-not $OutputRoot){$OutputRoot=Join-Path $SourceRoot 'dist'}
if(-not $BuildRoot){$BuildRoot=Join-Path $SourceRoot ('work\desktop-build-'+[Guid]::NewGuid().ToString('N'))}
foreach($p in @($DependencyRoot,$OutputRoot,$BuildRoot)){[IO.Directory]::CreateDirectory([IO.Path]::GetFullPath($p))|Out-Null}
$DependencyRoot=[IO.Path]::GetFullPath($DependencyRoot);$OutputRoot=[IO.Path]::GetFullPath($OutputRoot);$BuildRoot=[IO.Path]::GetFullPath($BuildRoot)
function Download-Verified([string]$Url,[string]$File,[string]$Hash){
    if(-not(Test-Path -LiteralPath $File)){[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $File}
    if((Get-FileHash -LiteralPath $File -Algorithm SHA256).Hash.ToLowerInvariant() -ne $Hash){throw ('Dependency checksum mismatch: '+[IO.Path]::GetFileName($File))}
}
Download-Verified 'https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/1.0.4370.26/microsoft.web.webview2.1.0.4370.26.nupkg' (Join-Path $DependencyRoot 'webview2.nupkg') '1c0dacac84b70109b3fd42f90c53a0ba942abc3a87590d7a4e0ccd86e4a06cf4'
Download-Verified 'https://github.com/IceDynamix/reliquary-archiver/releases/download/v0.20.0/reliquary-archiver-pktmon-x64.exe' (Join-Path $DependencyRoot 'reliquary-archiver.exe') 'ce4a5bb00ba0c3d681772d9151ac2332934dd1b497926c3d7994f40c2a94cd9d'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$sdk=Join-Path $BuildRoot 'sdk';[IO.Compression.ZipFile]::ExtractToDirectory((Join-Path $DependencyRoot 'webview2.nupkg'),$sdk)
$payload=Join-Path $BuildRoot 'payload';[IO.Directory]::CreateDirectory($payload)|Out-Null
foreach($file in @('server.ps1','marker.ps1','marker-core.ps1','marker-native.cs','layout-1080.ps1','upgrade-core.ps1','upgrade.ps1','live-core.ps1','live-server.ps1','live.ps1','enhancement-actions.ps1','roster-core.ps1','roster-navigation.ps1','roster-server.ps1','roster.ps1','星铁遗器整理助手.html','source','licenses','desktop','scripts','README.md','LICENSE','package.json','启动工具.cmd','使用说明.txt')){Copy-Item -LiteralPath (Join-Path $SourceRoot $file) -Destination $payload -Recurse -Force}
$payloadDesktop=Join-Path $payload 'source\desktop';[IO.Directory]::CreateDirectory($payloadDesktop)|Out-Null
foreach($file in @('Launcher.cs','DesktopHost.cs','app.manifest','build.ps1','使用说明.txt')){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination $payloadDesktop -Force}
Copy-Item -LiteralPath (Join-Path $sdk 'lib\net462\Microsoft.Web.WebView2.Core.dll') -Destination $payload
Copy-Item -LiteralPath (Join-Path $sdk 'lib\net462\Microsoft.Web.WebView2.WinForms.dll') -Destination $payload
Copy-Item -LiteralPath (Join-Path $sdk 'runtimes\win-x64\native\WebView2Loader.dll') -Destination $payload
Copy-Item -LiteralPath (Join-Path $sdk 'LICENSE.txt') -Destination (Join-Path $payload 'licenses\WebView2-LICENSE.txt')
Copy-Item -LiteralPath (Join-Path $sdk 'NOTICE.txt') -Destination (Join-Path $payload 'licenses\WebView2-NOTICE.txt')
[IO.Directory]::CreateDirectory((Join-Path $payload 'tools'))|Out-Null
Copy-Item -LiteralPath (Join-Path $DependencyRoot 'reliquary-archiver.exe') -Destination (Join-Path $payload 'tools\reliquary-archiver-pktmon-x64.exe')
# Original geometric icon, drawn at build time; no game image is copied.
Add-Type -AssemblyName System.Drawing
$bitmap=New-Object Drawing.Bitmap(64,64);$g=[Drawing.Graphics]::FromImage($bitmap);$g.SmoothingMode=[Drawing.Drawing2D.SmoothingMode]::AntiAlias;$g.Clear([Drawing.Color]::FromArgb(27,43,76))
$points=[Drawing.PointF[]]@((New-Object Drawing.PointF(32,6)),(New-Object Drawing.PointF(39,25)),(New-Object Drawing.PointF(58,32)),(New-Object Drawing.PointF(39,39)),(New-Object Drawing.PointF(32,58)),(New-Object Drawing.PointF(25,39)),(New-Object Drawing.PointF(6,32)),(New-Object Drawing.PointF(25,25)))
$brush=New-Object Drawing.SolidBrush([Drawing.Color]::FromArgb(238,213,158));$g.FillPolygon($brush,$points);$g.FillEllipse([Drawing.Brushes]::White,46,10,4,4)
$iconHandle=$bitmap.GetHicon();$icon=[Drawing.Icon]::FromHandle($iconHandle);$iconPath=Join-Path $payload 'app.ico';$iconFile=[IO.File]::Create($iconPath);$icon.Save($iconFile);$iconFile.Dispose();$icon.Dispose();$g.Dispose();$brush.Dispose();$bitmap.Dispose()
$csc=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if(-not(Test-Path -LiteralPath $csc)){throw '.NET Framework C# compiler not found.'}
& $csc /nologo /codepage:65001 /target:library /platform:x64 /optimize+ "/out:$(Join-Path $payload 'DesktopHost.dll')" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll "/reference:$(Join-Path $payload 'Microsoft.Web.WebView2.Core.dll')" "/reference:$(Join-Path $payload 'Microsoft.Web.WebView2.WinForms.dll')" (Join-Path $PSScriptRoot 'DesktopHost.cs')
if($LASTEXITCODE -ne 0){throw 'Desktop host compilation failed.'}
$archive=Join-Path $BuildRoot 'payload.zip';[IO.Compression.ZipFile]::CreateFromDirectory($payload,$archive,[IO.Compression.CompressionLevel]::Optimal,$false)
$exe=Join-Path $OutputRoot '星铁遗器整理助手.exe'
& $csc /nologo /codepage:65001 /target:winexe /platform:x64 /optimize+ "/out:$exe" /reference:System.Windows.Forms.dll /reference:System.IO.Compression.dll /reference:System.IO.Compression.FileSystem.dll "/resource:$archive,payload.zip" "/win32manifest:$(Join-Path $PSScriptRoot 'app.manifest')" "/win32icon:$iconPath" (Join-Path $PSScriptRoot 'Launcher.cs')
if($LASTEXITCODE -ne 0){throw 'Launcher compilation failed.'}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '使用说明.txt') -Destination $OutputRoot -Force
$package=Join-Path $BuildRoot 'download';[IO.Directory]::CreateDirectory($package)|Out-Null
Copy-Item -LiteralPath $exe -Destination $package;Copy-Item -LiteralPath (Join-Path $OutputRoot '使用说明.txt') -Destination $package
$zip=Join-Path $OutputRoot 'hsr-relic-manager-v1.5.6-windows.zip'
if(Test-Path -LiteralPath $zip){Remove-Item -LiteralPath $zip -Force}
[IO.Compression.ZipFile]::CreateFromDirectory($package,$zip,[IO.Compression.CompressionLevel]::Optimal,$false)
$direct=Join-Path $OutputRoot 'hsr-relic-manager-v1.5.6.exe';Copy-Item -LiteralPath $exe -Destination $direct -Force
$checks=@();foreach($file in @($exe,$direct,$zip)){ $checks+=((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()+'  '+[IO.Path]::GetFileName($file)) }
[IO.File]::WriteAllLines((Join-Path $OutputRoot 'SHA256SUMS.txt'),$checks,(New-Object Text.UTF8Encoding($false)))
Write-Output ('EXE='+$exe);Write-Output ('ZIP='+$zip);Get-Item -LiteralPath $exe,$zip | Select-Object Name,Length
