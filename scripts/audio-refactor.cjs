const fs = require("node:fs");

function read(path) {
  return fs.readFileSync(path, "utf8");
}

function write(path, content) {
  fs.writeFileSync(path, content);
}

function replaceRequired(text, from, to, label) {
  if (!text.includes(from)) throw new Error(`Missing expected audio block: ${label}`);
  return text.replace(from, to);
}

let page = read("app/page.tsx");
page = replaceRequired(
  page,
  'import { inputManager } from "../game/input/InputManager";\n',
  'import { inputManager } from "../game/input/InputManager";\nimport { audio } from "../game/audio/AudioManager";\n',
  "page audio import",
);
page = replaceRequired(page, "let soundEnabled = true;\n", "", "legacy sound flag");
page = page.replace(
  /function playTone\(frequency = 440, duration = 0\.08\) \{[\s\S]*?\n\}\n\nexport default function Home/,
  `function playTone(frequency = 440, duration = 0.08) {\n  if (hapticsEnabled && frequency < 200 && navigator.vibrate) navigator.vibrate(Math.min(45, Math.round(duration*180)));\n  audio.playSfx({ frequency, duration, volume: 0.05, waveform: "square" });\n}\n\nexport default function Home`,
);
page = page.replaceAll("soundEnabled=next.sound;", "audio.setMuted(!next.sound);");
if (page.includes("soundEnabled")) throw new Error("page.tsx still contains legacy soundEnabled state");
if (!page.includes('audio.playSfx({ frequency, duration, volume: 0.05, waveform: "square" })')) throw new Error("page playTone was not migrated");
write("app/page.tsx", page);

let race = read("app/Race3D.tsx");
race = replaceRequired(
  race,
  'import { inputManager, type InputAction } from "../game/input/InputManager";\n',
  'import { inputManager, type InputAction } from "../game/input/InputManager";\nimport { audio } from "../game/audio/AudioManager";\n',
  "Race3D audio import",
);
race = replaceRequired(
  race,
  '    if(!sound)return;\n    const ctx=new AudioContext();const osc=ctx.createOscillator();const gain=ctx.createGain();osc.type="square";osc.frequency.value=frequency;gain.gain.setValueAtTime(.035,ctx.currentTime);gain.gain.exponentialRampToValueAtTime(.001,ctx.currentTime+duration);osc.connect(gain);gain.connect(ctx.destination);osc.start();osc.stop(ctx.currentTime+duration);\n',
  '    if(!sound)return;\n    audio.playSfx({frequency,duration,volume:.035,waveform:"square"});\n',
  "Race3D oscillator",
);
write("app/Race3D.tsx", race);

let arena = read("app/ArenaRound.tsx");
arena = replaceRequired(
  arena,
  'import { inputManager, type InputAction } from "../game/input/InputManager";\n',
  'import { inputManager, type InputAction } from "../game/input/InputManager";\nimport { audio } from "../game/audio/AudioManager";\n',
  "Arena audio import",
);
arena = replaceRequired(
  arena,
  '    if(sound){const ctx=new AudioContext();const osc=ctx.createOscillator();const gain=ctx.createGain();osc.frequency.value=180;gain.gain.setValueAtTime(.04,ctx.currentTime);gain.gain.exponentialRampToValueAtTime(.001,ctx.currentTime+.1);osc.connect(gain);gain.connect(ctx.destination);osc.start();osc.stop(ctx.currentTime+.1);}\n',
  '    if(sound)audio.playSfx({frequency:180,duration:.1,volume:.04,waveform:"sine"});\n',
  "Arena oscillator",
);
write("app/ArenaRound.tsx", arena);

for (const path of ["app/page.tsx", "app/Race3D.tsx", "app/ArenaRound.tsx", "app/Tutorial.tsx"]) {
  const source = read(path);
  if (/new AudioContext\s*\(/.test(source) || /new AudioCtx\s*\(/.test(source)) {
    throw new Error(`${path} still creates AudioContext directly`);
  }
}
