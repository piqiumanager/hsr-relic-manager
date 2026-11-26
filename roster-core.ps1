# Pure roster parsing and validation. No window or native input access.
function Normalize-RosterText([string]$Text){return ($Text.Normalize()-replace '[\s·•・‧∙.．?？☆★:：]','').Trim()}
function Get-RosterMenuEntries($Lines){
    $result=@();foreach($line in $Lines){
        if(-not$line.words){$result+=,$line;continue}
        $group=$null;foreach($word in @($line.words|Sort-Object @{Expression={[double]$_.x}})){
            if(-not$group-or$word.x-($group.x+$group.width)-gt 36){if($group){$result+=,$group};$group=@{text=[string]$word.text;x=$word.x;y=$word.y;width=$word.width;height=$word.height}}
            else{$right=[Math]::Max($group.x+$group.width,$word.x+$word.width);$group.text+=[string]$word.text;$group.width=$right-$group.x;$group.height=[Math]::Max($group.height,$word.height)}
        };if($group){$result+=,$group}
    };return ,$result
}
function Get-RosterAccountUid($Lines){
    $text=($Lines|ForEach-Object{([string]$_.text)-replace '\s',''})-join "`n"
    $found=@([regex]::Matches($text,'(?i)U[1I]D[:：]?([0-9]{8,10})(?![0-9])')|ForEach-Object{$_.Groups[1].Value}|Select-Object -Unique)
    if($found.Count-ne 1){throw '未能唯一识别当前账号 UID，请退出对话后重新读取。'};return $found[0]
}
function Get-RosterPath($Lines){
    $paths=@('毁灭','巡猎','智识','同谐','虚无','存护','丰饶','记忆','欢愉')
    $text=Normalize-RosterText (($Lines|ForEach-Object{$_.text})-join'');$found=@($paths|Where-Object{$text-match$_})
    if($found.Count-ne 1){throw '角色命途未能唯一识别。'};return $found[0]
}
function ConvertFrom-RosterSummary($Lines,$Data,[bool]$TrailblazerConfirmed=$false){
    $nameLines=@($Lines|Where-Object{$_.y-lt 55});$name=Normalize-RosterText (($nameLines|ForEach-Object{$_.text})-join'')
    $path=Get-RosterPath @($Lines|Where-Object{$_.y-ge 55-and$_.y-lt 105})
    $levelText=($Lines|Where-Object{$_.y-ge 105-and$_.y-lt 180}|ForEach-Object{$_.text})-join''
    if(($levelText-replace '\s','') -notmatch '等级([0-9]{1,2})[/／]([0-9]{1,2})'){throw '角色等级未识别，无法确认这是已拥有角色的详情页。'}
    $level=[int]$Matches[1];$max=[int]$Matches[2];if($level-lt 1-or$level-gt$max-or$max-gt 80){throw '角色等级不合法。'}
    $candidates=@();foreach($entry in $Data.charNames.PSObject.Properties){
        if($entry.Name-notmatch '^[0-9]+$'){continue};$label=[string]$entry.Value.name
        if($label-match '^(.+)\s*[(（]([^()（）]+)[)）]$'){$baseName=$Matches[1].Trim();$form=$Matches[2];if($form-ne$path){continue}}else{$baseName=$label}
        if((Normalize-RosterText $baseName)-ceq$name){$candidates+=@{id=$entry.Name;name=$label;rarity=[int]$entry.Value.rarity}}
    }
    if($TrailblazerConfirmed){
        # Gender variants have identical scoring weights. Store one canonical ID for this observed path only.
        $candidates=@($Data.charNames.PSObject.Properties|Where-Object{$_.Name-match '^80[0-9]{2}$'-and$_.Value.name-match ('\('+[regex]::Escape($path)+'\)')}|Sort-Object Name|Select-Object -First 1|ForEach-Object{@{id=$_.Name;name=('开拓者 · '+$path);rarity=5}})
    }
    if($candidates.Count-ne 1){throw ('角色名未能唯一识别：'+$name+'，请重新读取。')}
    return @{id=$candidates[0].id;name=$candidates[0].name;rarity=$candidates[0].rarity;path=$path;level=$level}
}
function Test-RosterTrailblazerIntro($Lines){$text=Normalize-RosterText (($Lines|ForEach-Object{$_.text})-join'');return ($text-match'角色简介'-and$text-match'登上星穹列车'-and$text-match'星核带来的危机')}
function Get-RosterDigest([string]$Uid,$Characters){
    $ids=@($Characters|ForEach-Object{[string]$_.id}|Sort-Object -Unique);$bytes=[Text.Encoding]::UTF8.GetBytes($Uid+':'+($ids-join','));$sha=[Security.Cryptography.SHA256]::Create()
    try{return [BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Assert-AccountRoster($Roster,$Data){
    if($Roster.state-ne'complete'-or$Roster.complete-ne$true-or$Roster.source-ne'game-character-ocr'-or[string]$Roster.accountUid-notmatch'^[0-9]{8,10}$'){throw '请先在“账号角色”中完整读取当前账号。'}
    $characters=@($Roster.characters);if($characters.Count-lt 1-or$characters.Count-gt 200-or$Roster.visitedCount-lt$characters.Count){throw '账号五星名单为空或不完整。'}
    $seen=@{};foreach($c in $characters){$id=[string]$c.id;$meta=$Data.charNames.PSObject.Properties[$id];if(-not$meta-or$meta.Value.rarity-ne 5-or$seen.ContainsKey($id)){throw '账号名单存在未知角色、四星或重复角色。'};$seen[$id]=$true
      if(-not$Data.profiles.PSObject.Properties[$id]){throw ('已有五星缺少评分权重：'+$meta.Value.name+'。请更新数据后再筛选。')}
    }
    if($Roster.digest-cne(Get-RosterDigest $Roster.accountUid $characters)){throw '账号名单校验不通过，请重新读取。'};return $true
}
