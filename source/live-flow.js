globalThis.LiveFlow=(()=>{
 'use strict';
 async function score(request,settings,options={}){
  const E=RelicEngine,C=HSRCore,U=UpgradeFlow,r=globalThis.NumericOcr?await NumericOcr.resolve(request.observation,options):request.observation;if(!r||r.rarity!==5)throw Error('未确认五星遗器');
  const main=C.MainStatsValues[r.mainstat]?.[5];if(!main||!C.PartsMainStats[r.slot]?.includes(r.mainstat)||!Number.isInteger(r.level)||r.level<0||r.level>15)throw Error('主属性或等级不符合游戏规则');
  const actual=main.base+main.increment*r.level,display=s=>['HP','ATK','DEF','SPD'].includes(s)?Math.floor(actual+1e-5):Math.floor(actual*10+1e-5)/10;
  if(!Number.isFinite(r.mainstat_value)||Math.abs(r.mainstat_value-display(r.mainstat))>.011)throw Error('主属性数值与强化等级不一致');
  U.validateRollBudget(r);
  const variants=['low','high'].map(bound=>({...r,_uid:request.relicId,mainstat_value:actual,substats:r.substats.map(s=>({...s,value:U.possibleValues(s.key,s.value,r.level)[bound]})),preview_substats:(r.preview_substats||[]).map(s=>({...s,value:U.possibleValues(s.key,s.value,0)[bound]}))}));
  const imported=E.parse({source:'当前游戏画面',relics:[variants[1]],characters:request.characters||[]});
  const cfg=E.cleanupSettings(settings);if(cfg.scope==='owned'&&!imported.owned.length)throw Error('现场读取没有角色持有信息，请选择全部已收录五星。');
  const upper=await E.analyze(imported,cfg),lower=await E.analyze(E.parse({...imported.root,relics:[variants[0]]}),cfg),row=upper.rows[0];
  if(!row?.scores.length||row.scoringIssues.length)throw Error('当前属性未通过评分校验');
  const metric=r.level===15?'current':'average',value=row.best[metric];
  const answer={requestId:request.requestId,action:row.status==='discard'?'markDiscard':row.status==='review'?'skip':'keep',verified:true,averagePotential:row.best.average,currentScore:row.best.current,averageLower:lower.rows[0]?.best?.average,currentLower:lower.rows[0]?.best?.current,observation:r,raw:variants[1],row:{...row,scoreBounds:{lower:lower.rows[0]?.best,upper:row.best}},reason:row.reasons.join('；'),equippedLow:!!r.location&&r.location!=='live-protected-footer'&&value<80};
  answer.unlockFirst=r.lock===true&&answer.action==='markDiscard';
  if(answer.unlockFirst)answer.reason=(r.level===15?'当前分':'平均满级潜力')+'低于 80，解锁后标记弃置';
  if(typeof r.lock!=='boolean')answer.reason='锁定状态不明，跳过';else if(r.location!=='')answer.reason=answer.equippedLow?'已装备的低分遗器，已保护，请单独复核':'已装备或装备状态不明，跳过';else if(r.discard!==false)answer.reason='已弃置或状态不明，跳过';
  if(typeof r.lock!=='boolean'||r.location!==''||r.discard!==false){answer.action='skip';answer.unlockFirst=false;}
  if(request.upgrade===true&&answer.action==='keep'&&r.level<15){
   if(lower.rows[0]?.best?.average>=80){answer.action='enhance';answer.unlockFirst=r.lock===true;answer.targetLevel=Math.min(15,(Math.floor(r.level/3)+1)*3);answer.reason=(answer.unlockFirst?'平均满级潜力达到 80，解锁后强化至 +':'平均满级潜力达到 80，强化至 +')+answer.targetLevel;}
   else{answer.action='skip';answer.reason='隐藏小数导致评分跨过 80，保留并跳过';}
  }
  return answer;
 }
 return{score};
})();
