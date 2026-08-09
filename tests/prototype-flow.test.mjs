import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";
import ts from "typescript";

const source = readFileSync("game/systems/flowSystem.ts", "utf8");
const compiled = ts.transpileModule(source, {
  compilerOptions: {
    module: ts.ModuleKind.ESNext,
    target: ts.ScriptTarget.ES2022,
  },
}).outputText;
const moduleUrl = `data:text/javascript;base64,${Buffer.from(compiled).toString("base64")}`;
const flow = await import(moduleUrl);

test("prototype v1 successful run follows the four-round flow", () => {
  for (let run = 0; run < 100; run += 1) {
    assert.equal(flow.entryScreen(true), "pick");
    assert.equal(flow.screenAfterRace(25), "roundBreak");
    assert.equal(flow.roundClearedAfterRace(25), 1);
    assert.equal(flow.nextRoundAfterBreak(1), "fruit");

    const fruit = flow.arenaFlowOutcome("fruit", true);
    assert.deepEqual(fruit, {
      screen: "roundBreak",
      roundCleared: 2,
      failureRank: null,
      champion: false,
    });
    assert.equal(flow.nextRoundAfterBreak(fruit.roundCleared), "survival");

    const survival = flow.arenaFlowOutcome("survival", true);
    assert.equal(survival.screen, "roundBreak");
    assert.equal(survival.roundCleared, 3);
    assert.equal(flow.nextRoundAfterBreak(survival.roundCleared), "final");

    const final = flow.arenaFlowOutcome("final", true);
    assert.equal(final.screen, "result");
    assert.equal(final.roundCleared, 4);
    assert.equal(final.champion, true);
  }
});

test("prototype v1 routes race and arena failures directly to result", () => {
  assert.equal(flow.entryScreen(false), "tutorial");
  assert.equal(flow.screenAfterRace(26), "result");
  assert.equal(flow.roundClearedAfterRace(26), 0);
  assert.deepEqual(flow.arenaFlowOutcome("fruit", false), {
    screen: "result",
    roundCleared: 0,
    failureRank: 26,
    champion: false,
  });
  assert.equal(flow.arenaFlowOutcome("survival", false).failureRank, 11);
  assert.equal(flow.arenaFlowOutcome("final", false).failureRank, 2);
});
