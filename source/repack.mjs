// Optional developer command: node repack.mjs. Normal use requires no Node.js.
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const base=path.dirname(fileURLToPath(import.meta.url));
const read=name=>fs.readFileSync(path.join(base,name),'utf8');
const safe=s=>s.replace(/<\/script/gi,'<\\/script');
const backgrounds=JSON.parse(read('backgrounds/credits.json')).images.map(a=>({id:a.id,name:a.name,src:'source/backgrounds/'+a.id+'.webp'}));
let html=read('index.template.html').replace('/*STYLE*/',read('style.css')).replace('/*DATA*/','globalThis.HSRData='+read('data.json')+';globalThis.HSRBackgroundData='+JSON.stringify(backgrounds)+';').replace('/*CORE*/',safe(read('fribbels-core.js'))).replace('/*ENGINE*/',safe(read('engine.js'))).replace('/*APP*/',safe(read('background.js')+'\n'+read('roster.js')+'\n'+read('upgrade-flow.js')+'\n'+read('numeric-ocr.js')+'\n'+read('live-flow.js')+'\n'+read('app.js')));
fs.writeFileSync(path.join(base,'../星铁遗器整理助手.html'),html);
console.log('已重新生成界面文件。');
