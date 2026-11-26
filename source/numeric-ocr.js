globalThis.NumericOcr=(()=>{
 let ready;const TIMEOUT=30000,terminated=new WeakSet();
 function terminate(w){try{if(w?.terminate&&!terminated.has(w)){terminated.add(w);Promise.resolve(w.terminate()).catch(()=>{});}}catch{}}
 function cancellation(){const e=Error('已停止数字识别。');e.name='AbortError';e.cancelled=true;return e;}
 function abandon(cause,pending,w){
  if(ready===pending)ready=null;
  if(w||pending?.instance)terminate(w||pending.instance);else pending?.then(terminate,()=>{});
  if(cause?.cancelled||cause?.name==='AbortError')return cancellation();
  const e=Error('数字识别组件运行失败：'+(cause?.message||String(cause)));e.fatal=true;return e;
 }
 function bounded(promise,deadline,signal){
  if(signal?.aborted)return Promise.reject(cancellation());
  const remaining=deadline-Date.now();if(remaining<=0)return Promise.reject(Error('识别超过 30 秒，已停止。'));
  return new Promise((resolve,reject)=>{
   let settled=false;const finish=(fn,value)=>{if(settled)return;settled=true;clearTimeout(timer);signal?.removeEventListener('abort',onAbort);fn(value);};
   const onAbort=()=>finish(reject,cancellation()),timer=setTimeout(()=>finish(reject,Error('识别超过 30 秒，已停止。')),remaining);
   signal?.addEventListener('abort',onAbort,{once:true});
   Promise.resolve(promise).then(v=>finish(resolve,v),e=>finish(reject,e));
  });
 }
 function worker(){
  if(!ready){
   let pending;pending=(async()=>{
    if(!globalThis.Tesseract)await new Promise((resolve,reject)=>{const script=document.createElement('script');script.src='/ocr/tesseract.min.js';script.onload=resolve;script.onerror=()=>reject(Error('数字识别组件加载失败'));document.head.append(script);});
    const w=await Tesseract.createWorker('eng',1,{workerPath:'/ocr/worker.min.js',corePath:'/ocr/tesseract-core-lstm.js',langPath:'/ocr',gzip:false,cacheMethod:'none',workerBlobURL:false});pending.instance=w;
    try{await w.setParameters({tessedit_char_whitelist:'0123456789.+%',tessedit_pageseg_mode:7});return w;}catch(e){terminate(w);throw e;}
   })().catch(cause=>{if(ready===pending)ready=null;const e=Error(cause?.message||String(cause));e.fatal=true;throw e;});ready=pending;
  }
  return ready;
 }
 async function resolve(raw,{signal}={}){
  if(signal?.aborted)throw cancellation();
  if(!raw.numericImages)return raw;
  if(raw.numericImages.length!==2+raw.substats.length+(raw.preview_substats?.length||0))throw Error('属性数字区域不完整');
  const deadline=Date.now()+TIMEOUT,pending=worker();let w;
  try{w=await bounded(pending,deadline,signal);}catch(e){throw abandon(e,pending,w);}
  const values=[];
  for(const image of raw.numericImages){
   let result;try{result=await bounded(w.recognize(image),deadline,signal);}catch(e){throw abandon(e,pending,w);}
   if(!result?.data||typeof result.data.text!=='string')throw abandon(Error('组件未返回有效识别结果'),pending,w);
   const text=result.data.text.replace(/\s/g,'');
   if(!/^\+?\d+(?:\.\d+)?%?$/.test(text)||!Number.isFinite(result.data.confidence)||result.data.confidence<65)throw Error('属性数字无法可靠识别');
   values.push(text);
  }
  if(signal?.aborted)throw abandon(cancellation(),pending,w);
  const r=structuredClone(raw);delete r.numericImages;r.level=Number(values[0].replace('+',''));r.mainstat_value=Number(values[1].replace('%',''));if(['HP','ATK','DEF'].includes(r.mainstat)&&values[1].endsWith('%'))r.mainstat+='%';
  if((r.mainstat==='SPD'&&values[1].endsWith('%'))||(r.mainstat!=='SPD'&&!['HP','ATK','DEF'].includes(r.mainstat)&&!values[1].endsWith('%')))throw Error('主属性百分比符号未确认');
  for(const [i,s]of [...r.substats,...r.preview_substats].entries()){const v=values[i+2];s.value=Number(v.replace('%',''));if(['HP','ATK','DEF'].includes(s.key)&&v.endsWith('%'))s.key+='%';if((s.key==='SPD'&&v.endsWith('%'))||(s.key!=='SPD'&&!['HP','ATK','DEF'].includes(s.key)&&!v.endsWith('%')))throw Error('百分比符号未确认');}
  return r;
 }
 return{resolve};
})();
