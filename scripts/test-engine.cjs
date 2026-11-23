require('node:process').chdir(require('node:path').resolve(__dirname,'..'));
require('node:fs').mkdirSync('work',{recursive:true});
const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const ctx={console,setTimeout,clearTimeout,structuredClone};vm.createContext(ctx);
ctx.HSRData=JSON.parse(fs.readFileSync('source/data.json','utf8'));
vm.runInContext(fs.readFileSync('source/fribbels-core.js','utf8'),ctx);
vm.runInContext(fs.readFileSync('source/engine.js','utf8'),ctx);
const E=ctx.RelicEngine,C=ctx.HSRCore,D=ctx.HSRData;
let checks=0;function check(condition,message){assert.ok(condition,message);checks++;}
function raw(overrides={}){return {_uid:'test-1',set_id:'117',slot:'Head',rarity:5,level:15,mainstat:'HP',substats:[{key:'CRIT Rate_',value:19.44},{key:'CRIT DMG_',value:6.48},{key:'ATK_',value:4.32},{key:'ATK',value:21.168754}],lock:false,location:'',discard:false,...overrides};}
const wrap=(r,characters=[{id:'1308'}])=>E.parse({source:'HSR-Scanner',version:4,characters,relics:r});
async function run(){
check(Object.keys(D.profiles).length>=75,'five-star profiles present');
check(!D.profiles['1001'],'four-star excluded');
check(D.profiles['8001']&&D.profiles['8002'],'both trailblazers supported');
check(wrap([raw({slot:'Planar Sphere',mainstat:'ATK_'})]).relics[0].part==='PlanarSphere','Reliquary spaced slot names supported');
check(wrap([],[{id:'1310',ability_version:1}]).owned.includes('1310b1'),'activated enhanced character mapped correctly');
check(wrap([],[{id:'1310',ability_version:0}]).owned.includes('1310'),'original ability version retained');
check(!E.targets(wrap([]),E.DEFAULTS).some(p=>D.profiles[p.id+'b1']),'default all-star scope uses current enhanced version');
const p=D.profiles['1308'],m=E.metadata(p),r=wrap([raw()]).relics[0];
check(r.issues.length===0,'valid scanner import');
let s=E.evaluate(r,p,m);check(Math.abs(s.current-100)<.001,'perfect relic scores 100');check(Math.abs(s.best-s.current)<.01&&Math.abs(s.average-s.current)<.01,'fully enhanced has no future rolls');
const starter=raw({level:0,substats:[{key:'CRIT Rate_',value:3.24},{key:'CRIT DMG_',value:6.48},{key:'ATK_',value:4.32},{key:'ATK',value:21.168754}]});
let sr=wrap([starter]).relics[0],future=E.evaluate(sr,p,m);check(future.best>future.average&&future.average>future.current,'future potential ordered');
let three=wrap([raw({level:0,substats:starter.substats.slice(0,3),preview_substats:[{key:'ATK',value:21.168754}]})]).relics[0];let ts=E.evaluate(three,p,m);check(ts.current<future.current,'unrevealed preview excluded from current');check(ts.best<future.best&&ts.best>ts.current,'three-line start spends one upgrade revealing the fourth line');
let result=await E.analyze(wrap([raw()]),{...E.DEFAULTS,scope:'selected',selected:['1308']});check(result.rows[0].status==='keep','high completed relic retained');
const bad=raw({substats:[{key:'DEF',value:126.9},{key:'DEF_',value:5.4},{key:'HP_',value:4.32},{key:'Effect RES_',value:4.32}]});
result=await E.analyze(wrap([bad]),{...E.DEFAULTS,scope:'selected',selected:['1308']});check(result.rows[0].status==='discard','low relic is cleanup candidate');
result=await E.analyze(wrap([{...bad,lock:true}]),{...E.DEFAULTS,scope:'selected',selected:['1308']});check(result.rows[0].status==='review','locked low relic protected but not high keep');
result=await E.analyze(wrap([{...bad,location:'1308'}]),{...E.DEFAULTS,scope:'selected',selected:['1308']});check(result.rows[0].status==='review','equipped low relic protected');
result=await E.analyze(wrap([{...bad,lock:true}]),{...E.DEFAULTS,scope:'selected',selected:['1308'],protectLocked:false});check(result.rows[0].status==='discard','lock protection user configurable');
const missing=raw();delete missing.lock;result=await E.analyze(wrap([missing]),E.DEFAULTS);check(result.rows[0].status==='review','unknown lock not assumed unlocked');
const unknown=raw({set_id:'9999'});result=await E.analyze(wrap([unknown]),E.DEFAULTS);check(result.rows[0].status==='review','unknown set protected');
const dup=wrap([raw(),raw()]);check(dup.relics.every(x=>x.issues.includes('遗器 ID 重复')),'duplicate IDs protected');
const invalid=wrap([raw({level:-1})]);check(invalid.relics[0].issues.length>0,'invalid level protected');
check(wrap([raw({rarity:4})]).relics.length===0,'only five-star relics processed');
const known=wrap([bad],[{id:'1001'},{id:'1308'}]);check(E.targets(known,{...E.DEFAULTS,scope:'owned'}).length===1,'owned roster excludes four-stars');
assert.throws(()=>E.settingsValid({...E.DEFAULTS,current:101}));checks++;
assert.throws(()=>E.parse({avatarInfoList:[]}));checks++;
const demo=E.demo();check(demo.isDemo&&demo.relics.length===112,'demo explicitly marked');
const dr=await E.analyze(demo,E.DEFAULTS);const count=dr.rows.reduce((a,r)=>(a[r.status]=(a[r.status]||0)+1,a),{});check(dr.rows.length===112,'demo completes all records');check(count.discard>0&&count.keep+count.upgrade>0,'demo exercises good and low tiers');
check(dr.rows.filter(r=>r.status==='upgrade').every(r=>r.best.average>=E.DEFAULTS.average&&r.best.best>=E.DEFAULTS.best),'displayed best character also satisfies both upgrade gates');
check(!dr.rows.some(r=>r.scores.some(s=>!Number.isFinite(s.best)||!Number.isFinite(s.average))),'all scores finite');
for(const profile of Object.values(D.profiles)){const score=E.evaluate(sr,profile,E.metadata(profile));check(score===null||Number.isFinite(score.best),'every bundled profile usable');}
const exportFile=E.exportResults(dr,demo);check(exportFile.gameChangesApplied===false&&exportFile.demo===true,'export cannot imply game changes');
const large=wrap(Array.from({length:3000},(_,i)=>({...starter,_uid:'load-'+i})));const start=performance.now();const big=await E.analyze(large,E.DEFAULTS);check(big.rows.length===3000,'full bag load test');
const report={checks,demoCounts:count,fullBagMs:Math.round(performance.now()-start),profiles:Object.keys(D.profiles).length};fs.writeFileSync('work/engine-test-report.json',JSON.stringify(report,null,2));console.log(JSON.stringify(report));
}
run().catch(e=>{console.error(e.stack);process.exitCode=1});
