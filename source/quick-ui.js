(() => {
  'use strict';
  const $=id=>document.getElementById(id),E=RelicEngine;
  const state={phase:'idle',message:'先让游戏停留在登录界面，再点“一键整理”。',calibrated:false,scanned:0,marked:0};
  let captureBusy=false,watching=false,hasFreshPlan=false;
  const active=()=>['starting','calibrating','running'].includes(state.phase);
  async function api(route,body){
    if(!globalThis.LOCAL_CONFIG)throw Error('请运行 EXE 后使用游戏内整理；离线 HTML 可导入 JSON 评分。');
    const r=await fetch('/api/marker/'+route,{method:body===undefined?'GET':'POST',headers:{'X-Relic-Token':LOCAL_CONFIG.token,'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)})});
    const data=await r.json();if(!r.ok||data.error)throw Error(data.error||'本机服务未响应');return data;
  }
  function render(){
    $('quickStartBtn').textContent=captureBusy||active()?'查看整理进度':'一键整理 →';
    if(!$('flowStatus'))return;
    $('flowStatus').textContent=state.message;
    $('flowCalibration').textContent=state.calibrated?'校准已保存，同一分辨率下可继续使用。':'首次使用：打开背包 → 遗器，选中一件未锁定、未弃置的五星遗器，再点下方校准。';
    $('flowCalibrate').disabled=captureBusy||active();
    let plan;try{plan=E.buildMarkPlan(RelicDesk.result,RelicDesk.imported);}catch{}
    $('flowMark').disabled=captureBusy||active()||!hasFreshPlan||!state.calibrated||!plan?.total;
    $('flowStop').disabled=!active();
    $('flowCounts').textContent=`扫描 ${state.scanned||0} 次 · 已确认标记 ${state.marked||0} 件`;
    for(const [i,id]of ['flowRead','flowScore','flowFinish'].entries()){
      $(id).classList.toggle('done',i===0?!!RelicDesk.imported?.captureId:i===1?!!RelicDesk.result&&!captureBusy:state.phase==='complete');
    }
  }
  function dialog(){
    $('modalTitle').textContent='一键整理';$('modalEyebrow').textContent='READ → SCORE → MARK';
    $('modalBody').innerHTML=`<div class="modal-content quick-content"><div class="flow-steps"><span id="flowRead">1　读取背包</span><span id="flowScore">2　自动评分</span><span id="flowFinish">3　标记弃置</span></div><p>仅评估五星角色，默认只留极高分与高潜力胚子。已装备、已锁定及识别不清的遗器会跳过。</p><div class="marker-state-box" id="flowStatus"></div><p id="flowCalibration"></p><p><strong>读取完成后：</strong>在游戏内打开“背包 → 遗器”，只显示五星，清除锁定/弃置筛选，滚动到列表顶部，展开右侧详情。准备好后点“继续标记”，运行时不操作鼠标，<strong>F8</strong> 随时停止。</p><div class="marker-buttons"><button class="btn secondary" id="flowCalibrate">首次校准 / 重新校准</button><button class="btn primary" id="flowMark" disabled>继续标记</button><button class="btn danger" id="flowStop" disabled>停止标记</button></div><p id="flowCounts" class="small-muted"></p><p class="small-muted">标记完成后，请到游戏中检查弃置列表并自行确认分解。自动标记为实验功能，首次需要实机校准。</p></div>`;
    if(!$('modal').open)$('modal').showModal();
    $('flowCalibrate').onclick=async()=>{try{await api('calibrate',{});state.phase='calibrating';state.message='校准窗口即将打开，请跟随截图提示点选。';render();watch();}catch(e){fail(e);}};
    $('flowMark').onclick=async()=>{try{const plan=E.buildMarkPlan(RelicDesk.result,RelicDesk.imported);await api('start',{plan,previewOnly:false});state.phase='starting';state.message='即将切换到游戏并逐件核对，请保持背包界面，F8 可停止。';render();watch();}catch(e){fail(e);}};
    $('flowStop').onclick=async()=>{try{state.message=(await api('stop',{})).message;render();}catch(e){fail(e);}};
    render();
  }
  function fail(e){state.phase='failed';state.message=e.message||String(e);render();}
  async function watch(){
    if(watching)return;watching=true;
    try{for(;;){const s=await api('status');Object.assign(state,s,{phase:s.state});render();if(!active())break;await new Promise(r=>setTimeout(r,1300));}}
    catch(e){fail(e);}finally{watching=false;}
  }
  async function start(){
    if(captureBusy||active()){dialog();return;}
    dialog();
    if(!globalThis.LOCAL_CONFIG){fail(Error('请双击 EXE 使用一键整理；也可在主界面导入已有 JSON 离线筛选。'));return;}
    try{
      const s=await api('status');Object.assign(state,s,{phase:s.state});
      if(active()){render();watch();return;}
      captureBusy=true;hasFreshPlan=false;state.phase='reading';state.scanned=state.marked=0;state.message='准备读取，请停留在游戏登录界面。授权后再点击进入游戏。';render();
      const observer=new MutationObserver(()=>{state.message=$('captureState').textContent;render();});
      observer.observe($('captureState'),{childList:true,subtree:true,characterData:true});
      let ok=false;try{ok=await RelicDesk.capture();}finally{observer.disconnect();captureBusy=false;}
      if(!ok){fail(Error($('captureState').textContent||'未取得可用背包，请重新开始。'));return;}
      state.phase='ready';
      const plan=E.buildMarkPlan(RelicDesk.result,RelicDesk.imported);
      hasFreshPlan=true;
      state.message=`读取与评分完成：${RelicDesk.result.rows.length} 件五星遗器，${plan.total} 件可自动标记。现在打开游戏遗器背包，准备好后继续。`;
      render();
    }catch(e){captureBusy=false;fail(e);}
  }
  $('quickStartBtn').onclick=start;
  globalThis.QuickFlow={start,get state(){return {...state};}};
})();
