import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync, readdirSync } from "node:fs";
import { join } from "node:path";

const read = (path) => readFileSync(path, "utf8");

function sourceFiles(root) {
  if (!existsSync(root)) return [];
  return readdirSync(root, { withFileTypes: true }).flatMap((entry) => {
    const path = join(root, entry.name);
    if (entry.isDirectory()) return sourceFiles(path);
    return /\.(ts|tsx)$/.test(entry.name) ? [path] : [];
  });
}

test("game architecture modules exist", () => {
  for (const path of [
    "game/types/game.ts",
    "game/config/animals.ts",
    "game/config/items.ts",
    "game/config/difficulty.ts",
    "game/config/race.ts",
    "game/systems/aiSystem.ts",
    "game/systems/raceSystem.ts",
    "game/systems/collisionSystem.ts",
    "game/systems/rankingSystem.ts",
    "game/save/SaveManager.ts",
    "ui/components/Chimera.tsx",
  ]) assert.equal(existsSync(path), true, `${path} should exist`);
});

test("page delegates configuration and save responsibilities", () => {
  const page = read("app/page.tsx");
  assert.equal(page.includes("const ANIMALS:"), false);
  assert.equal(page.includes("function createRace("), false);
  assert.equal(page.includes("localStorage."), false);
  assert.equal(page.includes("../game/config/animals"), true);
  assert.equal(page.includes("../game/save/SaveManager"), true);
  assert.equal(page.includes("../ui/components/Chimera"), true);
});

test("UI source does not access localStorage directly", () => {
  for (const path of [...sourceFiles("app"), ...sourceFiles("ui")]) {
    assert.equal(read(path).includes("localStorage."), false, `${path} should delegate persistence to SaveManager`);
  }
});

test("Race3D delegates pure race calculations", () => {
  const race = read("app/Race3D.tsx");
  assert.equal(race.includes("const LENGTH=24000"), false);
  assert.equal(race.includes("Array.from({length:49}"), false);
  assert.equal(race.includes("calculateRank("), true);
  assert.equal(race.includes("createRace3DState("), true);
  assert.equal(race.includes("obstacleLateral("), true);
});
