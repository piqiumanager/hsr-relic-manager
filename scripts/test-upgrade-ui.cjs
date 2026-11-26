// Offline browser test. Every game-action API is intercepted.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require(process.env.HSR_PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(__dirname,'..'),origin=process.env.HSR_TEST_ORIGIN||'http://127.0.0.1:3255',fixtures=JSON.parse(fs.readFileSync(path.join(root,'work/live-pipeline-fixtures.json'),'utf8'));
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.HSR_CHROME?{executablePath:process.env.HSR_CHROME}:{})});
 try{
  const page=await browser.newPage({viewport:{width:1000,height:780}}),errors=[],starts=[],answers=[];page.on('pageerror',e=>errors.push(e.message));
  let active=false,index=0,queue=[],finalRaw;
  const request=(raw,n,intent)=>({requestId:String(n).padStart(32,'0'),relicId:'synthetic-upgrade',upgrade:true,intent,pass:1,observation:{...raw,_uid:'synthetic-upgrade'}});
  queue=[request(fixtures.high[0],1,'score'),...fixtures.high.slice(1).map((r,i)=>request(r,i+2,'upgrade-after'))];finalRaw=fixtures.high.at(-1);
  await page.route('**/api/**',async route=>{
   const p=new URL(route.request().url()).pathname,reply=json=>route.fulfill({json});
   if(p==='/api/appearance')return route.continue();if(p==='/api/capture/latest')return reply({state:'empty'});
   if(p==='/api/live/start'){starts.push(route.request().postDataJSON());active=true;index=0;return reply({kind:'live',state:'starting'});}
   if(p==='/api/marker/status')return reply(!active?{state:'idle'}:index<queue.length?{kind:'live',upgrade:true,state:'awaitingScore',request:queue[index],scanned:1,inventoryCount:1}:{kind:'live',upgrade:true,state:'complete',confirmedSteps:5,marked:0,message:'已核实强化至 +15'});
   if(p==='/api/live/decision'){answers.push(route.request().postDataJSON());index++;return reply({state:'accepted'});}
   if(p==='/api/live/snapshot')return reply({state:'partial',data:{source:'synthetic',relics:[{...finalRaw,_uid:'synthetic-upgrade'}],metadata:{partial:true,screenRead:true}}});
   if(route.request().method()==='POST')throw Error('Unmocked game action: '+p);return route.continue();
  });
  await page.goto(origin);await page.waitForFunction(()=>!!globalThis.RelicDesk);await page.locator('#upgradeModeBtn').click();assert.equal(await page.locator('#markBtn').innerText(),'开始强化');assert.equal(await page.locator('#markBtn').isEnabled(),true);assert.equal(await page.evaluate(()=>RelicDesk.imported),null);
  await page.locator('#markBtn').click();await page.waitForFunction(()=>document.getElementById('phase').textContent==='已完成'&&!document.getElementById('markBtn').disabled);
  assert.equal(starts.length,1);assert.equal(starts[0].upgrade,true);assert.equal(starts[0].previewOnly,false);assert.equal(starts[0].plan,undefined);
  assert.deepEqual(answers.map(a=>a.action),['enhance','enhance','enhance','enhance','enhance','keep']);assert.deepEqual(answers.slice(0,-1).map(a=>a.targetLevel),[3,6,9,12,15]);assert.ok(answers.every(a=>a.observation&&a.raw&&a.row&&Number.isFinite(a.currentScore)));
  assert.equal(await page.evaluate(()=>RelicDesk.result.rows.length),1);assert.equal(await page.evaluate(()=>RelicDesk.result.rows[0].enhance),15);await page.locator('#detailsBtn').click();assert.equal(await page.locator('#detailRows tr').count(),1);assert.match(await page.locator('#detailRows').innerText(),/\+15/);await page.locator('#closeDialog').click();
  const equipped={...fixtures.junk,level:15,mainstat_value:705,location:'equipped',lock:true};queue=[request(equipped,20,'score')];finalRaw=equipped;
  await page.locator('#markBtn').click();await page.waitForFunction(()=>document.getElementById('phase').textContent==='已完成'&&!document.getElementById('markBtn').disabled);
  assert.equal(answers.at(-1).action,'skip');assert.equal(answers.at(-1).equippedLow,true);assert.equal(await page.locator('#equippedWarningBtn').isVisible(),true);await page.locator('#equippedWarningBtn').click();assert.equal(await page.locator('#dialogTitle').innerText(),'已装备的低分遗器');await page.locator('#closeDialog').click();
  for(const viewport of [{width:780,height:620},{width:390,height:844}]){await page.setViewportSize(viewport);assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);assert.equal(await page.locator('#stopBtn').evaluate(el=>el.getBoundingClientRect().bottom<=innerHeight),true);}
  assert.deepEqual(errors,[]);console.log('Direct enhancement UI passed: no capture prerequisite, +3 rescore until +15, one row per relic, equipped warning and responsive layout. Game input: 0.');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
