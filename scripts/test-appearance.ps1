$ErrorActionPreference='Stop';$base=Split-Path $PSScriptRoot -Parent;$utf8=New-Object Text.UTF8Encoding($false)
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $base 'server.ps1'),[ref]$tokens,[ref]$errors);if($errors.Count){throw $errors[0].Message}
foreach($f in $ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$true)){Invoke-Expression $f.Extent.Text}
$dataBase=Join-Path $base ('work/appearance-'+[Guid]::NewGuid().ToString('N'));$checks=0
if((Get-Appearance).opacity-ne .82){throw 'Default appearance'};$checks++
$credits=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $base 'source/backgrounds/credits.json')));$id=$credits.images[0].id
Save-Appearance @{opacity=.55;lastBackground=$id}|Out-Null;$saved=Get-Appearance;if($saved.opacity-ne .55-or$saved.lastBackground-ne$id){throw 'Persisted appearance'};$checks++
foreach($bad in @(@{opacity=.1;lastBackground=$id},@{opacity=1.1;lastBackground=$id},@{opacity=[double]::NaN;lastBackground=$id},@{opacity=$null;lastBackground=$id},@{opacity=.5;lastBackground='../private'})){$rejected=$false;try{Save-Appearance $bad|Out-Null}catch{$rejected=$true};if(-not$rejected){throw 'Invalid appearance accepted'};$checks++}
[IO.File]::WriteAllText((Join-Path $dataBase 'appearance.json'),'corrupt',$utf8);if((Get-Appearance).opacity-ne .82){throw 'Corrupt preference fallback'};$checks++
Write-Output ('Appearance persistence/validation passed: '+$checks+'; game actions: 0')
