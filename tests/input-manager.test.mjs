import assert from "node:assert/strict";
import fs from "node:fs";
import test from "node:test";
import ts from "typescript";

const source = fs.readFileSync(new URL("../game/input/InputManager.ts", import.meta.url), "utf8");
const compiled = ts.transpileModule(source, {
  compilerOptions: {
    module: ts.ModuleKind.ES2022,
    target: ts.ScriptTarget.ES2022,
  },
}).outputText;
const moduleUrl = `data:text/javascript;base64,${Buffer.from(compiled).toString("base64")}`;
const { InputManager } = await import(moduleUrl);

test("InputManager keeps movement state per external source", () => {
  const input = new InputManager();
  input.activate("race");

  input.setExternalAction("touch-left", "left", true);
  assert.equal(input.isPressed("left"), true);

  input.setExternalAction("gamepad:0", "left", true);
  input.setExternalAction("touch-left", "left", false);
  assert.equal(input.isPressed("left"), true);

  input.releaseSource("gamepad:0");
  assert.equal(input.isPressed("left"), false);
  input.reset();
});

test("InputManager dispatches actions only to the active context", () => {
  const input = new InputManager();
  const calls = [];
  const releaseRace = input.activate("race", {
    onJump: () => calls.push("race:jump"),
    onSkill: () => calls.push("race:skill"),
  });

  input.trigger("jump");
  input.trigger("skill");
  assert.deepEqual(calls, ["race:jump", "race:skill"]);

  input.activate("arena", { onJump: () => calls.push("arena:jump") });
  releaseRace();
  input.trigger("jump");
  assert.equal(input.getActiveContextId(), "arena");
  assert.deepEqual(calls, ["race:jump", "race:skill", "arena:jump"]);
  input.reset();
});
