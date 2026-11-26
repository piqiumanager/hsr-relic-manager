/* +3 enhancement policy and live screen-observation scoring. */
globalThis.UpgradeFlow=(()=>{
 'use strict';
 const POLICY=Object.freeze({step:3,threshold:80,maxLevel:15,maxRelicMaterialRarity:4,allowExperience:true,allowLockedMaterials:false,allowEquippedMaterials:false,allowSalvage:false});
 function decision(relic,scores,{initialTrial=false}={}){
  if(relic.grade!==5||relic.locked!==false||relic.owner!==''||relic.discarded!==false||relic.issues?.length)return{action:'skip',reason:'遗器受保护或数据不完整'};
  if(!Number.isInteger(relic.enhance)||relic.enhance<0||relic.enhance>15)throw Error('强化等级无效');
  const key=relic.enhance===15?'current':'average';const valid=scores.filter(s=>Number.isFinite(s[key]));if(!valid.length)return{action:'stop',reason:'无法重新评分'};
  const best=[...valid].sort((a,b)=>b[key]-a[key])[0];
  if(best[key]<POLICY.threshold)return{action:'markDiscard',score:best[key],character:best.id};
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
 async function run(adapter,{cancelled=()=>false,initialTrial=false}={}){
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
 function buildPlan(result,imported){
  const E=RelicEngine,D=HSRData;
  if(!result||!imported?.captureId||imported.isDemo)throw Error('请重新读取背包后开始强化。');
  const groups=new Map();for(const r of result.rows){const key=E.markerFingerprint(r);if(!groups.has(key))groups.set(key,[]);groups.get(key).push(r);}
  const lower=new Set(Object.values(imported.root.relics).filter(r=>r&&typeof r==='object'&&Number(r.rarity??r.grade)!==5).map(r=>E.markerFingerprint(E.parse({relics:[{...r,rarity:5}]}).relics[0])));
  const candidates=[];
  for(const [key,rs]of groups){
   if(lower.has(key)||rs.some(r=>r.status!=='upgrade'||r.manual||r.issues.length||r.locked!==false||r.owner!==''||r.discarded!==false||r.enhance%3!==0||r.enhance>=15))continue;
   const r=rs[0],pieceName=D.pieceNames[r.setId]?.[r.part];if(!pieceName)continue;
   candidates.push({key,ids:rs.map(r=>r.id),count:rs.length,setId:r.setId,setName:r.setName,pieceName,part:r.part,enhance:r.enhance,main:r.main,substats:r.substats,visualSubstats:[...r.substats,...r.previewSubstats],initialScores:rs.map(r=>({id:r.id,average:Math.max(...r.scores.map(s=>s.average)),current:Math.max(...r.scores.map(s=>s.current))}))});
  }
  if(!candidates.length)throw Error('没有可强化的胚子。已锁定、已装备、已弃置和非 3 级节点的遗器会跳过。');
  return{schema:'hsr-marker-plan-v1',operation:'upgrade',captureId:imported.captureId,policy:POLICY,candidates,total:candidates.reduce((n,r)=>n+r.count,0),inventoryCount:Object.values(imported.root.relics).length,targetIds:E.targets(imported,result.settings).map(p=>p.id),settings:result.settings,allowSalvage:false};
 }
 function possibleValues(stat,visible,level){
  const E=RelicEngine,C=HSRCore,roll=C.SubStatValues[stat]?.[5];if(!roll)throw Error('无法识别强化词条');
  const display=v=>['HP','ATK','DEF','SPD'].includes(stat)?Math.floor(v+0.00001):Math.floor(v*10+0.00001)/10;
  const values=[];for(let n=1;n<=1+Math.floor(level/3);n++)for(let hi=0;hi<=n;hi++)for(let mid=0;mid<=n-hi;mid++){const value=hi*roll.high+mid*roll.mid+(n-hi-mid)*roll.low;if(Math.abs(display(value)-visible)<0.011)values.push(value);}
  if(!values.length)throw Error('强化词条数值不符合游戏档位');return{low:Math.min(...values),high:Math.max(...values)};
 }
 function scoreObservation(request,plan){
  const E=RelicEngine,D=HSRData,C=HSRCore,o=request.observation,c=plan.candidates.find(c=>c.key===request.candidateKey);
  if(!c||!c.ids.includes(request.relicId)||!o||o.setId!==c.setId||o.part!==c.part||o.main?.stat!==c.main.stat||o.locked!==false||o.owner!==''||o.discarded!==false||!Number.isInteger(o.enhance)||o.enhance<0||o.enhance>15||o.enhance%3!==0)throw Error('强化观察与目标遗器不一致');
  if(request.initial&&o.enhance!==c.enhance)throw Error('初始强化等级与快照不同');
  const main=C.MainStatsValues[o.main.stat]?.[5];const value=main?main.base+main.increment*o.enhance:NaN;const visible=['HP','ATK','DEF','SPD'].includes(o.main.stat)?Math.floor(value+0.00001):Math.floor(value*10+0.00001)/10;
  if(!Number.isFinite(o.main.value)||Math.abs(o.main.value-visible)>0.011)throw Error('强化后主属性数值与等级不一致');
  let lower,upper,character;
  if(request.initial&&o.enhance===0){const v=c.initialScores;lower=Math.min(...v.map(s=>s.average));upper=Math.max(...v.map(s=>s.average));}
  else{
   if(!Array.isArray(o.substats)||o.substats.length!==4||new Set(o.substats.map(s=>s.stat)).size!==4||o.substats.some(s=>s.stat===o.main.stat))throw Error('强化后四个副属性未完整识别');
   const ranges=o.substats.map(s=>possibleValues(s.stat,s.value,o.enhance));
   const variant=k=>E.parse({relics:[{_uid:request.relicId,set_id:o.setId,slot:o.part,rarity:5,level:o.enhance,mainstat:o.main.stat,substats:o.substats.map((s,i)=>({key:s.stat,value:ranges[i][k]})),lock:false,location:'',discard:false}]}).relics[0];
   const lo=variant('low'),hi=variant('high');if(lo.issues.length||hi.issues.length)throw Error('强化后遗器属性未通过校验');
   const scores=plan.targetIds.map(id=>{const p=D.profiles[id];if(!p)throw Error('强化角色权重缺失');const meta=E.metadata(p,plan.settings.overrides?.[id]);return{low:E.evaluate(lo,p,meta),high:E.evaluate(hi,p,meta)};});
   const key=o.enhance===15?'current':'average';lower=Math.max(...scores.map(s=>s.low?.[key]??-Infinity));upper=Math.max(...scores.map(s=>s.high?.[key]??-Infinity));character=scores.find(s=>s.low?.[key]===lower)?.low?.name;
  }
  if(!Number.isFinite(lower)||!Number.isFinite(upper))throw Error('强化后无法评分');
  const common={requestId:request.requestId,lower,upper,character,level:o.enhance};

  if(upper<80)return{...common,action:'markDiscard'};
  if(lower>=80)return{...common,action:o.enhance===15?'keep':'enhance',targetLevel:o.enhance===15?15:o.enhance+3};
  return{...common,action:'stop',reason:'画面隐藏小数导致评分跨过 80 分，已保留并停止。'};
 }
 return{POLICY,decision,verifyPreparation,verifyAdvance,run,buildPlan,possibleValues,scoreObservation};
})();
