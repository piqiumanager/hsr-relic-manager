/* Relic decisions and import adapters. Runs entirely on the local computer. */
globalThis.RelicEngine = (() => {
  'use strict';
  const C=HSRCore,D=HSRData;
  const PARTS={Head:'头部',Hands:'手部',Body:'躯干',Feet:'脚部',PlanarSphere:'位面球',LinkRope:'连结绳'};
  const STAT_ZH={'HP':'生命值','HP%':'生命值%','ATK':'攻击力','ATK%':'攻击力%','DEF':'防御力','DEF%':'防御力%','SPD':'速度','CRIT Rate':'暴击率','CRIT DMG':'暴击伤害','Effect Hit Rate':'效果命中','Effect RES':'效果抵抗','Break Effect':'击破特攻','Energy Regeneration Rate':'能量恢复效率','Outgoing Healing Boost':'治疗量加成','Physical DMG Boost':'物理伤害','Fire DMG Boost':'火伤害','Ice DMG Boost':'冰伤害','Lightning DMG Boost':'雷伤害','Wind DMG Boost':'风伤害','Quantum DMG Boost':'量子伤害','Imaginary DMG Boost':'虚数伤害'};
  const PRESETS={
    extreme:{label:'极高分',current:75,average:70,best:85},
    strict:{label:'高分',current:65,average:60,best:80},
    custom:{label:'自定义',current:75,average:70,best:85},
  };
  const DEFAULTS={preset:'extreme',current:75,average:70,best:85,scope:'all',selected:[],protectLocked:true,protectEquipped:true,considerReroll:false,keepSpeed:0,keepRare:false,reserve:0,overrides:{}};
  const aliases={'HP_':'HP%','ATK_':'ATK%','DEF_':'DEF%','CRIT Rate_':'CRIT Rate','CRIT DMG_':'CRIT DMG','Effect Hit Rate_':'Effect Hit Rate','Effect RES_':'Effect RES','Break Effect_':'Break Effect','Physical DMG Boost_':'Physical DMG Boost','Fire DMG Boost_':'Fire DMG Boost','Ice DMG Boost_':'Ice DMG Boost','Lightning DMG Boost_':'Lightning DMG Boost','Wind DMG Boost_':'Wind DMG Boost','Quantum DMG Boost_':'Quantum DMG Boost','Imaginary DMG Boost_':'Imaginary DMG Boost','Energy Regeneration Rate_':'Energy Regeneration Rate','Outgoing Healing Boost_':'Outgoing Healing Boost'};
  for(const [k,v]of Object.entries(STAT_ZH))aliases[v]=k;
  const stat=s=>aliases[String(s)]||String(s??'');
  const number=v=>v!==''&&v!==null&&v!==undefined&&Number.isFinite(Number(v))?Number(v):NaN;
  const flag=v=>typeof v==='boolean'?v:null;
  const list=x=>Array.isArray(x)?x:x&&typeof x==='object'?Object.values(x):[];
  function part(s){const text=String(s??'').replace(/\s+/g,'');return Object.keys(PARTS).find(k=>k===text||PARTS[k]===text)||({Sphere:'PlanarSphere',Rope:'LinkRope',head:'Head',hands:'Hands',body:'Body',feet:'Feet',planar_sphere:'PlanarSphere',link_rope:'LinkRope'})[text];}
  function normalize(raw,index){
    const issues=[];const grade=number(raw.rarity??raw.grade);const enhance=number(raw.level??raw.enhance);
    const p=part(raw.slot??raw.part);const setRaw=String(raw.set_id??raw.set??'');
    const set=D.sets[setRaw]||Object.values(D.sets).find(x=>x.en===setRaw||x.name===setRaw);
    let mainStat=stat(raw.mainstat??raw.main?.stat??raw.main_stat);
    // Scanner/Reliquary use HP/ATK/DEF for percentage mains outside head/hands.
    // Slot rules disambiguate these names; substat names must remain unchanged.
    if(['Body','Feet','PlanarSphere','LinkRope'].includes(p)&&['HP','ATK','DEF'].includes(mainStat))mainStat+='%';
    const toSubs=(arr)=>list(arr).map(s=>({stat:stat(s.key??s.stat),value:number(s.value),addedRolls:number(s.addedRolls??s.added_rolls??(Number.isInteger(s.count)?s.count-1:undefined))||0,rollsKnown:Number.isInteger(s.count)||Number.isFinite(s.addedRolls)||Number.isFinite(s.added_rolls)}));
    const subs=toSubs(raw.substats),preview=toSubs(raw.preview_substats??raw.previewSubstats??[]);
    if(!p)issues.push('无法识别部位');
    if(!set)issues.push('套装未收录');
    if(!Number.isInteger(enhance)||enhance<0||enhance>15)issues.push('强化等级不完整');
    if(!C.PartsMainStats[p]?.includes(mainStat))issues.push('主属性与部位不匹配');
    if(subs.length<3||subs.length>4||subs.length+preview.length>4)issues.push('副属性数量不完整');
    if(enhance>=3&&subs.length!==4)issues.push('已强化遗器缺少已生效副属性');
    const all=[...subs,...preview];
    if(all.some(s=>!C.SubStats.includes(s.stat)||!Number.isFinite(s.value)||s.value<=0))issues.push('副属性值无法识别');
    if(new Set(all.map(s=>s.stat)).size!==all.length||all.some(s=>s.stat===mainStat))issues.push('主副属性有重复');
    const ownerRaw=Object.hasOwn(raw,'location')?raw.location:raw.equippedBy;
    const owner=ownerRaw===undefined||ownerRaw===null?null:String(ownerRaw||'');
    const locked=flag(raw.lock??raw.locked),discarded=flag(raw.discard??raw.discarded);
    if(locked===null)issues.push('锁定状态未知');
    if(owner===null)issues.push('装备状态未知');
    for(const s of all)if(Number.isFinite(s.value)&&C.SubStatValues[s.stat]){
      if(s.value>C.SubStatValues[s.stat][5].high*(1+Math.floor(enhance/3))+0.25)issues.push('副属性数值超过当前等级上限');
    }
    const mainValue=number(raw.main?.value??raw.mainstat_value);
    const calculatedMain=C.MainStatsValues?.[mainStat]?.[5];
    const protectionIssues=issues.filter(s=>['锁定状态未知','装备状态未知','遗器 ID 重复'].includes(s));
    const scoringIssues=issues.filter(s=>!protectionIssues.includes(s));
    return {id:String(raw._uid??raw.id??`row-${index+1}`),index,grade,enhance,part:p||'Unknown',setId:set?.id||setRaw,set:set?.en||setRaw,setName:set?.name||setRaw||'未知套装',main:{stat:mainStat,value:Number.isFinite(mainValue)?mainValue:calculatedMain?calculatedMain.base+calculatedMain.increment*enhance:null},substats:subs,previewSubstats:preview,locked,discarded,owner,issues:[...new Set(issues)],scoringIssues,raw};
  }
  function parse(input){
    let root=typeof input==='string'?JSON.parse(input.replace(/^\uFEFF/,'')):input;
    if(!root||typeof root!=='object'||Array.isArray(root))throw Error('请选择 Reliquary、HSR Scanner 或 Fribbels 导出的完整 JSON 文件。');
    if(root.schema==='hsr-relic-session-v1')return {session:root};
    if(!root.relics&&root.data?.relics)root=root.data;
    if(!root.relics||typeof root.relics!=='object')throw Error('文件中没有背包遗器列表。仅输入 UID 或角色展示柜数据不足以筛选整个背包。');
    const source=list(root.relics);if(source.length>15000)throw Error('遗器数量异常，文件未导入。');
    const ignored=source.filter(x=>number(x?.rarity??x?.grade)!==5).length;
    const relics=source.map((x,i)=>x&&typeof x==='object'?normalize(x,i):null).filter(r=>r?.grade===5);
    const count=new Map();for(const r of relics)count.set(r.id,(count.get(r.id)||0)+1);
    for(const r of relics)if(count.get(r.id)>1)r.issues.push('遗器 ID 重复');
    const owned=list(root.characters).map(c=>{const id=String(c.id??c.form?.characterId??c.characterId??'');return D.profiles[id+'b1']&&(c.ability_version==null||Number(c.ability_version)>0)?id+'b1':id;}).filter(Boolean);
    const rosterUnknown=owned.filter(id=>!D.charNames[id]);
    return {root,relics,owned,rosterUnknown,ignored,source:String(root.source||'Fribbels / JSON'),uid:String(root.metadata?.uid??''),isDemo:root.demo===true||root.metadata?.demo===true||String(root.source||'').includes('示例背包')};
  }
  function metadata(profile,override={}){
    const stats={...profile.stats,...override.stats};
    for(const s of C.SubStats)stats[s]=Math.max(0,Math.min(1,number(stats[s])||0));
    C.applyFlatStatScaling(stats);
    const sortedSubstats=Object.entries(stats).filter(([s])=>C.SubStats.includes(s)).sort((a,b)=>b[1]-a[1]);
    const contributions={},highRollPotential={},midRollPotential={},lowRollPotential={};
    for(const [s,w] of sortedSubstats){const c=w*C.substatPotentialScale(s);contributions[s]=c;highRollPotential[s]=c*C.SubStatValues[s][5].high;midRollPotential[s]=c*C.SubStatValues[s][5].mid;lowRollPotential[s]=c*C.SubStatValues[s][5].low;}
    return {stats,parts:{...profile.parts,...override.parts},sortedSubstats,contributions,highRollPotential,midRollPotential,lowRollPotential,flatMainstatBoost:profile.flatMainstatBoost};
  }
  function evaluate(relic,profile,meta){
    if(!relic.part||!C.PartsMainStats[relic.part])return null;
    const ideal=C.computeOptimalScore(relic.part,relic.main.stat,meta);
    if(!Number.isFinite(ideal)||ideal<=0)return null;
    const score=C.computeFutureScores({...relic,grade:5},meta,ideal,false);
    if(![score.current,score.average,score.best].every(Number.isFinite))return null;
    return {id:profile.id,name:profile.name,current:score.current,average:score.average,best:score.best,worst:score.worst,reroll:score.rerollAvg,setRecommended:profile.sets.includes(relic.set),mainRecommended:meta.parts[relic.part]?.includes(relic.main.stat)||false};
  }
  function targets(imported,settings){
    let ids=Object.keys(D.profiles).filter(id=>!D.profiles[id+'b1']);
    if(settings.scope==='owned')ids=imported.owned.filter(id=>D.profiles[id]);
    if(settings.scope==='selected')ids=settings.selected.filter(id=>D.profiles[id]);
    return [...new Set(ids)].map(id=>D.profiles[id]);
  }
  function settingsValid(s){
    const c={...DEFAULTS,...s};
    for(const k of ['current','average','best'])if(!Number.isFinite(number(c[k]))||number(c[k])<0||number(c[k])>100)throw Error('评分门槛必须在 0–100 之间。');
    for(const k of ['current','average','best','reserve','keepSpeed'])c[k]=number(c[k]);
    return c;
  }
  async function analyze(imported,settings,onProgress=()=>{}){
    const cfg=settingsValid(settings),profiles=targets(imported,cfg);
    if(!profiles.length)throw Error(cfg.scope==='owned'?'导出文件中没有可评估的已拥有五星角色，请选择“全部五星”或手动选择角色。':'请至少选择一位五星角色。');
    const metas=profiles.map(p=>metadata(p,cfg.overrides?.[p.id]));
    const missing=cfg.scope==='all'?imported.rosterUnknown:cfg.scope==='owned'?imported.owned.filter(id=>D.charNames[id]?.rarity===5&&!D.profiles[id]):[];
    const rows=[];
    for(let i=0;i<imported.relics.length;i++){
      const r=imported.relics[i];let scores=[];
      if(!(r.scoringIssues??r.issues).length)for(let j=0;j<profiles.length;j++){const v=evaluate(r,profiles[j],metas[j]);if(v)scores.push(v);}
      const rank=s=>r.enhance===15?s.current:s.average;
      scores.sort((a,b)=>rank(b)-rank(a)||b.best-a.best);
      let best=scores[0]||null;
      const qualifies=scores.filter(s=>r.enhance===15?s.current>=cfg.current:s.average>=cfg.average&&s.best>=cfg.best);
      if(qualifies.length)best=qualifies[0];
      let status='discard',reasons=[];
      if(r.issues.length){status='review';reasons.push(...r.issues);}
      else if(!scores.length){status='review';reasons.push('所选角色没有可用的评分权重');}
      else if(qualifies.length){status=r.enhance===15?'keep':'upgrade';const q=qualifies[0];reasons.push(`${q.name}：${r.enhance===15?'当前 '+q.current.toFixed(1):'平均潜力 '+q.average.toFixed(1)+'，上限 '+q.best.toFixed(1)}`);}
      else {reasons.push(r.enhance===15?`所有目标五星角色当前评分均低于 ${cfg.current}`:`没有目标五星角色同时达到平均 ${cfg.average}、上限 ${cfg.best}`);}
      if(status==='discard'&&cfg.considerReroll&&r.enhance===15&&!r.substats.every(s=>s.rollsKnown)){status='review';reasons.push('缺少强化次数，无法准确计算重掷潜力');}
      if(status==='discard'&&cfg.considerReroll&&scores.some(s=>s.reroll>=cfg.average)){status='review';reasons.push('重掷潜力较高，单独复核');}
      if(status==='discard'&&cfg.keepSpeed>0&&r.substats.some(s=>s.stat==='SPD'&&s.value>=cfg.keepSpeed)){status='review';reasons.push('触发速度词条保护');}
      if(status==='discard'&&cfg.keepRare&&((r.part==='Feet'&&r.main.stat==='SPD')||(r.part==='LinkRope'&&r.main.stat==='Energy Regeneration Rate')||(r.part==='Body'&&r.main.stat==='Outgoing Healing Boost'))){status='review';reasons.push('触发稀有主属性保护');}
      if(status==='discard'&&missing.length){status='review';reasons.push('账号中有未收录的五星角色，暂缓清理');}
      if(status==='discard'&&cfg.protectEquipped&&r.owner){status='review';reasons.push('低分但已装备，待你复核');}
      if(status==='discard'&&cfg.protectLocked&&r.locked){status='review';reasons.push('低分但已锁定，待你复核');}
      rows.push({...r,status,reasons,best,scores,qualifies:qualifies.map(s=>s.id),manual:null});
      if(i%45===0){onProgress(i/imported.relics.length);await new Promise(resolve=>setTimeout(resolve,0));}
    }
    if(cfg.reserve>0){
      const buckets=new Map();for(const row of rows)for(const s of row.scores){const k=[s.id,row.part,row.setId,row.main.stat].join('|');if(!buckets.has(k))buckets.set(k,[]);buckets.get(k).push({row,score:row.enhance===15?s.current:s.average});}
      for(const bucket of buckets.values()){bucket.sort((a,b)=>b.score-a.score);for(const {row}of bucket.slice(0,cfg.reserve))if(row.status==='discard'){row.status='review';row.reasons.push('触发自定义每组保留数量');}}
    }
    const diagnostics={total:rows.length,scored:rows.filter(r=>r.scores.length).length,unscored:rows.filter(r=>!r.scores.length).length,protected:rows.filter(r=>r.status==='review'&&r.scores.length).length,issues:{}};
    for(const r of rows.filter(r=>!r.scores.length))for(const issue of r.reasons)diagnostics.issues[issue]=(diagnostics.issues[issue]||0)+1;
    onProgress(1);return{rows,profileCount:profiles.length,missing,settings:cfg,diagnostics,at:new Date().toISOString()};
  }
  const status=r=>r.manual||r.status;
  function exportResults(result,imported){
    return {schema:'hsr-relic-decisions-v1',createdAt:result.at,source:imported.source,demo:!!imported.isDemo,settings:result.settings,targetCount:result.profileCount,sourceSnapshot:imported.relics.map(r=>({id:r.id,index:r.index,setId:r.setId,part:r.part,enhance:r.enhance,main:r.main,substats:r.substats})),relics:result.rows.map(r=>({id:r.id,index:r.index,setId:r.setId,setName:r.setName,part:r.part,enhance:r.enhance,main:r.main,substats:r.substats,decision:status(r),automaticDecision:r.status,reason:r.reasons,best:r.best,owner:r.owner,locked:r.locked})),gameChangesApplied:false};
  }
  function demo(){
    let state=1907;const random=()=>{state=(state*1664525+1013904223)>>>0;return state/4294967296;};
    const relics=[];const ps=Object.values(D.profiles).filter(p=>['1308','1309','1310','1303','1407','1401','1301','1313'].includes(p.id));
    for(let i=0;i<112;i++){
      const p=ps[i%ps.length]||Object.values(D.profiles)[0],pt=Object.keys(PARTS)[i%6];
      const main=p.parts[pt][0];const good=C.SubStats.filter(s=>(p.stats[s]||0)>0&&s!==main).sort((a,b)=>p.stats[b]-p.stats[a]);
      const bad=C.SubStats.filter(s=>(p.stats[s]||0)===0&&s!==main);
      const quality=i%4;let chosen=quality===0?[...good,...bad]:quality===1?[good[0],good[1],...bad,...good]:[...bad,...good];
      chosen=[...new Set(chosen.filter(Boolean))].slice(0,4);
      const level=[0,3,6,9,12,15][Math.floor(random()*6)];if(level===0&&i%2)chosen=chosen.slice(0,3);
      const values=chosen.map(s=>({key:s,value:C.SubStatValues[s][5].high}));
      for(let u=0;u<Math.floor(level/3)-(chosen.length===3?1:0);u++){let j=quality===0?Math.floor(random()*Math.min(2,values.length)):Math.floor(random()*values.length);values[j].value+=C.SubStatValues[values[j].key][5].high;}
      const set=Object.values(D.sets).find(x=>p.sets.includes(x.en)&&((pt==='PlanarSphere'||pt==='LinkRope')===String(x.id).startsWith('3')))||D.sets['102'];
      relics.push({_uid:'demo-'+(i+1),set_id:set.id,slot:pt,rarity:5,level,mainstat:main,substats:values,lock:i%17===0,location:i%19===0?p.id:'',discard:false});
    }
    const imported=parse({source:'示例背包（非你的账号）',version:4,characters:ps.map(p=>({id:p.id})),relics});imported.isDemo=true;return imported;
  }
  function displayNumber(s,v){return ['HP','ATK','DEF','SPD'].includes(s)?Math.floor(v+1e-5):Math.floor(v*10+1e-5)/10;}
  function markerFingerprint(r){
    if(!r.part||!r.main||!Array.isArray(r.substats))return null;
    const subs=[...r.substats,...(r.previewSubstats||[])].map(s=>[s.stat,displayNumber(s.stat,s.value)]).sort((a,b)=>a[0].localeCompare(b[0]));
    return JSON.stringify([r.setId,r.part,r.enhance,r.main.stat,subs]);
  }
  function buildMarkPlan(result,imported){
    if(!result||!imported)throw Error('请先读取背包并完成筛选。');
    if(imported.isDemo)throw Error('示例背包不能用于游戏内标记。');
    if(!imported.captureId)throw Error('自动标记需要先用“一键读取背包”取得本次新快照。已有 JSON 仍可离线筛选。');
    const grouped=new Map();
    for(const r of result.rows){const key=markerFingerprint(r);if(!grouped.has(key))grouped.set(key,[]);grouped.get(key).push(r);}
    // Include lower-star and otherwise skipped raw records to reject visual collisions.
    const otherKeys=new Set(list(imported.root.relics).filter(raw=>number(raw?.rarity??raw?.grade)!==5).filter(raw=>raw&&typeof raw==='object').map((raw,i)=>markerFingerprint(normalize(raw,i))));
    const candidates=[],skips={protected:0,alreadyDiscarded:0,unknownState:0,ambiguous:0,missingName:0};
    for(const [key,group]of grouped){
      const wanted=group.filter(r=>status(r)==='discard'&&r.status==='discard'&&!r.manual);
      if(!wanted.length)continue;
      const r=wanted[0];
      if(otherKeys.has(key)||group.some(x=>status(x)!=='discard'||x.status!=='discard'||x.manual||x.issues.length||x.locked!==false||x.owner!=='')){skips.protected+=wanted.length;continue;}
      if(group.some(x=>x.discarded===null)){skips.unknownState+=wanted.length;continue;}
      const unmarked=group.filter(x=>x.discarded===false);skips.alreadyDiscarded+=group.length-unmarked.length;
      if(!unmarked.length)continue;
      const pieceName=D.pieceNames?.[r.setId]?.[r.part];if(!pieceName){skips.missingName+=unmarked.length;continue;}
      candidates.push({key,ids:unmarked.map(x=>x.id),count:unmarked.length,setId:r.setId,setName:r.setName,pieceName,part:r.part,enhance:r.enhance,main:r.main,substats:r.substats,visualSubstats:[...r.substats,...r.previewSubstats]});
    }
    if(!candidates.length)throw Error('没有可自动标记的候选：已锁定、已装备、状态不明或已弃置的遗器不会再次点击。');
    return {schema:'hsr-marker-plan-v1',captureId:imported.captureId,createdAt:new Date().toISOString(),candidates,inventoryCount:list(imported.root.relics).length,total:candidates.reduce((n,x)=>n+x.count,0),skips,allowSalvage:false};
  }
  return{PARTS,STAT_ZH,PRESETS,DEFAULTS,parse,analyze,evaluate,metadata,targets,status,exportResults,demo,settingsValid,markerFingerprint,buildMarkPlan};
})();
