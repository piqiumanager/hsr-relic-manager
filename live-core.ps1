# Live screen parsing. Unknown identity, rarity or state never authorizes a mark.
function Get-LiveStatLabel([string]$Text){
    $text=Normalize-MarkerText $Text
    foreach($key in @($script:MarkerStatNames.Keys|Sort-Object {$script:MarkerStatNames[$_].Length} -Descending)){$label=$script:MarkerStatNames[$key];if($text.Contains($label)){if($key-in @('HP%','ATK%','DEF%')){$key=$key.TrimEnd('%')};return $key}}
    return $null
}
function ConvertFrom-LivePanel($Panel,$Subs,$Data,[double]$SubstatsTop,[switch]$NumbersPending){
    $full=Normalize-MarkerText (($Panel|ForEach-Object{$_.text})-join'')
    $matches=@()
    foreach($set in $Data.pieceNames.PSObject.Properties){foreach($part in $set.Value.PSObject.Properties){if($full.Contains((Normalize-MarkerText ([string]$part.Value)))){$matches+=,@{setId=$set.Name;part=$part.Name;piece=[string]$part.Value}}}}
    if($matches.Count-ne 1){throw '未能唯一识别遗器单件名称。'}
    $piece=$matches[0];$setName=[string]$Data.sets.($piece.setId).name
    if(-not$full.Contains((Normalize-MarkerText $setName))){throw '未识别到对应套装名称。'}
    $head=@($Panel|Where-Object{$_.y-lt$SubstatsTop});$text=Normalize-MarkerText (($head|ForEach-Object{$_.text})-join'')
    $levels=@([regex]::Matches($text,'(?<![0-9])\+([0-9]{1,2})(?![0-9.])')|ForEach-Object{[int]$_.Groups[1].Value}|Select-Object -Unique)
    if($levels.Count-ne 1-or$levels[0]-gt 15){if($NumbersPending){$levels=@(-1)}else{throw '未能唯一识别强化等级。'}}
    $mains=@($head|ForEach-Object{Get-StatObservation $_.text}|Where-Object{$null-ne$_})
    if($NumbersPending){$mains=@($head|Where-Object{$_.y-ge($SubstatsTop-55)}|ForEach-Object{$label=Get-LiveStatLabel $_.text;if($label){@{stat=$label;value=0}}})}
    if($mains.Count-ne 1){throw '未能唯一识别主属性。'}
    $active=@();$preview=@()
    foreach($line in $Subs){$s=Get-StatObservation $line.text;if($NumbersPending){$label=Get-LiveStatLabel $line.text;if($label){$s=@{stat=$label;value=0}}};if(-not$s){continue};$sub=@{key=$s.stat;value=$s.value};if((Normalize-MarkerText $line.text)-match'激活|解锁|生效'){$preview+=,$sub}else{$active+=,$sub}}
    if($active.Count-lt 3-or$active.Count-gt 4-or($active.Count+$preview.Count)-gt 4-or($levels[0]-ge 3-and($active.Count-ne 4-or$preview.Count-ne 0))){throw '副属性未完整识别。'}
    return @{set_id=$piece.setId;slot=$piece.part;rarity=5;level=$levels[0];mainstat=$mains[0].stat;mainstat_value=$mains[0].value;substats=$active;preview_substats=$preview;location=$(if($full-match'已装备|装备中'){'live-equipped'}else{''});pieceName=$piece.piece}
}
function Get-LiveInventoryCount($Lines){
    $text=Normalize-MarkerText (($Lines|ForEach-Object{$_.text})-join'')
    if($text-match'遗器数量([0-9]{1,4})/3000'){return [int]$Matches[1]}
    throw '未识别到遗器总数，请打开遗器背包。'
}
function Assert-LiveDecision($Request,$Decision){
    if($Request.requestId-ne$Decision.requestId){throw '当前遗器的评分回应已过期。'}
    if($Decision.action-notin @('keep','skip','markDiscard','stop')){throw '未知现场评分决策。'}
    if($Decision.action-eq'markDiscard'){
        $r=$Request.observation
        if($r.rarity-ne 5-or$r.lock-ne$false-or$r.discard-ne$false-or$r.location-cne''-or$Decision.verified-ne$true){throw '当前遗器受保护或评分未核实。'}
    }
    return $true
}
function Test-LiveIdentity($A,$B){
    if(-not$A-or-not$B-or$null-eq$A.level-or$null-eq$B.level-or$A.level-lt 0-or$A.level-ne$B.level-or$A.set_id-cne$B.set_id-or$A.slot-cne$B.slot-or$A.mainstat-cne$B.mainstat-or$A.pieceName-cne$B.pieceName-or$null-eq$A.mainstat_value-or$null-eq$B.mainstat_value-or[Math]::Abs($A.mainstat_value-$B.mainstat_value)-gt .011){return $false}
    foreach($key in @('substats','preview_substats')){
      $left=@($A.$key|Where-Object{$null-ne$_});$right=@($B.$key|Where-Object{$null-ne$_});if($left.Count-ne$right.Count){return $false}
      foreach($s in $left){$match=@($right|Where-Object{$_.key-ceq$s.key});if($match.Count-ne 1-or[Math]::Abs($s.value-$match[0].value)-gt .011){return $false}}
    }
    return @($A.substats).Count-ge 3
}
