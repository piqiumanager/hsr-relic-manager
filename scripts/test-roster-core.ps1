$ErrorActionPreference='Stop';$root=Split-Path $PSScriptRoot -Parent;$utf8=New-Object Text.UTF8Encoding($false)
. (Join-Path $root 'roster-core.ps1')
$data=ConvertFrom-Json ([IO.File]::ReadAllText((Join-Path $root 'source/data.json'),$utf8));$checks=0
function Assert($v,$name){if(-not$v){throw $name};$script:checks++}
function Bad($fn,$name){$bad=$false;try{& $fn|Out-Null}catch{$bad=$true};Assert $bad $name}
function Lines($name,$path='智识',$level='等级80/80'){return @(@{text=$name;y=15},@{text=$path;y=63},@{text=$level;y=130})}
Assert ((Get-RosterAccountUid @(@{text='UID:900000001'}))-eq'900000001') 'UID label required and parsed'
Bad {Get-RosterAccountUid @(@{text='900000001'})} 'Bare numbers cannot identify an account'
Bad {Get-RosterAccountUid @(@{text='UID:900000001 UID:900000002'})} 'Ambiguous account rejected'
$entries=Get-RosterMenuEntries @(@{text='角色 背包';words=@(@{text='角';x=1300;y=400;width=20;height=20},@{text='色';x=1322;y=400;width=20;height=20},@{text='背包';x=1550;y=400;width=40;height=20})})
Assert ($entries.Count-eq 2-and$entries[0].text-ceq'角色'-and$entries[1].text-ceq'背包') 'Merged full-screen OCR splits spatially distinct menu labels'
foreach($e in $data.charNames.PSObject.Properties|Where-Object{$_.Name-match'^[0-9]+$'-and$_.Name-notmatch'^80'}){
 $name=[string]$e.Value.name;$path='智识';if($name-match'^(.+)\s*[(（]([^()（）]+)[)）]$'){$name=$Matches[1].Trim();$path=$Matches[2]}
 $r=ConvertFrom-RosterSummary (Lines $name $path) $data;Assert ($r.id-ceq$e.Name-and$r.rarity-eq$e.Value.rarity) ('Closed-set name '+$e.Name)
}
$r=ConvertFrom-RosterSummary (Lines '☆阮.梅' '同谐') $data;Assert ($r.id-eq'1303') 'Decorations and name dots normalized'
Bad {ConvertFrom-RosterSummary (Lines '姬子' '智识' '80') $data} 'Owned-character level evidence required'
Bad {ConvertFrom-RosterSummary (Lines '姬子' '智识' '等级99/80') $data} 'Invalid character level rejected'
Bad {ConvertFrom-RosterSummary (Lines '不存在的新角色') $data} 'Unknown characters never guessed'
Bad {Get-RosterPath @(@{text='巡猎 智识'})} 'Ambiguous path rejected'
$r=ConvertFrom-RosterSummary (Lines '自定义昵称' '记忆') $data $true;Assert ($r.id-eq'8007') 'Confirmed protagonist maps only observed path'
Assert (Test-RosterTrailblazerIntro @(@{text='角色简介 登上星穹列车 星核带来的危机'})) 'Protagonist information evidence'
Assert (-not(Test-RosterTrailblazerIntro @(@{text='角色简介 星穹列车'}))) 'Partial protagonist information is insufficient'
$chars=@(@{id='1003';name='姬子';rarity=5});$roster=@{state='complete';complete=$true;source='game-character-ocr';accountUid='900000001';characters=$chars;visitedCount=1;digest=(Get-RosterDigest '900000001' $chars)}
Assert (Assert-AccountRoster $roster $data) 'Complete game roster accepted'
foreach($field in @('state','complete','source','accountUid','digest','characters','visitedCount')){
 $copy=ConvertFrom-Json (ConvertTo-Json $roster -Depth 10);switch($field){'state'{$copy.state='reading'};'complete'{$copy.complete=$false};'source'{$copy.source='manual'};'accountUid'{$copy.accountUid='unknown'};'digest'{$copy.digest='bad'};'characters'{$copy.characters=@(@{id='1001'})};'visitedCount'{$copy.visitedCount=0}}
 Bad {Assert-AccountRoster $copy $data} ('Invalid roster '+$field)
}
$copy=ConvertFrom-Json (ConvertTo-Json $roster -Depth 10);$copy.characters=@($copy.characters[0],$copy.characters[0]);$copy.visitedCount=2;Bad {Assert-AccountRoster $copy $data} 'Duplicate roster entry rejected'
Write-Output ('Roster parser/ownership checks passed: '+$checks+'; no game input.')
