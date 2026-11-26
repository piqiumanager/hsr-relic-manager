// Account ownership is read from the game and persisted by the local service.
globalThis.AccountRoster=(()=>{
 'use strict';
 function valid(r){if(r?.state!=='complete'||r.complete!==true||r.source!=='game-character-ocr'||!/^\d{8,10}$/.test(r.accountUid)||!Array.isArray(r.characters)||!r.characters.length)return null;const ids=r.characters.map(c=>String(c.id));if(new Set(ids).size!==ids.length||ids.some(id=>HSRData.charNames[id]?.rarity!==5||!HSRData.profiles[id]))return null;return r;}
 function bind(imported,roster){const r=valid(roster);if(!r)throw Error('请先在“账号角色”读取当前账号的五星名单。');if(imported.uid&&imported.uid!==r.accountUid)throw Error('导入背包与当前角色名单属于不同账号。');return RelicEngine.parse({...imported.root,characters:r.characters,metadata:{...imported.root.metadata,uid:r.accountUid,rosterDigest:r.digest}});}
 function settings(saved={}){return RelicEngine.cleanupSettings({...saved,scope:'owned',selected:[]});}
 function accountLabel(r){return r?.accountUid?'账号尾号 '+r.accountUid.slice(-4):'尚未读取账号';}
 return{valid,bind,settings,accountLabel};
})();
