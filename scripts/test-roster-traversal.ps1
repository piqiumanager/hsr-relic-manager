$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$checks=0
Add-Type -TypeDefinition 'public static class RelicNative {public static int Page,Last,Drags;public static bool Jump;public static void DragRosterBar(object w,bool forward){Drags++;if(forward)Page=System.Math.Min(Last,Page+(Jump?2:1));else Page=System.Math.Max(0,Page-1);}}'
. (Join-Path $root 'roster-core.ps1')
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'roster.ps1'),[ref]$tokens,[ref]$errors);if($errors.Count){throw $errors[0].Message}
foreach($f in $ast.FindAll({param($n)$n-is[Management.Automation.Language.FunctionDefinitionAst]},$true)){if($f.Name-in @('Invoke-RosterTraversal','Add-RosterCharacter')){Invoke-Expression $f.Extent.Text}}
function Assert($v,$m){if(-not$v){throw $m};$script:checks++}
function Check-Stop {if($script:cancel-and$state.scanned-ge 4){throw(New-Object OperationCanceledException('Stopped model'))}}
function Start-Sleep {}
function Save-RosterState($s,$m){$state.state=$s}
function Get-RosterSlots {return ,@(0..($pages[[RelicNative]::Page].Count-1)|ForEach-Object{470+85*$_})}
function Select-RosterAvatar($x){Check-Stop;$id=$pages[[RelicNative]::Page][[int](($x-470)/85)];if($script:stuck){$id=$pages[0][0]};return @{id=[string]$id;rarity=$(if($id%4-eq 0){4}else{5});name=('Synthetic '+$id);level=80}}
function Reset($p){$script:pages=$p;$script:visited=@{};$script:characters=New-Object 'Collections.Generic.List[object]';$script:state=@{scanned=0;ownedFiveStar=0;pages=0};[RelicNative]::Page=0;[RelicNative]::Last=$p.Count-1;[RelicNative]::Drags=0;[RelicNative]::Jump=$false;$script:stuck=$false;$script:cancel=$false}
Reset @(@(1..9),@(6..14),@(11..18));Invoke-RosterTraversal
Assert ($visited.Count-eq 18-and$characters.Count-eq 14) 'Overlapping pages cover all characters and retain only five stars'
Assert ($state.pages-eq 3) 'Final page handled without duplicate entries'
Reset (,@(1..3));Invoke-RosterTraversal;Assert ($visited.Count-eq 3) 'Small roster with a single page'
Reset @(@(1..9),@(6..14));$script:stuck=$true;$bad=$false;try{Invoke-RosterTraversal}catch{$bad=$true};Assert $bad 'A failed avatar click cannot masquerade as a second character'
Reset @(@(1..9),@(6..14),@(11..18));[RelicNative]::Jump=$true;Invoke-RosterTraversal;Assert ($visited.Count-eq 18) 'Overshooting page is backed up until overlap is established'
Reset (,@(1..9));$script:cancel=$true;$bad=$false;try{Invoke-RosterTraversal}catch{$bad=$_.Exception-is[OperationCanceledException]};Assert ($bad-and$visited.Count-eq 4) 'Stop prevents reading the next character'
$native=[IO.File]::ReadAllText((Join-Path $root 'roster.ps1'));Assert ($native-notmatch'ClickDiscard|Confirm-Enhancement|Mark-LiveRelic') 'Account scan contains no relic mutation calls'
Write-Output ('Roster traversal checks passed: '+$checks+'; synthetic portrait rail, no game input.')
