(() => {
  'use strict';
  const E=RelicEngine,D=HSRData,$=id=>document.getElementById(id);
  const esc=v=>String(v??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  const names={keep:'高分保留',upgrade:'高潜力胚子',discard:'清理候选',review:'需要复核'};
  const icons={Head:'♧',Hands:'♜',Body:'♢',Feet:'♧',PlanarSphere:'◉',LinkRope:'∞'};
  let imported=null,result=null,filter='all',page=0,settings=structuredClone(E.DEFAULTS),epoch=0,busy=false,capturing=false,timer=null;
  const prefsKey='hsr-relic-settings-v1';
  try{const saved=JSON.parse(localStorage.getItem(prefsKey)||'null');if(saved)settings=E.settingsValid({...settings,...saved});}catch{}
  const savePrefs=()=>{try{localStorage.setItem(prefsKey,JSON.stringify(settings));}catch{}};
  function toast(text){$('toast').textContent=text;$('toast').classList.remove('hidden');clearTimeout(timer);timer=setTimeout(()=>$('toast').classList.add('hidden'),2800);}
  function notice(text,type=''){const n=$('notice');n.textContent=text;n.className='notice'+(type?' '+type:'')+(text?'':' hidden');}
  function openModal(title,body,eyebrow='SETTINGS'){$('modalTitle').textContent=title;$('modalEyebrow').textContent=eyebrow;$('modalBody').innerHTML=body;if(!$('modal').open)$('modal').showModal();}
  const close=()=>$('modal').close();
  function score(n){return Number.isFinite(n)?n.toFixed(1):'—';}
  const statLabel=s=>E.STAT_ZH[s]||s;
  function value(s,v){return v===null||!Number.isFinite(v)?'—':((['HP','ATK','DEF','SPD'].includes(s)?v.toFixed(s==='SPD'?1:0):v.toFixed(1)+'%'));}
  const isNumericCell=s=>/^[0-9]+(?:\.[0-9]+)?$/.test(s);
  function download(name,content,type='application/json;charset=utf-8'){
    const url=URL.createObjectURL(new Blob([content],{type})),a=document.createElement('a');a.href=url;a.download=name;document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),5000);
  }
  function updateCriteria(){
    $('presetBadge').textContent=E.PRESETS[settings.preset]?.label||'自定义';
    const target=settings.scope==='all'?'全部已收录五星':settings.scope==='owned'?'已拥有五星':`手选 ${settings.selected.length} 位五星`;
    $('criteriaSummary').textContent=`${target} · 满级 ≥${settings.current}；胚子平均 ≥${settings.average}，且上限 ≥${settings.best}。`;
  }
  function setBusy(v){busy=v;$('reanalyzeBtn').disabled=v||!imported;$('exportBtn').disabled=v||!result;$('progressWrap').classList.toggle('hidden',!v);}
  async function analyze(){
    if(!imported)return;const run=++epoch;setBusy(true);notice('');
    try{
      const next=await E.analyze(imported,settings,p=>{if(run!==epoch)return;$('progressBar').style.width=(p*100)+'%';$('progressLabel').textContent=`正在评估五星角色适配与潜力… ${Math.round(p*100)}%`;});
      if(run!==epoch)return;result=next;page=0;render();
      if(imported.isDemo)notice('当前为示例背包，所有结果仅供体验。点击“读取背包”或导入你自己的文件开始整理。','demo-banner');
      else if(result.missing.length)notice('存在未收录的角色，部分低分遗器已转为待复核。请先在 Fribbels 检查这些角色的需要。','warning');
      else if(imported.ignored)notice(`已分析 ${imported.relics.length} 件五星遗器；${imported.ignored} 件非五星遗器未参与本次筛选。`);
      $('statusText').textContent=`已评估 ${result.profileCount} 位五星角色 · ${new Date().toLocaleTimeString('zh-CN',{hour:'2-digit',minute:'2-digit'})}`;
    }catch(err){if(run!==epoch)return;result=null;render();notice(err.message||'筛选失败，请检查导出文件。','error');}
    finally{if(run===epoch)setBusy(false);}
  }
  async function loadFile(file){
    if(!file)return;if(file.size>45*1024*1024){notice('文件过大，请导入 45 MB 以内的背包 JSON。','error');return;}
    try{
      const parsed=E.parse(await file.text());
      if(parsed.session){
        const session=parsed.session;const recovered=E.parse(session.root);if(recovered.session)throw Error('会话格式无效');
        imported=recovered;imported.isDemo=!!session.demo;settings=E.settingsValid({...E.DEFAULTS,...session.settings});updateCriteria();
        await afterLoad(file.name);if(result&&session.manual){for(const row of result.rows){const decision=session.manual[row.index+'|'+row.id];if(['keep','upgrade','review','discard'].includes(decision))row.manual=decision;}render();}
        return;
      }
      imported=parsed;await afterLoad(file.name);
    }catch(err){notice(err.message||'无法打开文件，请确认 JSON 文件完整。','error');}
    finally{$('fileInput').value='';}
  }
  async function afterLoad(label){
    filter='all';$('importTitle').textContent=label||'背包读取完成';
    $('importSub').textContent=`已导入 ${imported.relics.length} 件五星遗器 · ${imported.isDemo?'示例数据':imported.source} · 自动按当前规则筛选。`;
    $('fileMeta').innerHTML=`<span>${imported.owned.filter(id=>D.profiles[id]).length} 位已拥有五星角色</span><span>不上传账号数据</span><span>${imported.isDemo?'示例模式':'本机分析'}</span>`;
    await analyze();
  }
  function visible(){
    if(!result)return[];const q=$('searchInput').value.trim().toLowerCase(),pt=$('partFilter').value,lv=$('levelFilter').value;
    let rows=result.rows.filter(r=>(filter==='all'||E.status(r)===filter)&&(!pt||r.part===pt)&&(!lv||(lv==='zero'?r.enhance===0:lv==='partial'?r.enhance>0&&r.enhance<15:r.enhance===15))&&(!q||[r.id,r.setName,r.main.stat,statLabel(r.main.stat),...r.scores.map(s=>s.name)].join(' ').toLowerCase().includes(q)));
    const sort=$('sortSelect').value;
    if(sort==='level')rows.sort((a,b)=>b.enhance-a.enhance||a.index-b.index);
    else if(sort!=='index')rows.sort((a,b)=>(b.best?.[sort]??-1)-(a.best?.[sort]??-1)||a.index-b.index);
    return rows;
  }
  function render(){
    updateCriteria();const counts={keep:0,upgrade:0,discard:0,review:0};if(result)for(const row of result.rows)counts[E.status(row)]++;
    $('countAll').textContent=result?result.rows.length:'—';for(const k of Object.keys(counts))$('count'+k[0].toUpperCase()+k.slice(1)).textContent=result?counts[k]:'—';
    document.querySelectorAll('.stat-card').forEach(el=>el.classList.toggle('active',el.dataset.filter===filter));
    const rows=visible();page=Math.min(page,Math.max(0,Math.ceil(rows.length/40)-1));const paged=rows.slice(page*40,page*40+40);
    $('relicRows').innerHTML=paged.map(r=>{const st=E.status(r),best=r.best;return `<tr data-index="${r.index}" tabindex="0" aria-label="查看 ${esc(r.setName)} ${esc(E.PARTS[r.part])}"><td><div class="relic-title"><div class="slot-icon">${icons[r.part]||'◇'}</div><div><strong>${esc(r.setName)}</strong><small>${esc(statLabel(r.main.stat))} · ${esc(value(r.main.stat,r.main.value))}</small></div></div></td><td>${esc(E.PARTS[r.part]||r.part)}<span class="subtext">+${r.enhance} ${r.locked?' · 已锁定':''}${r.owner?' · 已装备':''}</span></td><td>${esc(best?.name||'待确认')}<span class="subtext">${best?.setRecommended?'推荐套装':'按属性评估'}${r.manual?' · 手动调整':''}</span></td><td><span class="number ${best?.current>=settings.current?'score-high':'score-low'}">${score(best?.current)}</span></td><td><span class="number ${best?.average>=settings.average?'score-high':'score-low'}">${score(best?.average)}</span></td><td><span class="number ${best?.best>=settings.best?'score-high':'score-low'}">${score(best?.best)}</span></td><td><span class="tag ${st}">${names[st]}</span></td><td style="color:#a1a7bd">›</td></tr>`;}).join('');
    $('resultCount').textContent=result?`${rows.length} 件`:'';
    $('emptyState').classList.toggle('hidden',rows.length>0);if(result&&!rows.length){$('emptyState').innerHTML='<div>⌕</div><h3>这个条件下没有遗器</h3><p>调整分类、部位、等级或搜索条件。</p>';}
    $('pagination').classList.toggle('hidden',rows.length<=40);$('pageInfo').textContent=`第 ${page+1} / ${Math.max(1,Math.ceil(rows.length/40))} 页 · 共 ${rows.length} 件`;
    $('prevPage').disabled=page===0;$('nextPage').disabled=(page+1)*40>=rows.length;
    $('reanalyzeBtn').disabled=busy||!imported;$('exportBtn').disabled=busy||!result;
  }
  function showDetail(index){
    const r=result?.rows.find(x=>x.index===index);if(!r)return;
    const st=E.status(r);const owner=r.owner?D.charNames[r.owner]?.name||r.owner:'未装备';
    openModal('遗器详情',`<div class="modal-content"><div class="detail-hero"><div class="slot-icon">${icons[r.part]||'◇'}</div><div><h3>${esc(r.setName)}</h3><span class="tag ${st}">${names[st]}</span><span class="small-muted">　${esc(E.PARTS[r.part])} · +${r.enhance} · ${esc(owner)}</span></div></div><div class="detail-stat"><span>主属性 · ${esc(statLabel(r.main.stat))}</span><strong>${esc(value(r.main.stat,r.main.value))}</strong></div><h3>副属性</h3><div class="detail-stats">${r.substats.map(s=>`<div class="detail-stat"><span>${esc(statLabel(s.stat))}</span><strong>${value(s.stat,s.value)}</strong></div>`).join('')}</div>${r.previewSubstats.length?'<p>未生效的预览词条：'+r.previewSubstats.map(s=>esc(statLabel(s.stat))+' '+value(s.stat,s.value)).join('，')+'</p>':''}<h3>为什么这样筛选</h3><ul class="reason-list">${r.reasons.map(s=>`<li>${esc(s)}</li>`).join('')}</ul><h3>五星角色适配 · 前 8 位</h3><div class="table-wrap"><table class="detail-scores"><thead><tr><th>角色</th><th>当前分</th><th>平均潜力</th><th>理论上限</th><th>套装</th></tr></thead><tbody>${r.scores.slice(0,8).map(s=>`<tr><td>${esc(s.name)}</td><td>${score(s.current)}</td><td>${score(s.average)}</td><td>${score(s.best)}</td><td>${s.setRecommended?'推荐':'散件参考'}</td></tr>`).join('')}</tbody></table></div><p class="small-muted">导入文件第 ${r.index+1} 件 · ID ${esc(r.id)}。顺序仅对应本次导出文件，不代表游戏当前格子。属性评分不代替整队配装与速度调轴。</p></div><div class="modal-actions"><button class="btn light" id="resetDecision">恢复自动结果</button><button class="btn secondary" id="manualReview">移入待复核</button><button class="btn primary" id="manualKeep">手动保留</button></div>`,'RELIC / DETAIL');
    const update=d=>{r.manual=d;render();close();toast('已调整本次整理结果');};$('manualKeep').onclick=()=>update('keep');$('manualReview').onclick=()=>update('review');$('resetDecision').onclick=()=>update(null);
  }
  function showRules(){
    openModal('高分保留规则',`<div class="modal-content"><h3>筛选强度</h3><div class="presets">${['extreme','strict'].map(k=>`<button class="preset ${settings.preset===k?'selected':''}" data-preset="${k}"><strong>${E.PRESETS[k].label}${k==='extreme'?' · 默认':''}</strong><span>满级 ${E.PRESETS[k].current} / 平均 ${E.PRESETS[k].average} / 上限 ${E.PRESETS[k].best}</span></button>`).join('')}</div><p>只有任意目标五星角色达到门槛，遗器才会被列为高分或高潜力。</p><div class="form-grid"><div class="field"><label for="ruleCurrent">满级：当前评分至少</label><input id="ruleCurrent" type="number" min="0" max="100" step="1" value="${settings.current}"></div><div class="field"><label for="ruleAverage">胚子：平均满级潜力至少</label><input id="ruleAverage" type="number" min="0" max="100" step="1" value="${settings.average}"></div><div class="field"><label for="ruleBest">胚子：理论上限至少</label><input id="ruleBest" type="number" min="0" max="100" step="1" value="${settings.best}"></div></div><p class="small-muted">分数为 0–100 的遗器属性潜力百分比。胚子必须同时满足后两项；理论上限不代表实际强化结果。</p><h3>低分遗器的处理</h3><div class="checks"><label class="check-line"><input id="protectLocked" type="checkbox" ${settings.protectLocked?'checked':''}>已锁定的低分遗器转入“需要复核”</label><label class="check-line"><input id="protectEquipped" type="checkbox" ${settings.protectEquipped?'checked':''}>已装备的低分遗器转入“需要复核”</label><label class="check-line"><input id="considerReroll" type="checkbox" ${settings.considerReroll?'checked':''}>考虑变量骰子的重掷潜力，较高时转入复核</label></div><p class="small-muted">不会按每个部位凑保留数量，也不会自动留下低分速度鞋或充能绳。缺失数据始终转入复核。</p><details><summary>高级：修改单个五星角色的评分权重</summary><div style="margin-top:16px"><select id="weightCharacter" class="full-width" style="max-width:none">${Object.values(D.profiles).map(p=>`<option value="${p.id}">${esc(p.name)}</option>`).join('')}</select><div id="weightEditor"></div></div></details></div><div class="modal-actions"><button id="resetRules" class="btn light">恢复极高分默认</button><button class="btn primary" id="applyRules">保存并自动筛选</button></div>`);
    let draft=structuredClone(settings.overrides||{}),currentCharacter=$('weightCharacter').value;
    const captureWeights=()=>{
      if(!document.querySelector('[data-weight]'))return;const p=D.profiles[currentCharacter];
      const stats={...p.stats,...draft[currentCharacter]?.stats};document.querySelectorAll('[data-weight]').forEach(el=>{const n=Number(el.value);if(!Number.isFinite(n)||n<0||n>1)throw Error('角色权重需要在 0–1 之间。');stats[el.dataset.weight]=n;});
      const parts=structuredClone(p.parts);for(const part of ['Body','Feet','PlanarSphere','LinkRope']){const vals=[...document.querySelectorAll(`[data-main-part="${part}"]:checked`)].map(el=>el.value);if(!vals.length)throw Error('每个部位至少选择一种主属性。');parts[part]=vals;}
      draft[currentCharacter]={stats,parts};
    };
    const renderWeights=()=>{
      const p=D.profiles[currentCharacter],o=draft[currentCharacter]||p;
      $('weightEditor').innerHTML=`<p class="small-muted">0 表示不需要，1 表示最高优先级。小生命、小攻击、小防御按对应百分比属性的 0.4 倍计权。</p><div class="weight-grid">${['HP%','ATK%','DEF%','SPD','CRIT Rate','CRIT DMG','Effect Hit Rate','Effect RES','Break Effect'].map(s=>`<label class="weight-field">${esc(statLabel(s))}<input type="number" min="0" max="1" step="0.05" data-weight="${s}" value="${o.stats[s]||0}"></label>`).join('')}</div><h3>可用主属性</h3>${['Body','Feet','PlanarSphere','LinkRope'].map(part=>`<div class="main-config-label">${E.PARTS[part]}</div><div class="main-chips">${HSRCore.PartsMainStats[part].map(s=>`<label><input type="checkbox" data-main-part="${part}" value="${s}" ${(o.parts||p.parts)[part].includes(s)?'checked':''}>${esc(statLabel(s))}</label>`).join('')}</div>`).join('')}`;
    };
    renderWeights();$('weightCharacter').onchange=()=>{try{captureWeights();currentCharacter=$('weightCharacter').value;renderWeights();}catch(e){toast(e.message);$('weightCharacter').value=currentCharacter;}};
    let chosenPreset=settings.preset;
    document.querySelectorAll('[data-preset]').forEach(btn=>btn.onclick=()=>{chosenPreset=btn.dataset.preset;const p=E.PRESETS[chosenPreset];$('ruleCurrent').value=p.current;$('ruleAverage').value=p.average;$('ruleBest').value=p.best;document.querySelectorAll('[data-preset]').forEach(x=>x.classList.toggle('selected',x===btn));});
    $('resetRules').onclick=()=>{settings={...structuredClone(E.DEFAULTS),scope:settings.scope,selected:settings.selected};savePrefs();close();updateCriteria();analyze();};
    $('applyRules').onclick=()=>{try{captureWeights();const next=E.settingsValid({...settings,preset:chosenPreset,current:Number($('ruleCurrent').value),average:Number($('ruleAverage').value),best:Number($('ruleBest').value),protectLocked:$('protectLocked').checked,protectEquipped:$('protectEquipped').checked,considerReroll:$('considerReroll').checked,overrides:draft});if(['current','average','best'].some(k=>next[k]!==E.PRESETS[chosenPreset]?.[k]))next.preset='custom';settings=next;savePrefs();updateCriteria();close();analyze();}catch(e){toast(e.message);}};
  }
  function showCharacters(){
    const selected=new Set(settings.selected),owned=new Set(imported?.owned||[]);const ps=Object.values(D.profiles).sort((a,b)=>Number(owned.has(b.id))-Number(owned.has(a.id))||a.name.localeCompare(b.name,'zh-CN'));
    openModal('只评估五星角色',`<div class="modal-content"><p>四星角色不参与评分。选择“全部五星”时，任何一位已收录五星角色适配的高分遗器都可留下。</p><div class="scope-options">${[['all','全部五星'],['owned','仅已拥有五星'],['selected','手动选择五星']].map(([v,n])=>`<label><input name="scope" type="radio" value="${v}" ${settings.scope===v?'checked':''}>${n}</label>`).join('')}</div><input id="characterSearch" class="character-search" placeholder="搜索五星角色"><div class="row gap" style="margin-bottom:12px"><button class="text-btn" id="selectOwned">勾选已拥有五星</button><button class="text-btn" id="selectAll">全选</button><button class="text-btn" id="selectNone">清空</button></div><div class="character-grid">${ps.map(p=>`<label class="character-chip ${owned.has(p.id)?'owned':''}" data-character-name="${esc(p.name.toLowerCase())}"><input type="checkbox" data-character-id="${p.id}" ${selected.has(p.id)?'checked':''}>${esc(p.name)}<small>${owned.has(p.id)?'已拥有':'★★★★★'}</small></label>`).join('')}</div><p class="small-muted">新增或未收录角色不会被猜测评分。使用“仅已拥有”需要导出文件包含角色列表。</p></div><div class="modal-actions"><button class="btn primary" id="applyCharacters">保存并自动筛选</button></div>`,'ROSTER / 5-STAR ONLY');
    $('characterSearch').oninput=e=>{const q=e.target.value.toLowerCase();document.querySelectorAll('[data-character-name]').forEach(el=>el.classList.toggle('hidden',!el.dataset.characterName.includes(q)));};
    const select=f=>document.querySelectorAll('[data-character-id]').forEach(el=>el.checked=f(el.dataset.characterId));
    $('selectOwned').onclick=()=>select(id=>owned.has(id));$('selectAll').onclick=()=>select(()=>true);$('selectNone').onclick=()=>select(()=>false);
    $('applyCharacters').onclick=()=>{const scope=document.querySelector('input[name=scope]:checked').value;const selected=[...document.querySelectorAll('[data-character-id]:checked')].map(x=>x.dataset.characterId);if(scope==='selected'&&!selected.length){toast('请至少勾选一位五星角色');return;}settings={...settings,scope,selected};savePrefs();close();updateCriteria();analyze();};
  }
  function showHelp(){
    openModal('三步完成遗器筛选',`<div class="modal-content"><div class="help-step"><b>1</b><div><h3>读取完整背包</h3><p>双击“启动工具.cmd”，点击“一键读取背包”。首次会下载官方 Reliquary PktMon 版本，校验后申请管理员授权。停在游戏登录界面，启动读取后再点击进入游戏。已有导出文件可直接拖入。</p></div></div><div class="help-step"><b>2</b><div><h3>自动留下高分与高潜力</h3><p>仅五星角色参与。默认满级当前分至少 75；胚子平均满级潜力至少 70，且理论上限至少 85。不按部位凑数。你可以修改门槛或单个角色权重。</p></div></div><div class="help-step"><b>3</b><div><h3>复核清理候选</h3><p>点击遗器查看属性和适配角色，也可手动移入保留或复核。导出结果保留完整属性供定位。本版可自动读取、筛选并在游戏内标记弃置。首次先完成位置校准；脚本不执行分解，最终由你在游戏内确认。</p></div></div><hr class="separator"><h3>分数怎样理解</h3><p>复用 Fribbels 的遗器属性评分核心。满级看当前属性；未满级计算后续强化的平均结果与最优上限。它不是整队伤害模拟，套装效果和速度调轴仍需在 Fribbels 配装中检查。默认不为中低分保留散件，也不自动尝试强化。</p><p>“需要复核”可能包括已装备或已锁定的低分遗器、未知套装、缺失字段和无法解析的属性。它们没有被认定为高分。</p><h3>在 Fribbels 中继续查看</h3><p>可导出原始背包，再到 Fribbels 的 Import / 导入页面导入。工具不会把账号文件自动上传到第三方。</p><p><a href="https://fribbels.github.io/hsr-optimizer/" target="_blank" rel="noopener noreferrer">打开 Fribbels ↗</a>　<a href="https://github.com/IceDynamix/reliquary-archiver/releases/tag/v0.20.0" target="_blank" rel="noopener noreferrer">Reliquary 官方下载 ↗</a></p><h3>本机与文件</h3><p>背包数据仅在浏览器内分析。读取文件放在工具目录的“captures”中。关闭前可导出会话，之后导入即可恢复规则与手动调整。浏览器只自动记忆规则，不自动保存账号背包。</p><p class="small-muted">角色配置与评分核心：Fribbels，MIT License，内置快照 2026-11-23。新版本游戏若新增未知套装或角色，将进入复核。授权见随包 licenses 文件夹。遗器单件名称来自 StarRailRes；v1.1 完整源码随包提供，整体按 AGPL-3.0 授权，Fribbels 部分保留 MIT 许可。</p></div>`,'GET STARTED');
  }
  function showExport(){
    if(!result)return;
    openModal('导出本次整理',`<div class="modal-content"><p>导出的是筛选建议，不会修改游戏背包。示例数据导出时会明确标为示例。</p><div class="export-options"><button class="btn secondary" id="downloadCSV">↓ 当前列表 CSV · ${visible().length} 件</button><button class="btn secondary" id="downloadDecisions">↓ 完整结果 JSON · 含评分、属性、去留理由</button><button class="btn secondary" id="downloadSession">↓ 保存完整会话 · 下次可恢复</button><button class="btn light" id="downloadOriginal">↓ 原始背包 JSON · 可导入 Fribbels</button></div></div>`,'EXPORT / LOCAL FILES');
    const prefix=imported.isDemo?'示例-':'';
    $('downloadDecisions').onclick=()=>download(prefix+'遗器筛选结果.json',JSON.stringify(E.exportResults(result,imported),null,2));
    $('downloadSession').onclick=()=>download(prefix+'遗器整理会话.json',JSON.stringify({schema:'hsr-relic-session-v1',demo:!!imported.isDemo,root:imported.root,settings,manual:Object.fromEntries(result.rows.filter(r=>r.manual).map(r=>[r.index+'|'+r.id,r.manual]))}));
    $('downloadOriginal').onclick=()=>download(prefix+'背包-Fribbels导入.json',JSON.stringify(imported.root,null,2));
    $('downloadCSV').onclick=()=>{const cell=v=>{let t=String(v??'');if(!isNumericCell(t)&&/^[=+\-@\t\r]/.test(t))t="'"+t;return '"'+t.replaceAll('"','""')+'"';};const headers=['文件序号','ID','套装','部位','等级','主属性','副属性','最佳适配五星','当前分','平均潜力','理论上限','结果','理由'];const data=visible().map(r=>[r.index+1,r.id,r.setName,E.PARTS[r.part],r.enhance,statLabel(r.main.stat)+' '+value(r.main.stat,r.main.value),r.substats.map(s=>statLabel(s.stat)+' '+value(s.stat,s.value)).join(' / '),r.best?.name,score(r.best?.current),score(r.best?.average),score(r.best?.best),names[E.status(r)],r.reasons.join('；')]);download(prefix+'遗器清单.csv','\uFEFF'+[headers,...data].map(row=>row.map(cell).join(',')).join('\r\n'),'text/csv;charset=utf-8');};
  }
  async function api(path,options={}){
    const config=globalThis.LOCAL_CONFIG;if(!config)throw Error('请解压完整工具包，双击“启动工具.cmd”使用一键读取。直接打开 HTML 时可使用 JSON 导入。');
    const response=await fetch('/api/'+path,{...options,headers:{'X-Relic-Token':config.token,'Content-Type':'application/json',...options.headers}});
    const data=await response.json();if(!response.ok||data.error)throw Error(data.error||'本机读取服务未响应');return data;
  }
  async function capture(){
    if(capturing)return false;
    if(!globalThis.LOCAL_CONFIG){openModal('启用一键读取',`<div class="modal-content"><p>请先解压完整工具包，再双击 <strong>启动工具.cmd</strong>。本机服务启动后即可一键调用 Reliquary。</p><p>现在也可直接导入已有 JSON 文件。若尚未导出，下载官方工具并按说明重新登录游戏：</p><p><a href="https://github.com/IceDynamix/reliquary-archiver/releases/tag/v0.20.0" target="_blank" rel="noopener noreferrer">Reliquary 官方下载 ↗</a></p></div>`,'CAPTURE');return;}
    capturing=true;$('captureBtn').disabled=true;$('captureState').classList.remove('hidden');
    $('captureState').textContent='准备读取：首次会下载 Reliquary 并申请管理员授权。请在游戏登录界面等待读取启动。';
    try{
      await api('capture/start',{method:'POST',body:'{}'});
      let done=false;for(let n=0;n<200&&!done;n++){
        await new Promise(resolve=>setTimeout(resolve,1200));const state=await api('capture/status');
        if(state.state==='complete'){done=true;imported=E.parse(state.data);imported.captureId=state.captureId;await afterLoad('背包读取完成');$('captureState').textContent='读取完成，已按当前规则自动筛选。';}
        else if(state.state==='failed')throw Error(state.message||'读取失败，请在启动读取后重新登录游戏。');
        else $('captureState').textContent=state.message||'读取已启动，请从登录界面点击进入游戏，等候背包数据返回…';
      }
      if(!done)throw Error('等待读取超时。请确认已重新登录，或使用已有 JSON 文件导入。');
      return !!result;
    }catch(e){$('captureState').textContent=e.message;notice(e.message,'error');return false;}
    finally{capturing=false;$('captureBtn').disabled=false;}
  }
  $('closeModal').onclick=close;$('modal').onclick=e=>{if(e.target===$('modal')){const rect=$('modal').getBoundingClientRect();if(e.clientX<rect.left||e.clientX>rect.right||e.clientY<rect.top||e.clientY>rect.bottom)close();}};
  document.querySelectorAll('[data-open]').forEach(btn=>btn.onclick=()=>({characters:showCharacters,rules:showRules,help:showHelp})[btn.dataset.open]());
  $('rulesTop').onclick=showRules;$('fileInput').onchange=e=>loadFile(e.target.files[0]);
  const demo=async()=>{imported=E.demo();await afterLoad('示例背包 · 非你的账号');};
  $('demoBtn').onclick=demo;$('emptyDemoBtn').onclick=demo;$('captureBtn').onclick=capture;$('reanalyzeBtn').onclick=analyze;$('exportBtn').onclick=showExport;
  document.querySelectorAll('[data-filter]').forEach(btn=>btn.onclick=()=>{filter=btn.dataset.filter;page=0;render();});
  for(const id of ['searchInput','partFilter','levelFilter','sortSelect'])$(id).addEventListener(id==='searchInput'?'input':'change',()=>{page=0;render();});
  $('prevPage').onclick=()=>{page--;render();};$('nextPage').onclick=()=>{page++;render();};
  $('relicRows').onclick=e=>{const tr=e.target.closest('[data-index]');if(tr)showDetail(Number(tr.dataset.index));};
  $('relicRows').onkeydown=e=>{if(e.key==='Enter'){const tr=e.target.closest('[data-index]');if(tr)showDetail(Number(tr.dataset.index));}};
  $('dropZone').ondragover=e=>{e.preventDefault();$('dropZone').classList.add('dragover');};$('dropZone').ondragleave=()=>$('dropZone').classList.remove('dragover');$('dropZone').ondrop=e=>{e.preventDefault();$('dropZone').classList.remove('dragover');loadFile(e.dataTransfer.files[0]);};
  for(const [v,n]of Object.entries(E.PARTS))$('partFilter').insertAdjacentHTML('beforeend',`<option value="${v}">${n}</option>`);
  updateCriteria();
  globalThis.RelicDesk={get imported(){return imported;},get result(){return result;},get settings(){return settings;},get capturing(){return capturing;},loadFile,analyze,visible,capture};
})();
