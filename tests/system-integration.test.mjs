import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const race = readFileSync("app/Race3D.tsx", "utf8");
const arena = readFileSync("app/ArenaRound.tsx", "utf8");

test("Race3D delegates testable cooldown, item, collision, and ranking rules", () => {
  for (const token of [
    "tickCooldown(",
    "canUseSkill(",
    "selectRace3DItem(",
    "consumeItem(",
    "isRaceCollision(",
    "calculateRank(",
  ]) assert.equal(race.includes(token), true, `Race3D should use ${token}`);
});

test("ArenaRound delegates collision and round outcome rules", () => {
  for (const token of [
    "isArenaContact(",
    "isFruitRoundSuccess(",
    "isSurvivalRoundFailure(",
    "isFinalPlayerEliminated(",
    "isFinalRoundSuccess(",
    "resolveRoundTimeout(",
  ]) assert.equal(arena.includes(token), true, `ArenaRound should use ${token}`);
});
