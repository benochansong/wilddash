import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import ts from "typescript";

const source = readFileSync("game/save/SaveManager.ts", "utf8");
const transpiled = ts.transpileModule(source, {
  compilerOptions: {
    module: ts.ModuleKind.ESNext,
    target: ts.ScriptTarget.ES2022,
    useDefineForClassFields: false,
  },
}).outputText;
const moduleUrl = `data:text/javascript;base64,${Buffer.from(transpiled).toString("base64")}`;
const {
  SaveManager,
  SAVE_KEY,
  SAVE_VERSION,
  DEFAULT_PROFILE,
  DEFAULT_SETTINGS,
} = await import(moduleUrl);

class MemoryStorage {
  constructor(entries = {}, { failWrites = false } = {}) {
    this.values = new Map(Object.entries(entries));
    this.failWrites = failWrites;
  }

  getItem(key) {
    return this.values.has(key) ? this.values.get(key) : null;
  }

  setItem(key, value) {
    if (this.failWrites) throw new Error("storage full");
    this.values.set(key, String(value));
  }

  removeItem(key) {
    this.values.delete(key);
  }
}

test("SaveManager migrates legacy profile, settings, and tutorial data to v1", () => {
  const storage = new MemoryStorage({
    "wild-dash-profile": JSON.stringify({ fans: 1234, wins: 7, best: 3 }),
    "wild-dash-settings": JSON.stringify({
      sound: false,
      haptics: false,
      reducedMotion: true,
      highContrast: true,
      largeTouch: false,
    }),
    "wild-dash-tutorial": "done",
  });

  const save = new SaveManager(storage).load();

  assert.equal(save.version, SAVE_VERSION);
  assert.deepEqual(save.profile, { fans: 1234, wins: 7, best: 3 });
  assert.deepEqual(save.settings, {
    sound: false,
    haptics: false,
    reducedMotion: true,
    highContrast: true,
    largeTouch: false,
  });
  assert.equal(save.tutorialCompleted, true);
  assert.deepEqual(save.unlocks, { characters: [] });
  assert.deepEqual(save.records, {});

  const persisted = JSON.parse(storage.getItem(SAVE_KEY));
  assert.equal(persisted.version, SAVE_VERSION);
  assert.equal(storage.getItem("wild-dash-profile"), null);
  assert.equal(storage.getItem("wild-dash-settings"), null);
  assert.equal(storage.getItem("wild-dash-tutorial"), null);
});

test("SaveManager repairs corrupt JSON with defaults without throwing", () => {
  const storage = new MemoryStorage({ [SAVE_KEY]: "{broken-json" });
  const manager = new SaveManager(storage);

  let save;
  assert.doesNotThrow(() => {
    save = manager.load();
  });

  assert.deepEqual(save.profile, DEFAULT_PROFILE);
  assert.deepEqual(save.settings, DEFAULT_SETTINGS);
  assert.equal(save.tutorialCompleted, false);
  assert.equal(JSON.parse(storage.getItem(SAVE_KEY)).version, SAVE_VERSION);
});

test("SaveManager validates individual fields and preserves valid values", () => {
  const storage = new MemoryStorage({
    [SAVE_KEY]: JSON.stringify({
      version: 1,
      profile: { fans: -4, wins: 3.8, best: 999 },
      settings: {
        sound: "yes",
        haptics: false,
        reducedMotion: true,
        highContrast: 1,
        largeTouch: true,
      },
      tutorialCompleted: "done",
      unlocks: { characters: ["dog", "dog", " ", 4, "fox"] },
      records: { bestTime: 42.5, negative: -1, text: "bad" },
    }),
  });

  const save = new SaveManager(storage).load();

  assert.deepEqual(save.profile, { fans: 0, wins: 3, best: 50 });
  assert.deepEqual(save.settings, {
    sound: true,
    haptics: false,
    reducedMotion: true,
    highContrast: false,
    largeTouch: true,
  });
  assert.equal(save.tutorialCompleted, false);
  assert.deepEqual(save.unlocks, { characters: ["dog", "fox"] });
  assert.deepEqual(save.records, { bestTime: 42.5 });
});

test("SaveManager keeps gameplay alive when persistence writes fail", () => {
  const storage = new MemoryStorage({}, { failWrites: true });
  const manager = new SaveManager(storage);

  assert.doesNotThrow(() => manager.saveProfile({ fans: 10, wins: 1, best: 8 }));
  assert.doesNotThrow(() => manager.saveSettings(DEFAULT_SETTINGS));
  assert.doesNotThrow(() => manager.markTutorialComplete());
  assert.doesNotThrow(() => manager.saveUnlocks({ characters: ["dog"] }));
  assert.doesNotThrow(() => manager.saveRecord("race.bestTime", 99.5));
});

test("SaveManager does not overwrite data written by a future save version", () => {
  const future = JSON.stringify({ version: 99, profile: { fans: 9999 } });
  const storage = new MemoryStorage({ [SAVE_KEY]: future });
  const save = new SaveManager(storage).load();

  assert.deepEqual(save.profile, DEFAULT_PROFILE);
  assert.equal(storage.getItem(SAVE_KEY), future);
});

test("SaveManager resetToDefaults restores a complete v1 save", () => {
  const storage = new MemoryStorage();
  const manager = new SaveManager(storage);
  manager.saveProfile({ fans: 500, wins: 2, best: 5 });
  manager.markTutorialComplete();
  manager.saveUnlocks({ characters: ["dog", "rabbit"] });
  manager.saveRecord("race.bestTime", 88.2);

  const reset = manager.resetToDefaults();

  assert.equal(reset.version, SAVE_VERSION);
  assert.deepEqual(reset.profile, DEFAULT_PROFILE);
  assert.deepEqual(reset.settings, DEFAULT_SETTINGS);
  assert.equal(reset.tutorialCompleted, false);
  assert.deepEqual(reset.unlocks, { characters: [] });
  assert.deepEqual(reset.records, {});
});
