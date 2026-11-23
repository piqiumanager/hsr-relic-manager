(() => {
  'use strict';
  const $=id=>document.getElementById(id),E=RelicEngine;
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  let polling=false;
  async function api(route,options={}){
    if(!globalThis.LOCAL_CONFIG)throw Error('请完整解压工具包，双击“启动工具.cmd”后使用游戏内标记。');
    const res=await fetch('/api/marker/'+route,{...options,headers:{'X-Relic-Token':LOCAL_CONFIG.token,'Content-Type':'application/json'}});
    const data=await res.json();if(!res.ok||data.error)throw Error(data.error||'本机标记服务未响应');return data;
  }
  function render(state){
    const running=['starting','calibrating','running'].includes(state.state);
    $('markerStripText').textContent=state.message||'按候选属性逐件核对，只打弃置标记；分解由你在游戏内确认。';
    $('markerBtn').textContent=running?'查看标记进度 →':'自动标记弃置 →';
    if($('markerState')){
      $('markerState').textContent=state.message||'准备就绪';
      $('markerCalibration').textContent=state.calibrated?'位置校准：已保存':'位置校准：尚未完成';
      for(const [id,key]of [['markerScanned','scanned'],['markerMatched','matched'],['markerMarked','marked'],['markerPage','page']])$(id).textContent=state[key]||0;
      $('markerCalibrate').disabled=running;
      $('markerStart').disabled=running||!state.calibrated||!RelicDesk.imported?.captureId||!!RelicDesk.imported?.isDemo||!RelicDesk.result;
      $('markerPreview').disabled=$('markerStart').disabled;$('markerStop').disabled=!running;
    }
    return running;
  }
  async function poll(){
    if(polling)return;polling=true;
    try{while(true){const state=await api('status');if(!render(state))break;await new Promise(r=>setTimeout(r,1300));}}
    catch(err){if($('markerState'))$('markerState').textContent=err.message;else $('markerStripText').textContent=err.message;}
    finally{polling=false;}
  }
  async function open(){
    let plan=null,reason='';try{plan=E.buildMarkPlan(RelicDesk.result,RelicDesk.imported);}catch(e){reason=e.message;}
    $('modalTitle').textContent='游戏内自动标记弃置';$('modalEyebrow').textContent='IN-GAME / DISCARD MARKS';
    $('modalBody').innerHTML=`<div class="modal-content"><p>只处理本次清理候选；已锁定、已装备、已弃置或有识别歧义的遗器会跳过。最后的分解由你在游戏中确认。</p>${reason?`<div class="inline-warning">${esc(reason)}</div>`:`<div class="inline-warning">本次有 ${plan.total} 件可自动标记候选，逐件核对名称、等级、主副属性后才会点击。</div>`}<h3>首次使用</h3><p>在游戏中打开“背包 → 遗器”，选中一件未锁定、未弃置的五星遗器，再点“首次校准”，按截图提示点选位置。分辨率或界面布局变化后重新校准。</p><h3>每次开始前</h3><p>用“一键读取背包”取得新快照。遗器列表选择五星，清除锁定/弃置状态筛选，滚动到顶部，保持右侧详情展开。运行时不要操作鼠标；按 <strong>F8</strong> 随时停止。</p><p class="small-muted">校准和标记会切到游戏并申请管理员授权。中文 OCR 不清楚时跳过，不会点击分解或最终确认。</p><div class="marker-state-box" id="markerState">正在读取本机状态…</div><div class="marker-counts"><div>扫描次数<b id="markerScanned">0</b></div><div>核对命中<b id="markerMatched">0</b></div><div>确认标记<b id="markerMarked">0</b></div><div>当前页<b id="markerPage">0</b></div></div><p class="small-muted" id="markerCalibration">位置校准：读取中</p><div class="marker-buttons"><button class="btn secondary" id="markerCalibrate">首次校准 / 重新校准</button><button class="btn light" id="markerPreview" disabled>仅识别预览</button><button class="btn primary" id="markerStart" disabled>开始自动标记</button><button class="btn danger" id="markerStop" disabled>停止</button></div><p class="small-muted">前后证据和日志保存在 marker-runs 中。本功能已通过本地逻辑与 OCR 测试，尚需在你的游戏界面完成首次校准和实机核对。</p></div>`;
    if(!$('modal').open)$('modal').showModal();
    const error=e=>{$('markerState').textContent=e.message;};
    $('markerCalibrate').onclick=async()=>{try{await api('calibrate',{method:'POST',body:'{}'});render({state:'starting',message:'校准窗口即将打开，请跟随截图提示。'});poll();}catch(e){error(e);}};
    const start=async previewOnly=>{try{const fresh=E.buildMarkPlan(RelicDesk.result,RelicDesk.imported);await api('start',{method:'POST',body:JSON.stringify({plan:fresh,previewOnly})});render({state:'starting',message:previewOnly?'准备识别预览；不会点击弃置。':'准备标记，请保持游戏在前台；F8 停止。'});poll();}catch(e){error(e);}};
    $('markerStart').onclick=()=>start(false);$('markerPreview').onclick=()=>start(true);
    $('markerStop').onclick=async()=>{try{$('markerState').textContent=(await api('stop',{method:'POST',body:'{}'})).message;}catch(e){error(e);}};
    if(!globalThis.LOCAL_CONFIG){error(Error('请完整解压工具包，双击“启动工具.cmd”后使用游戏内标记。直接打开 HTML 只能离线筛选。'));$('markerCalibrate').disabled=true;return;}
    try{const state=await api('status');if(render(state))poll();}catch(e){error(e);}
  }
  $('markerBtn').onclick=open;
  globalThis.MarkerUI={open,render};
})();
