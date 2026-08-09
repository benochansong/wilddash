import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import ts from "typescript";

async function importTs(path) {
  const source = readFileSync(path, "utf8");
  const transpiled = ts.transpileModule(source, {
    compilerOptions: {
      module: ts.ModuleKind.ESNext,
      target: ts.ScriptTarget.ES2022,
    },
  }).outputText;
  const url = `data:text/javascript;base64,${Buffer.from(transpiled).toString("base64")}`;
  return import(url);
}

const skills = await importTs("game/systems/skillSystem.ts");
const items = await importTs("game/systems/itemSystem.ts");
const collisions = await importTs("game/systems/collisionSystem.ts");
const ranking = await importTs("game/systems/rankingSystem.ts");
const rounds = await importTs("game/systems/roundSystem.ts");
const difficulty = await importTs("game/config/difficulty.ts");
const animals = await importTs("game/config/animals.ts");

test("animal skill cooldowns tick down and never become negative", () => {
  assert.equal(skills.tickCooldown(5, 1.25), 3.75);
  assert.equal(skills.tickCooldown(0.2, 1), 0);
  assert.equal(skills.canUseSkill(0), true);
  assert.equal(skills.canUseSkill(0.01), false);

  assert.deepEqual(
    Object.fromEntries(Object.entries(animals.ANIMALS).map(([key, value]) => [key, value.cooldown])),
    { dog: 10, rabbit: 7, elephant: 9, cat: 8 },
  );
  assert.deepEqual(
    Object.fromEntries(Object.entries(animals.RACE3D_SKILLS).map(([key, value]) => [key, value.cooldown])),
    { dog: 12, rabbit: 8, elephant: 10, cat: 9 },
  );
});

test("race item acquisition uses comeback pool and item use consumes held item", () => {
  assert.equal(items.selectRace3DItem(31, 0), "shield");
  assert.equal(items.selectRace3DItem(31, 1), "magnet");
  assert.equal(items.selectRace3DItem(12, 0), "banana");
  assert.equal(items.selectRace3DItem(12, 3), "magnet");
  assert.equal(items.consumeItem("ink"), "ink");
  assert.equal(items.consumeItem(null), null);
});

test("collision predicates respect race and arena hit thresholds", () => {
  assert.equal(collisions.isRaceCollision(1000, 1080, 10, 60), true);
  assert.equal(collisions.isRaceCollision(1000, 1090, 10, 60), false);
  assert.equal(collisions.isRaceCollision(1000, 1080, 10, 62), false);
  assert.equal(collisions.isArenaContact(50, 50, 55, 55), true);
  assert.equal(collisions.isArenaContact(50, 50, 58, 50), false);
});

test("ranking counts only rivals ahead of the player", () => {
  const rivals = [{ s: 120 }, { s: 99 }, { s: 101 }, { s: 100 }];
  assert.equal(ranking.calculateRank(100, rivals), 3);
  assert.equal(ranking.calculateRank(1000, rivals), 1);
  assert.equal(ranking.calculateRank(0, rivals), 5);
});

test("round success and failure conditions preserve current rules", () => {
  assert.equal(rounds.isFruitRoundSuccess(7), false);
  assert.equal(rounds.isFruitRoundSuccess(8), true);
  assert.equal(rounds.isSurvivalRoundFailure(1), false);
  assert.equal(rounds.isSurvivalRoundFailure(0), true);
  assert.equal(rounds.isFinalPlayerEliminated(48), false);
  assert.equal(rounds.isFinalPlayerEliminated(48.01), true);
  assert.equal(rounds.isFinalRoundSuccess(1), false);
  assert.equal(rounds.isFinalRoundSuccess(0), true);
  assert.deepEqual(rounds.resolveRoundTimeout("fruit", 6, 3, 4), { success: false, score: 6 });
  assert.deepEqual(rounds.resolveRoundTimeout("survival", 0, 2, 5), { success: true, score: 2 });
  assert.deepEqual(rounds.resolveRoundTimeout("final", 0, 3, 1), { success: false, score: 3 });
});

test("difficulty settings scale AI pressure in ascending order", () => {
  const { wild, chaos, nightmare } = difficulty.DIFFICULTIES;
  assert.ok(wild.aiSpeed < chaos.aiSpeed && chaos.aiSpeed < nightmare.aiSpeed);
  assert.ok(wild.aggression < chaos.aggression && chaos.aggression < nightmare.aggression);
  assert.ok(wild.collision < chaos.collision && chaos.collision < nightmare.collision);
  assert.deepEqual([wild.count, chaos.count, nightmare.count], [16, 19, 22]);
});
