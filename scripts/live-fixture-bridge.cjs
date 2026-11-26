// Offline fixtures use the production scorer and real roll values. Never connects to the game.
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'..'),ctx={console,setTimeout,structuredClone};vm.createContext(ctx);
ctx.HSRData=JSON.parse(fs.readFileSync(path.join(root,'source/data.json'),'utf8'));
for(const f of ['fribbels-core.js','engine.js','upgrade-flow.js','live-flow.js'])vm.runInContext(fs.readFileSync(path.join(root,'source',f),'utf8'),ctx);
const E=ctx.RelicEngine,C=ctx.HSRCore,D=ctx.HSRData,display=(s,v)=>['HP','ATK','DEF','SPD'].includes(s)?Math.floor(v+1e-5):Math.floor(v*10+1e-5)/10;
function visible(r){const m=C.MainStatsValues[r.mainstat][5];if(!D.pieceNames[r.set_id]?.[r.slot])throw Error('Invalid synthetic set/part');return{...structuredClone(r),_uid:'offline-fixture',rarity:5,pieceName:D.pieceNames[r.set_id][r.slot],mainstat_value:display(r.mainstat,m.base+m.increment*r.level),substats:r.substats.map(s=>({key:s.key,value:display(s.key,s.value)})),preview_substats:(r.preview_substats||[]).map(s=>({key:s.key,value:display(s.key,s.value)})),lock:false,location:'',discard:false};}
const score=r=>ctx.LiveFlow.score({requestId:'fixture',relicId:'offline',observation:visible(r),upgrade:true},E.cleanupSettings());
async function sequence(seed,best){let r=structuredClone(seed);const seq=[visible(r)];for(let level=3;level<=15;level+=3){const options=[];for(let i=0;i<4;i++){const next=structuredClone(r);next.level=level;next.substats[i].value+=C.SubStatValues[next.substats[i].key][5][best?'high':'low'];const a=await score(next);options.push({raw:next,answer:a});}const k=level===15?'currentScore':'averagePotential';options.sort((a,b)=>(best?-1:1)*(a.answer[k]-b.answer[k]));r=options[0].raw;seq.push(visible(r));if(options[0].answer.action==='markDiscard')break;}return seq;}
(async()=>{
 if(process.argv[2]==='--generate'){
  const demo=E.demo().root.relics,seeds=demo.filter(r=>r.level===0&&r.substats.length===4&&D.pieceNames[r.set_id]?.[r.slot]),high=[],low=[];
  for(const r of seeds){if((await score(r)).action!=='enhance')continue;const good=await sequence(r,true);if(good.length===6&&(await score(good.at(-1))).action==='keep')high.push(good);const bad=await sequence(r,false);if((await score(bad.at(-1))).action==='markDiscard')low.push(bad);if(high.length&&low.length)break;}
  if(!high.length||!low.length)throw Error('Could not build valid enhancement sequences');
  const junk=visible({set_id:'117',slot:'Head',mainstat:'HP',level:12,substats:[{key:'ATK',value:55},{key:'SPD',value:6},{key:'CRIT DMG',value:5.1},{key:'DEF',value:16}]});
  if((await score(junk)).action!=='markDiscard')throw Error('Low fixture was not low');
  const lowByLevel={};for(const level of [0,3,6,9,12,15]){for(const raw of demo.filter(r=>r.level===level&&D.pieceNames[r.set_id]?.[r.slot])){if((await score(raw)).action==='markDiscard'){lowByLevel[level]=visible(raw);break;}}if(!lowByLevel[level])throw Error('No valid low-scoring fixture at +'+level);}
  const dir=path.join(root,'work');fs.mkdirSync(dir,{recursive:true});fs.writeFileSync(path.join(dir,'live-pipeline-fixtures.json'),JSON.stringify({junk,high:high[0],low:low[0],lowByLevel}));
  console.log(JSON.stringify({highLevels:high[0].map(r=>r.level),lowLevels:low[0].map(r=>r.level),synthetic:true}));
 }else{
  const request=JSON.parse(fs.readFileSync(process.argv[2],'utf8').replace(/^\uFEFF/,''));let answer;
  try{answer=await ctx.LiveFlow.score(request,E.cleanupSettings());}catch(e){answer={requestId:request.requestId,action:'skip',verified:false,raw:{_uid:request.relicId,rarity:0},reason:e.message};}
  fs.writeFileSync(process.argv[3],JSON.stringify(answer));
 }
})().catch(e=>{console.error(e);process.exit(1)});
