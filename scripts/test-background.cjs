const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const root=path.resolve(__dirname,'..'),credits=JSON.parse(fs.readFileSync(path.join(root,'source/backgrounds/credits.json'),'utf8'));
assert.equal(credits.images.length,6);assert.equal(new Set(credits.images.map(a=>a.id)).size,6);
for(const a of credits.images){const url=new URL(a.source);assert.equal(url.protocol,'https:');assert.ok(['webstatic.mihoyo.com','fastcdn.mihoyo.com'].includes(url.hostname));assert.equal(crypto.createHash('sha256').update(fs.readFileSync(path.join(root,a.file))).digest('hex'),a.sha256);}
let last=null,element={},selected=[];const ctx={HSRBackgroundData:credits.images.map(a=>({id:a.id,src:'bundled:'+a.id})),localStorage:{getItem:()=>last,setItem:(_,v)=>last=v},document:{getElementById:()=>element}};
vm.createContext(ctx);const code=fs.readFileSync(path.join(root,'source/background.js'),'utf8');
for(let i=0;i<50;i++){element={dataset:{}};vm.runInContext(code,ctx);selected.push(ctx.RelicBackground.selected);assert.equal(element.dataset.character,last);if(i)assert.notEqual(selected[i],selected[i-1]);}
console.log('Background assets passed: 6 official images with matching checksums; 50 launches without an immediate repeat.');
