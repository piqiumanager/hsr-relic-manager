// Bundled official artwork and local display preferences.
globalThis.RelicBackground=(()=>{
 'use strict';
 const images=globalThis.HSRBackgroundData||[];
 function choose(items,last,random=Math.random){const pool=items.filter(i=>i.id!==last),choices=pool.length?pool:items;if(!choices.length)return null;return choices[Math.min(choices.length-1,Math.max(0,Math.floor(random()*choices.length)))];}
 function read(key){try{return localStorage.getItem(key);}catch{return null;}}
 let current=null,opacity=.82,pending;
 function flush(){if(pending){clearTimeout(pending);pending=null;}const cfg=globalThis.LOCAL_CONFIG;if(!cfg)return Promise.resolve();return fetch('/api/appearance',{method:'POST',headers:{'X-Relic-Token':cfg.token,'Content-Type':'application/json'},body:JSON.stringify({opacity,lastBackground:current?.id||''})}).then(r=>{if(!r.ok)throw Error('背景偏好未保存');});}
 function persist(){if(!globalThis.LOCAL_CONFIG)return;if(pending)clearTimeout(pending);pending=setTimeout(()=>{pending=null;flush().catch(()=>{});},180);}
 function setOpacity(value,save=true){const n=Number(value);opacity=Number.isFinite(n)?Math.max(.25,Math.min(1,n)):.82;document.documentElement?.style?.setProperty('--art-opacity',String(opacity));if(save){try{localStorage.setItem('hsr-art-opacity',String(opacity));}catch{}persist();}return opacity;}
 function set(id){const item=images.find(a=>a.id===id);if(!item)return false;current=item;const image=document.getElementById('characterBackground');if(image){image.src=item.src;image.dataset.character=item.id;}const label=document.getElementById('characterName');if(label)label.textContent=item.name;try{localStorage.setItem('hsr-last-background',item.id);}catch{}persist();return true;}
 function next(){const item=choose(images,current?.id);if(item)set(item.id);return current?.id||null;}
 const supplied=globalThis.LOCAL_CONFIG?.appearance;setOpacity(.82,false);
 const initial=choose(images,supplied?.lastBackground||read('hsr-last-background'));if(initial)set(initial.id);
 return{choose,flush,get selected(){return current?.id||null;},get opacity(){return opacity;}};
})();
