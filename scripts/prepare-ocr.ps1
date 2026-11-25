param([string]$SourceRoot='')
$ErrorActionPreference='Stop';if(-not$SourceRoot){$SourceRoot=Split-Path $PSScriptRoot -Parent}
$dir=Join-Path $SourceRoot 'source/ocr';$manifest=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $dir 'PROVENANCE.json')))
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
foreach($asset in $manifest.downloads){
 $file=Join-Path $dir $asset.name
 if(-not(Test-Path -LiteralPath $file)){$part=$file+'.part';try{Invoke-WebRequest -UseBasicParsing -Uri $asset.url -OutFile $part -TimeoutSec 120;if((Get-FileHash -LiteralPath $part -Algorithm SHA256).Hash.ToLowerInvariant()-ne$asset.sha256){throw ('OCR checksum mismatch: '+$asset.name)};Move-Item -LiteralPath $part -Destination $file -Force}finally{if(Test-Path -LiteralPath $part){Remove-Item -LiteralPath $part -Force}}}
 if((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant()-ne$asset.sha256){throw ('OCR checksum mismatch: '+$asset.name)}
}
Write-Output 'Offline OCR binaries verified.'
