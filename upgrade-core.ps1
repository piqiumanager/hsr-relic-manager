# Pure recognition and contract checks shared by the live executor and tests.
function Find-UpgradeControl($Lines,[string[]]$Texts,$Region,$Exclude=$null){
    $wanted=@($Texts|ForEach-Object{Normalize-MarkerText $_});$found=@()
    foreach($line in $Lines){
        $parts=if($line.words){@($line.words)}else{@($line)}
        for($i=0;$i-lt$parts.Count;$i++){
            $text='';$left=[double]$parts[$i].x;$top=[double]$parts[$i].y;$right=$left;$bottom=$top
            for($j=$i;$j-lt[Math]::Min($parts.Count,$i+16);$j++){
                $p=$parts[$j];$text+=Normalize-MarkerText $p.text;$right=[Math]::Max($right,$p.x+$p.width);$bottom=[Math]::Max($bottom,$p.y+$p.height)
                if($wanted-notcontains$text){continue}
                $cx=[int](($left+$right)/2);$cy=[int](($top+$bottom)/2)
                if($cx-lt$Region.x-or$cy-lt$Region.y-or$cx-ge($Region.x+$Region.width)-or$cy-ge($Region.y+$Region.height)){continue}
                if($Exclude-and[Math]::Abs($cx-$Exclude.cx)-lt 15-and[Math]::Abs($cy-$Exclude.cy)-lt 15){continue}
                if(@($found|Where-Object{[Math]::Abs($_.cx-$cx)-lt 5-and[Math]::Abs($_.cy-$cy)-lt 5}).Count-eq 0){$found+=,@{text=$text;cx=$cx;cy=$cy;x=$left;y=$top;width=$right-$left;height=$bottom-$top}}
            }
        }
    }
    if($found.Count-gt 1){throw ('控件不唯一：'+($Texts-join'/'))}
    if($found.Count-eq 1){return $found[0]};return $null
}
function Get-UpgradeProjection($Lines,[int]$Current,[int]$Target){
    if($Target-ne[Math]::Min(15,([Math]::Floor($Current/3)+1)*3)-or$Current-ge 15){throw '强化目标不是下一档 +3。'}
    $text=Normalize-MarkerText (($Lines|ForEach-Object{$_.text})-join' ')
    $levels=@([regex]::Matches($text,'(?<![0-9])\+([0-9]{1,2})(?![0-9.])')|ForEach-Object{[int]$_.Groups[1].Value})
    if($levels-contains$Current-and$levels-contains$Target-and@($levels|Where-Object{$_-gt$Target-and$_-le 15}).Count-eq 0){return $true}
    if($text-match('(?<![0-9])\+?'+$Current+'(?:→|➜|->|＞|>)+\+?'+$Target+'(?![0-9])')){return $true}
    throw ('无法核实预期等级 +'+$Current+' → +'+$Target+'，未执行强化。')
}
function Test-UpgradeMaterialCaption($Lines){
    $text=Normalize-MarkerText (($Lines|ForEach-Object{$_.text})-join'')
    return ($text-match'(?:4星及以下|四星及以下|四星以下|4星以下)'-and$text-notmatch'(?:5星及以下|五星及以下|五星以下|5星以下)')
}
function ConvertTo-UpgradeObservation($Candidate,$PanelLines,$SubstatLines,[int]$ExpectedLevel,[double]$SubstatsTop){
    $full=Normalize-MarkerText (($PanelLines|ForEach-Object{$_.text})-join'')
    if(-not$full.Contains((Normalize-MarkerText $Candidate.pieceName))-or-not$full.Contains((Normalize-MarkerText $Candidate.setName))){throw '强化后的遗器名称或套装不一致。'}
    $head=@($PanelLines|Where-Object{$_.y-lt$SubstatsTop});$headText=Normalize-MarkerText (($head|ForEach-Object{$_.text})-join'')
    if($headText-notmatch('(?<![0-9])\+'+$ExpectedLevel+'(?![0-9])')){throw ('未读到预期强化等级 +'+$ExpectedLevel+'。')}
    $mains=@($head|ForEach-Object{Get-StatObservation $_.text}|Where-Object{$null-ne$_-and$_.stat-eq$Candidate.main.stat})
    if($mains.Count-ne 1){throw '无法唯一识别强化后的主属性。'}
    $subs=@($SubstatLines|ForEach-Object{Get-StatObservation $_.text}|Where-Object{$null-ne$_})
    if($ExpectedLevel-ge 3-and$subs.Count-ne 4){throw '强化后的四个副属性未完整识别。'}
    if(@($subs.stat|Select-Object -Unique).Count-ne$subs.Count){throw '强化后副属性重复。'}
    return @{setId=[string]$Candidate.setId;part=[string]$Candidate.part;main=@{stat=$mains[0].stat;value=$mains[0].value};enhance=$ExpectedLevel;substats=@($subs|ForEach-Object{@{stat=$_.stat;value=$_.value}});locked=$false;owner='';discarded=$false}
}
function Assert-UpgradeDecision($Request,$Decision){
    if($Request.requestId-ne$Decision.requestId){throw '强化评分回应已过期。'}
    $level=[int]$Request.observation.enhance
    if($Decision.action-eq'stop'){return $true}
    $low=[double]$Decision.lower;$high=[double]$Decision.upper
    if([double]::IsNaN($low)-or[double]::IsInfinity($low)-or[double]::IsNaN($high)-or[double]::IsInfinity($high)-or$high-lt$low){throw '强化评分区间无效。'}
    switch($Decision.action){
      'enhance'{if($level-ge 15-or$Decision.targetLevel-ne[Math]::Min(15,$level+3)-or$low-lt 80){throw '强化评分或目标等级不满足规则。'}}
      'markDiscard'{if($high-ge 80){throw '不能弃置可能达到 80 分的遗器。'}}
      'keep'{if($level-ne 15-or$low-lt 80){throw '满级保留条件不满足。'}}
      default{throw '未知强化决策。'}
    }
    return $true
}
