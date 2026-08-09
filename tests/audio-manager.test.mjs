import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";

const manager = fs.readFileSync("game/audio/AudioManager.ts", "utf8");
const appFiles = ["app/page.tsx", "app/Race3D.tsx", "app/ArenaRound.tsx", "app/Tutorial.tsx"];

test("AudioManager owns the only gameplay AudioContext construction", () => {
  assert.equal((manager.match(/new AudioCtx\(\)/g) ?? []).length, 1);
  assert.match(manager, /private context: AudioContext \| null = null/);

  for (const path of appFiles) {
    const source = fs.readFileSync(path, "utf8");
    assert.doesNotMatch(source, /new AudioContext\s*\(/, `${path} creates AudioContext directly`);
    assert.doesNotMatch(source, /new AudioCtx\s*\(/, `${path} creates an AudioContext alias directly`);
  }
});

test("AudioManager exposes SFX, music, mute, and volume controls", () => {
  for (const method of [
    "playSfx(",
    "setMuted(",
    "setSfxVolume(",
    "setMusicVolume(",
    "playMusic(",
    "stopMusic(",
    "registerSfx(",
    "registerMusic(",
    "resume(",
  ]) {
    assert.ok(manager.includes(method), `missing AudioManager API: ${method}`);
  }
});
