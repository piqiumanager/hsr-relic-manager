// Optional integration check: start server.ps1 with a separate empty DataRoot first.
// Requires Playwright (HSR_PLAYWRIGHT_MODULE may point to its installed package).
// Every capture and game-action endpoint is mocked; no game worker can be started.
const fs=require('node:fs'),path=require('node:path'),assert=require('node:assert/strict');
const {chromium}=require(process.env.HSR_PLAYWRIGHT_MODULE||'playwright');
const root=path.resolve(__dirname,'..'),origin=process.env.HSR_TEST_ORIGIN||'http://127.0.0.1:3244';
const snapshot=JSON.parse(fs.readFileSync(path.join(root,'work/upgrade-snapshot-fixture.json'),'utf8'));
const first=JSON.parse(fs.readFileSync(path.join(root,'work/upgrade-request-fixture.json'),'utf8'));
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.HSR_CHROME?{executablePath:process.env.HSR_CHROME}:{})});
 try{
  const page=await browser.newPage({viewport:{width:1000,height:780}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
  await page.addInitScript(()=>{Math.random=()=>.999999;});
  let active=false,answers=[],startBody,request=first,complete=false;
  await page.route('**/api/**',async route=>{
   const p=new URL(route.request().url()).pathname,body=()=>route.request().postDataJSON(),reply=v=>route.fulfill({json:v});
   if(p==='/api/capture/latest')return reply({});
   if(p==='/api/capture/start')return reply({state:'starting'});
   if(p==='/api/capture/status')return reply({state:'complete',captureId:'synthetic-capture',data:snapshot});
   if(p==='/api/marker/status')return reply(!active?{state:'idle'}:complete?{kind:'upgrade',state:'complete',preview:false,confirmedSteps:1,marked:0,message:'强化完成'}:{kind:'upgrade',state:'awaitingScore',request,preview:false,confirmedSteps:answers.length?1:0,message:'核验评分'});
   if(p==='/api/upgrade/start'){startBody=body();active=true;return reply({kind:'upgrade',state:'starting'});}
   if(p==='/api/upgrade/decision'){
    answers.push(body());
    if(answers.length===1){request=await page.evaluate(first=>{const c=RelicDesk.result.rows[0],C=HSRCore,m=C.MainStatsValues[c.main.stat][5],display=(s,v)=>['HP','ATK','DEF','SPD'].includes(s)?Math.floor(v+1e-5):Math.floor(v*10+1e-5)/10;return{...first,requestId:'22222222222222222222222222222222',initial:false,observation:{...first.observation,enhance:3,main:{stat:c.main.stat,value:display(c.main.stat,m.base+m.increment*3)},substats:[...c.substats,...c.previewSubstats].map((s,i)=>({stat:s.stat,value:display(s.stat,s.value+(i===0?C.SubStatValues[s.stat][5].high:0))}))}};},first);}else complete=true;
    return reply({state:'accepted'});
   }
   if(p==='/api/marker/start'||p==='/api/marker/calibrate')throw Error('Unexpected game action');
   return route.continue();
  });
  await page.goto(origin);await page.waitForFunction(()=>!!globalThis.RelicDesk);
  assert.equal(await page.locator('html').getAttribute('lang'),'zh-CN');
  await page.waitForFunction(()=>document.getElementById('characterBackground').naturalWidth>0);const initialBackground=await page.evaluate(()=>RelicBackground.selected);
  assert.equal(await page.evaluate(()=>HSRBackgroundData.length),33);assert.equal(await page.locator('#characterBackground').evaluate(el=>Number(getComputedStyle(el).opacity)),.36);
  await page.locator('#upgradeModeBtn').click();assert.equal(await page.locator('#markBtn').innerText(),'开始强化');
  assert.match(await page.locator('#rulesSummary').innerText(),/80/);
  await page.evaluate(async snapshot=>{await RelicDesk.loadFile(new File([JSON.stringify(snapshot)],'synthetic.json',{type:'application/json'}));RelicDesk.imported.captureId='synthetic-capture';document.getElementById('mode').dispatchEvent(new Event('change'));},snapshot);await page.waitForFunction(()=>!document.getElementById('markBtn').disabled);
  await page.screenshot({path:path.join(root,'work/upgrade-ui-ready.png')});
  await page.locator('#markBtn').click();await page.waitForFunction(()=>document.getElementById('phase').textContent==='已完成');
  assert.equal(startBody.plan.operation,'upgrade');assert.equal(startBody.plan.policy.maxRelicMaterialRarity,4);assert.equal(startBody.previewOnly,false);
  assert.equal(answers.length,2);assert.equal(answers[0].action,'enhance');assert.equal(answers[0].targetLevel,3);assert.ok(Number.isFinite(answers[1].lower));assert.notEqual(answers[0].requestId,answers[1].requestId);
  assert.equal(await page.evaluate(()=>RelicDesk.result),null);assert.equal(await page.locator('#markBtn').isDisabled(),true);
  // Demonstration screenshot only; no account snapshot is used in docs.
  await page.evaluate(()=>document.getElementById('demoBtn').click());await page.waitForFunction(()=>RelicDesk.result?.rows.length===112);
  await page.screenshot({path:path.join(root,'docs/preview.png')});
  await page.setViewportSize({width:780,height:620});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);assert.equal(await page.locator('#stopBtn').evaluate(el=>el.getBoundingClientRect().bottom<=innerHeight),true);
  await page.locator('#settingsBtn').click();assert.equal(await page.locator('dialog').isVisible(),true);await page.screenshot({path:path.join(root,'work/settings-ui.png')});await page.locator('#closeDialog').click();
  await page.setViewportSize({width:390,height:844});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth),false);await page.screenshot({path:path.join(root,'work/narrow-ui.png')});
  assert.equal(await page.evaluate(()=>RelicBackground.selected),initialBackground);await page.reload();await page.waitForFunction(()=>!!globalThis.RelicBackground);assert.notEqual(await page.evaluate(()=>RelicBackground.selected),initialBackground);
  assert.deepEqual(errors,[]);console.log('UI integration passed: Simplified Chinese, mode switch, capture, +3 decision, fresh rescore, stale-snapshot invalidation, dialogs, responsive layout and bundled nonrepeating backgrounds. Game input sent: 0');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1)});
