# Live screen parsing. Unknown identity, rarity or state never authorizes a mark.
function Get-LiveStatLabel([string]$Text){
    $text=Normalize-MarkerText $Text
    foreach($key in @($script:MarkerStatNames.Keys|Sort-Object {$script:MarkerStatNames[$_].Length} -Descending)){$label=$script:MarkerStatNames[$key];if($text.Contains($label)){if($key-in @('HP%','ATK%','DEF%')){$key=$key.TrimEnd('%')};return $key}}
    foreach($entry in @(@('物理','Physical'),@('火','Fire'),@('冰','Ice'),@('雷','Lightning'),@('风','Wind'),@('量子','Quantum'),@('虚数','Imaginary'))){if($text.Contains($entry[0]+'属性伤害')){return $entry[1]+' DMG Boost'}}
    return $null
}
function ConvertFrom-LivePanel($Panel,$Subs,$Data,[double]$SubstatsTop,[switch]$NumbersPending,$MainLines=$null){
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
    if($NumbersPending-and$null-ne$MainLines){$label=Get-LiveStatLabel (($MainLines|ForEach-Object{$_.text})-join'');$mains=@();if($label){$mains=@(@{stat=$label;value=0})}}
    if($NumbersPending-and$mains.Count-eq 0-and$piece.part-in @('Head','Hands')){$mains=@(@{stat=$(if($piece.part-eq'Head'){'HP'}else{'ATK'});value=0})}
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
function Assert-LiveDecision($Request,$Decision,[bool]$AllowUnlockLowPotential=$false,[bool]$AllowEnhance=$false){
    if($Request.requestId-ne$Decision.requestId){throw '当前遗器的评分回应已过期。'}
    if($Decision.action-notin @('keep','skip','markDiscard','stop','enhance')){throw '未知现场评分决策。'}
    if($Decision.action-eq'markDiscard'){
        $r=$Request.observation
        $lockAllowed=$r.lock-eq$false-or($r.lock-eq$true-and$Decision.unlockFirst-eq$true-and$AllowUnlockLowPotential)
        if($r.rarity-ne 5-or-not$lockAllowed-or$r.discard-ne$false-or$r.location-cne''-or$Decision.verified-ne$true){throw '当前遗器受保护或评分未核实。'}
        $o=$Decision.observation;$potential=if($o.level-eq 15){$Decision.currentScore}else{$Decision.averagePotential}
        if($null-eq$o.level-or$o.level-lt 0-or$o.level-gt 15-or$o.level-ne[Math]::Floor([double]$o.level)-or$null-eq$potential-or[double]::IsNaN([double]$potential)-or[double]::IsInfinity([double]$potential)-or[double]$potential-lt 0-or[double]$potential-ge 80){throw '仅允许标记未满级平均潜力或满级当前分低于 80 的遗器。'}
    }
    if($Decision.action-eq'enhance'){
        $r=$Request.observation;$o=$Decision.observation;$score=$Decision.averagePotential
        if(-not$AllowEnhance-or$Request.upgrade-ne$true-or$r.rarity-ne 5-or$r.lock-ne$false-or$r.discard-ne$false-or$r.location-cne''-or$Decision.verified-ne$true){throw '未授权强化或遗器受保护。'}
        if($null-eq$o.level-or$o.level-lt 0-or$o.level-ge 15-or$o.level-ne[Math]::Floor([double]$o.level)-or$Decision.targetLevel-ne[Math]::Min(15,([Math]::Floor($o.level/3)+1)*3)-or$null-eq$score-or[double]::IsNaN([double]$score)-or[double]::IsInfinity([double]$score)-or[double]$score-lt 80){throw '强化目标或评分不满足 +3 / 80 分规则。'}
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

function Assert-LiveAdvance($Before,$After,[int]$Target){
    if($Target-ne[Math]::Min(15,([Math]::Floor($Before.level/3)+1)*3)-or$After.level-ne$Target-or$Before.set_id-cne$After.set_id-or$Before.slot-cne$After.slot-or$Before.pieceName-cne$After.pieceName-or$Before.mainstat-cne$After.mainstat-or$After.lock-ne$false-or$After.discard-ne$false-or$After.location-cne''){throw '强化后的遗器身份、等级或保护状态不一致。'}
    if(@($After.substats).Count-ne 4-or@($After.preview_substats).Count-ne 0){throw '强化后四个副属性未完整识别。'}
    foreach($s in $Before.substats){$next=@($After.substats|Where-Object{$_.key-ceq$s.key});if($next.Count-ne 1-or$next[0].value+0.011-lt$s.value){throw '强化后副属性减少或缺失。'}}
    if($After.mainstat_value-le$Before.mainstat_value){throw '强化后主属性未提升。'}
    return $true
}
