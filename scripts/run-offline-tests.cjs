// Stops on the first failing check. Never starts a game worker.
const {spawnSync}=require('node:child_process'),path=require('node:path'),fs=require('node:fs');
const root=path.resolve(__dirname,'..');
const js=['test-engine.cjs','test-import-main.cjs','test-upgrade-flow.cjs','test-upgrade-scoring.cjs','test-background.cjs','test-live-flow.cjs','test-roll-budget.cjs','test-numeric-ocr-recovery.cjs','test-stress-bridge.cjs','test-roster-flow.cjs','test-universal-speed.cjs','test-ocr-assets.cjs','test-mark-plan.cjs'];
const ps=['test-universal-speed.ps1','test-roster-core.ps1','test-roster-native.ps1','test-roster-bridge.ps1','test-roster-traversal.ps1','test-live-core.ps1','test-live-adversarial.ps1','test-live-executor.ps1','test-live-bridge.ps1','test-live-pipeline.ps1','test-upgrade-core.ps1','test-upgrade-bridge.ps1','test-server.ps1','test-appearance.ps1','test-layout.ps1','test-marker-core.ps1'];
if(process.argv.includes('--stress'))ps.push('test-live-bag.ps1');
if(process.argv.includes('--ocr'))ps.push('test-roster-ocr.ps1','test-marker-ocr.ps1','test-live-recognition.ps1');
const records=[];function run(name,exe,args){const start=Date.now(),r=spawnSync(exe,args,{cwd:root,encoding:'utf8',windowsHide:true});if(r.stdout)process.stdout.write(r.stdout);if(r.stderr)process.stderr.write(r.stderr);records.push({name,passed:r.status===0&&!r.error,durationMs:Date.now()-start});if(r.error||r.status!==0){save();throw r.error||Error('Failed '+name+' (exit '+r.status+')');}}
function save(){fs.mkdirSync(path.join(root,'work'),{recursive:true});fs.writeFileSync(path.join(root,'work/offline-test-results.json'),JSON.stringify({at:new Date().toISOString(),gameInput:0,checks:records},null,2));}
for(const f of js)run(f,process.execPath,[path.join('scripts',f)]);
for(const f of ps)run(f,'powershell.exe',['-NoProfile','-ExecutionPolicy','Bypass','-File',path.join('scripts',f),...(['test-live-pipeline.ps1','test-live-bag.ps1'].includes(f)?['-Node',process.execPath]:[])]);
save();console.log('Offline suites passed: '+records.length+'; actual game input: 0.');
