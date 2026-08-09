import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import ts from "typescript";

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

test("AudioManager reuses one AudioContext across repeated SFX playback", async () => {
  const compiled = ts.transpileModule(manager, {
    compilerOptions: {
      module: ts.ModuleKind.ES2022,
      target: ts.ScriptTarget.ES2022,
    },
  }).outputText;
  const moduleUrl = `data:text/javascript;base64,${Buffer.from(compiled).toString("base64")}`;

  let contextCount = 0;
  class FakeParam {
    value = 0;
    setValueAtTime(value) { this.value = value; }
    exponentialRampToValueAtTime(value) { this.value = value; }
  }
  class FakeGain {
    gain = new FakeParam();
    connect() {}
    disconnect() {}
  }
  class FakeOscillator {
    type = "sine";
    frequency = { value: 0 };
    onended = null;
    connect() {}
    disconnect() {}
    start() {}
    stop() { queueMicrotask(() => this.onended?.()); }
  }
  class FakeAudioContext {
    state = "running";
    currentTime = 0;
    destination = {};
    constructor() { contextCount += 1; }
    createGain() { return new FakeGain(); }
    createOscillator() { return new FakeOscillator(); }
    resume() { return Promise.resolve(); }
  }

  const previousWindow = globalThis.window;
  globalThis.window = { AudioContext: FakeAudioContext };

  try {
    const { AudioManager } = await import(moduleUrl);
    const audio = new AudioManager();
    for (let index = 0; index < 100; index += 1) {
      audio.playSfx({ frequency: 220 + index, duration: 0.01, volume: 0.01 });
    }
    await new Promise((resolve) => setImmediate(resolve));
    assert.equal(contextCount, 1);
  } finally {
    if (previousWindow === undefined) delete globalThis.window;
    else globalThis.window = previousWindow;
  }
});
