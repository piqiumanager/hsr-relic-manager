globalThis.NumericOcr=(()=>{
 let ready;
 async function worker(){
  if(!ready)ready=(async()=>{
   if(!globalThis.Tesseract)await new Promise((resolve,reject)=>{const script=document.createElement('script');script.src='/ocr/tesseract.min.js';script.onload=resolve;script.onerror=()=>reject(Error('数字识别组件加载失败'));document.head.append(script);});
   const w=await Tesseract.createWorker('eng',1,{workerPath:'/ocr/worker.min.js',corePath:'/ocr/tesseract-core-lstm.js',langPath:'/ocr',gzip:false,cacheMethod:'none',workerBlobURL:false});
   await w.setParameters({tessedit_char_whitelist:'0123456789.+%',tessedit_pageseg_mode:7});return w;
  })().catch(e=>{ready=null;e.fatal=true;throw e;});return ready;
 }
 async function resolve(raw){
  if(!raw.numericImages)return raw;
  if(raw.numericImages.length!==2+raw.substats.length+(raw.preview_substats?.length||0))throw Error('属性数字区域不完整');
  const w=await worker(),values=[];for(const image of raw.numericImages){const r=await w.recognize(image);const text=r.data.text.replace(/\s/g,'');if(!/^\+?\d+(?:\.\d+)?%?$/.test(text)||!Number.isFinite(r.data.confidence)||r.data.confidence<65)throw Error('属性数字无法可靠识别');values.push(text);}
  const r=structuredClone(raw);delete r.numericImages;r.level=Number(values[0].replace('+',''));r.mainstat_value=Number(values[1].replace('%',''));if(['HP','ATK','DEF'].includes(r.mainstat)&&values[1].endsWith('%'))r.mainstat+='%';
  if((r.mainstat==='SPD'&&values[1].endsWith('%'))||(r.mainstat!=='SPD'&&!['HP','ATK','DEF'].includes(r.mainstat)&&!values[1].endsWith('%')))throw Error('主属性百分比符号未确认');
  for(const [i,s]of [...r.substats,...r.preview_substats].entries()){const v=values[i+2];s.value=Number(v.replace('%',''));if(['HP','ATK','DEF'].includes(s.key)&&v.endsWith('%'))s.key+='%';if((s.key==='SPD'&&v.endsWith('%'))||(s.key!=='SPD'&&!['HP','ATK','DEF'].includes(s.key)&&!v.endsWith('%')))throw Error('百分比符号未确认');}
  return r;
 }
 return{resolve};
})();
