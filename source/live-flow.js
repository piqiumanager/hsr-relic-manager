globalThis.LiveFlow=(()=>{
 'use strict';
 async function score(request,settings){
  const E=RelicEngine,C=HSRCore,U=UpgradeFlow,r=globalThis.NumericOcr?await NumericOcr.resolve(request.observation):request.observation;if(!r||r.rarity!==5)throw Error('未确认五星遗器');
  const main=C.MainStatsValues[r.mainstat]?.[5];if(!main||!C.PartsMainStats[r.slot]?.includes(r.mainstat)||!Number.isInteger(r.level)||r.level<0||r.level>15)throw Error('主属性或等级不符合游戏规则');
  const actual=main.base+main.increment*r.level,display=s=>['HP','ATK','DEF','SPD'].includes(s)?Math.floor(actual+1e-5):Math.floor(actual*10+1e-5)/10;
  if(Math.abs(r.mainstat_value-display(r.mainstat))>.011)throw Error('主属性数值与强化等级不一致');
  const variants=['low','high'].map(bound=>({...r,_uid:request.relicId,mainstat_value:actual,substats:r.substats.map(s=>({...s,value:U.possibleValues(s.key,s.value,r.level)[bound]})),preview_substats:(r.preview_substats||[]).map(s=>({...s,value:U.possibleValues(s.key,s.value,0)[bound]}))}));
  const imported=E.parse({source:'当前游戏画面',relics:[variants[1]],characters:request.characters||[]});
  const cfg=E.settingsValid(settings);if(cfg.scope==='owned'&&!imported.owned.length)throw Error('现场读取没有角色持有信息，请选择全部已收录五星。');
  const upper=await E.analyze(imported,cfg),lower=await E.analyze(E.parse({...imported.root,relics:[variants[0]]}),cfg),row=upper.rows[0];
  if(!row?.scores.length||row.scoringIssues.length)throw Error('当前属性未通过评分校验');
  const answer={requestId:request.requestId,action:row.status==='discard'?'markDiscard':row.status==='review'?'skip':'keep',verified:true,observation:r,raw:variants[1],row:{...row,scoreBounds:{lower:lower.rows[0]?.best,upper:row.best}}};
  if(r.lock!==false||r.location!==''||r.discard!==false)answer.action='skip';
  return answer;
 }
 return{score};
})();
