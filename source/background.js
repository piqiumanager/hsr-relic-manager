// Bundled official character art; changing the background never sends a request.
globalThis.RelicBackground=(()=>{
 'use strict';
 function choose(images,last,random=Math.random){const pool=images.filter(i=>i.id!==last);const choices=pool.length?pool:images;if(!choices.length)return null;return choices[Math.min(choices.length-1,Math.max(0,Math.floor(random()*choices.length)))];}
 let last;try{last=localStorage.getItem('hsr-last-background');}catch{}
 const selected=choose(globalThis.HSRBackgroundData||[],last),element=document.getElementById('characterBackground');
 if(selected&&element){element.src=selected.src;element.dataset.character=selected.id;try{localStorage.setItem('hsr-last-background',selected.id);}catch{}}
 return{choose,selected:selected?.id||null};
})();
