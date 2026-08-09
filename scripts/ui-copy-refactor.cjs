const fs = require("node:fs");

function update(path, replacements) {
  let text = fs.readFileSync(path, "utf8");
  for (const [from, to, label] of replacements) {
    if (!text.includes(from)) throw new Error(`Missing expected UI copy: ${label}`);
    text = text.replace(from, to);
  }
  fs.writeFileSync(path, text);
}

update("app/page.tsx", [
  ['aria-label={settings.sound?"사운드 끄기":"사운드 켜기"}', 'aria-label={settings.sound?"효과음 끄기":"효과음 켜기"}', "header sound aria label"],
  ['<SettingRow label="사운드" note="효과음과 간단한 배경 리듬" checked={settings.sound} onChange={(v)=>updateSetting("sound",v)}/>', '<SettingRow label="효과음" note="점프·충돌·스킬 효과음" checked={settings.sound} onChange={(v)=>updateSetting("sound",v)}/>', "sound setting"],
  ['<SettingRow label="모바일 진동" note="충돌과 스킬 사용 시 햅틱" checked={settings.haptics} onChange={(v)=>updateSetting("haptics",v)}/>', '', "mobile haptics setting"],
  ['<SettingRow label="큰 터치 버튼" note="모바일 조작 버튼을 20% 확대" checked={settings.largeTouch} onChange={(v)=>updateSetting("largeTouch",v)}/>', '', "large touch setting"],
  ['50-PLAYER PARTY ROYALE', '50-RACER LOCAL AI RACE', "lobby race label"],
  ['NEXT ROUND · 3D GRAND PRIX', 'NEXT ROUND · WILD GRAND PRIX', "round grand prix label"],
  ['ROUND 1 · 입체 레이싱', 'ROUND 1 · 50마리 로컬 레이스', "round race description"],
  ['3D 그랑프리 출전!', '그랑프리 출전!', "race start button"],
  ['3D GRAND PRIX · 동일 기본 속도 · 스킬 5초 잠금', 'WILD GRAND PRIX · LOCAL AI RACE · 동일 기본 속도 · 스킬 5초 잠금', "countdown race label"],
  ['navigator.clipboard?.writeText("나 방금 WILD DASH 50에서 우당탕탕 완주했어! 🐾")', 'navigator.clipboard?.writeText("나 방금 WILD DASH에서 50마리 로컬 AI 레이스를 완주했어! 🐾")', "share text"],
  ['▣ 쇼츠로 뽐내기', '▣ 결과 공유하기', "share button"],
]);

update("app/Race3D.tsx", [
  ['aria-label="위에서 내려다보는 3D 파티 동물 레이싱 경기장"', 'aria-label="위에서 내려다보는 원근 연출 파티 동물 레이싱 경기장"', "canvas accessibility label"],
]);

update("app/Tutorial.tsx", [
  ['PC는 W/S 또는 방향키, 모바일은 위·아래 버튼을 사용해요.', 'W/S 또는 방향키로 이동해요.', "tutorial movement copy"],
]);
