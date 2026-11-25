/* +3 enhancement orchestration. The live game adapter is intentionally not enabled
   until its target-level and material controls can be verified in a real client. */
globalThis.UpgradeFlow=(()=>{
 'use strict';
 const POLICY=Object.freeze({step:3,threshold:80,maxLevel:15,maxRelicMaterialRarity:4,allowExperience:true,allowLockedMaterials:false,allowEquippedMaterials:false,allowSalvage:false});
 function decision(relic,scores,{initialTrial=false}={}){
  if(relic.grade!==5||relic.locked!==false||relic.owner!==''||relic.discarded!==false||relic.issues?.length)return{action:'skip',reason:'遗器受保护或数据不完整'};
  if(!Number.isInteger(relic.enhance)||relic.enhance<0||relic.enhance>15)throw Error('强化等级无效');
  const key=relic.enhance===15?'current':'average';const valid=scores.filter(s=>Number.isFinite(s[key]));if(!valid.length)return{action:'stop',reason:'无法重新评分'};
  const best=[...valid].sort((a,b)=>b[key]-a[key])[0];
  if(!(initialTrial&&relic.enhance===0)&&best[key]<POLICY.threshold)return{action:'markDiscard',score:best[key],character:best.id};
  return relic.enhance===15?{action:'keep',score:best.current,character:best.id}:{action:'enhance',targetLevel:Math.min(15,relic.enhance+3),score:best[key],character:best.id};
 }
 function verifyPreparation(prepared,target){
  if(!prepared||prepared.targetLevel!==target||prepared.materialsVerified!==true||!Array.isArray(prepared.materials)||!prepared.materials.length)throw Error('强化目标或材料未核实');
  for(const m of prepared.materials){if(m.kind==='experience'){if(!(m.quantity>0))throw Error('经验材料数量无效');continue;}if(m.kind!=='relic'||!Number.isInteger(m.rarity)||m.rarity<2||m.rarity>4||m.locked!==false||m.equipped!==false)throw Error('不允许消耗此强化材料');}
 }
 function verifyAdvance(before,after,target){
  if(before.id!==after.id||before.setId!==after.setId||before.part!==after.part||before.main.stat!==after.main.stat||after.grade!==5||after.enhance!==target)throw Error('强化结果或遗器身份不一致');
  for(const old of before.substats){const s=after.substats.find(s=>s.stat===old.stat);if(!s||s.value+0.0001<old.value)throw Error('强化后词条异常');}
 }
 async function run(adapter,{cancelled=()=>false,initialTrial=true}={}){
  if(!adapter||!['readSelected','score','prepare','confirm','markDiscard'].every(k=>typeof adapter[k]==='function'))throw Error('需要已验证的游戏执行器');
  let relic=await adapter.readSelected();const history=[];
  for(let n=0;n<6;n++){
   if(cancelled())return{action:'stopped',history};
   const d=decision(relic,await adapter.score(relic),{initialTrial:initialTrial&&n===0});history.push({level:relic.enhance,...d});
   if(d.action==='markDiscard'){if(cancelled())return{action:'stopped',history};await adapter.markDiscard(relic);return{action:'markedDiscard',history,allowSalvage:false};}
   if(d.action!=='enhance')return{...d,history};
   const prepared=await adapter.prepare(relic,d.targetLevel,POLICY);verifyPreparation(prepared,d.targetLevel);
   if(cancelled())return{action:'stopped',history};
   await adapter.confirm(prepared);const after=await adapter.readSelected();verifyAdvance(relic,after,d.targetLevel);relic=after;
  }
  throw Error('强化步骤超过五次，已停止');
 }
 return{POLICY,decision,verifyPreparation,verifyAdvance,run};
})();
