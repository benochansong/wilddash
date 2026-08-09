const fs = require("node:fs");

function update(path, replacements) {
  let text = fs.readFileSync(path, "utf8");
  for (const [from, to, label] of replacements) {
    if (!text.includes(from)) throw new Error(`Missing expected source for ${label}`);
    text = text.replace(from, to);
  }
  fs.writeFileSync(path, text);
}

update("app/Race3D.tsx", [
  [
    'import { obstacleLateral } from "../game/systems/collisionSystem";',
    'import { isRaceCollision, obstacleLateral } from "../game/systems/collisionSystem";\nimport { consumeItem, selectRace3DItem } from "../game/systems/itemSystem";\nimport { canUseSkill, tickCooldown } from "../game/systems/skillSystem";',
    "Race3D system imports",
  ],
  [
    'const g=game.current;if(g.skillCd>0){g.flash=`출발 보호 · ${g.skillCd.toFixed(1)}초 후 사용`;return;}',
    'const g=game.current;if(!canUseSkill(g.skillCd)){g.flash=`출발 보호 · ${g.skillCd.toFixed(1)}초 후 사용`;return;}',
    "skill availability",
  ],
  [
    'const g=game.current;if(!g.item)return;\n    if(g.item==="banana"){g.bananas.push({s:g.s-160,lateral:g.lateral,life:7,owner:"player"});g.flash="🍌 뒤에 바나나 설치";}\n    if(g.item==="shield"){g.shield=3.2;g.flash="🐢 충돌 1회 방어";}\n    if(g.item==="magnet"){g.s+=400;g.flash="🧲 초고속 견인 +400m";}\n    if(g.item==="ink"){game.current.ai.filter(a=>a.s>g.s).sort((a,b)=>a.s-b.s).slice(0,6).forEach(a=>a.stun=1.1);g.flash="🦑 앞선 6마리 시야 방해";}',
    'const g=game.current;const item=consumeItem(g.item);if(!item)return;\n    if(item==="banana"){g.bananas.push({s:g.s-160,lateral:g.lateral,life:7,owner:"player"});g.flash="🍌 뒤에 바나나 설치";}\n    if(item==="shield"){g.shield=3.2;g.flash="🐢 충돌 1회 방어";}\n    if(item==="magnet"){g.s+=400;g.flash="🧲 초고속 견인 +400m";}\n    if(item==="ink"){game.current.ai.filter(a=>a.s>g.s).sort((a,b)=>a.s-b.s).slice(0,6).forEach(a=>a.stun=1.1);g.flash="🦑 앞선 6마리 시야 방해";}',
    "item consumption",
  ],
  [
    'g.time+=dt;g.skillCd=Math.max(0,g.skillCd-dt);g.boost=Math.max(0,g.boost-dt);',
    'g.time+=dt;g.skillCd=tickCooldown(g.skillCd,dt);g.boost=Math.max(0,g.boost-dt);',
    "skill cooldown tick",
  ],
  [
    'if(g.crossed.has(o.id))return;if(Math.abs(g.s-o.s)<90&&Math.abs(g.lateral-obstacleLateral(o,g.time))<52){',
    'if(g.crossed.has(o.id))return;if(isRaceCollision(g.s,o.s,g.lateral,obstacleLateral(o,g.time))){',
    "race obstacle collision",
  ],
  [
    'b.taken=true;const pool:Exclude<ItemKey,null>[]=g.ai.filter(a=>a.s>g.s).length>30?["shield","magnet","ink","magnet"]:["banana","shield","ink","magnet"];g.item=pool[i%pool.length];',
    'b.taken=true;g.item=selectRace3DItem(g.ai.filter(a=>a.s>g.s).length,i);',
    "item acquisition",
  ],
]);

update("app/ArenaRound.tsx", [
  [
    'import { audio } from "../game/audio/AudioManager";',
    'import { audio } from "../game/audio/AudioManager";\nimport { isArenaContact } from "../game/systems/collisionSystem";\nimport { isFinalPlayerEliminated, isFinalRoundSuccess, isFruitRoundSuccess, isSurvivalRoundFailure, resolveRoundTimeout } from "../game/systems/roundSystem";',
    "Arena system imports",
  ],
  ['if (s.score >= 8) {', 'if (isFruitRoundSuccess(s.score)) {', "fruit success"],
  ['if (contact < 8 && s.immune <= 0) {', 'if (isArenaContact(s.x,s.y,b.x,b.y) && s.immune <= 0) {', "arena contact"],
  ['if (s.hearts<=0) {', 'if (isSurvivalRoundFailure(s.hearts)) {', "survival failure"],
  ['if(playerRadius>48){s.done=true;onComplete(false,s.bots.length);return;}', 'if(isFinalPlayerEliminated(playerRadius)){s.done=true;onComplete(false,s.bots.length);return;}', "final elimination"],
  ['if(s.bots.length===0){s.done=true;onComplete(true,2);return;}', 'if(isFinalRoundSuccess(s.bots.length)){s.done=true;onComplete(true,2);return;}', "final success"],
  [
    'if (s.time<=0) { s.done=true; onComplete(mode === "survival" || (mode === "final" && s.bots.length===0), mode === "fruit" ? s.score : s.hearts); return; }',
    'if (s.time<=0) { const outcome=resolveRoundTimeout(mode,s.score,s.hearts,s.bots.length); s.done=true; onComplete(outcome.success,outcome.score); return; }',
    "round timeout",
  ],
]);
