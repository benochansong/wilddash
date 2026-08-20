import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const treeSafe = readFileSync("godot/modes/logspire_leap/logspire_platform_gameplay_v2_tree_safe.gd", "utf8");

function sliceFunction(name, nextName) {
  const start = treeSafe.indexOf(`func ${name}`);
  assert.ok(start >= 0, `missing function ${name}`);
  const end = nextName ? treeSafe.indexOf(`func ${nextName}`, start + 1) : treeSafe.length;
  return treeSafe.slice(start, end >= 0 ? end : treeSafe.length);
}

function assertAddBeforeGlobalPosition(source, addText, globalText, label) {
  const add = source.indexOf(addText);
  const global = source.indexOf(globalText);
  assert.ok(add >= 0, `${label}: missing add_child`);
  assert.ok(global >= 0, `${label}: missing global_position assignment`);
  assert.ok(add < global, `${label}: node must enter SceneTree before global_position`);
}

test("Round 3 production wires tree-safe platform gameplay", () => {
  assert.match(scene, /logspire_platform_gameplay_v2_tree_safe\.gd/);
  assert.match(treeSafe, /extends "res:\/\/modes\/logspire_leap\/logspire_platform_gameplay\.gd"/);
  assert.match(treeSafe, /LOGSPIRE PLATFORM TREE ORDER READY/);
});

test("Rolling Grove log replacement enters the tree before global transform", () => {
  const fn = sliceFunction("_make_log_body", "_make_box_body");
  assertAddBeforeGlobalPosition(fn, "_world.add_child(body)", "body.global_position =", "rolling log");
});

test("Rolling Grove balance and cracking replacements enter the tree before global transform", () => {
  const fn = sliceFunction("_make_box_body", "_build_mushroom");
  assertAddBeforeGlobalPosition(fn, "_world.add_child(body)", "body.global_position =", "box platform");
});

test("Mushroom trigger and visual enter the tree before global transforms", () => {
  const fn = sliceFunction("_build_mushroom", "_build_vine");
  assertAddBeforeGlobalPosition(fn, "_world.add_child(area)", "area.global_position =", "mushroom area");
  assertAddBeforeGlobalPosition(fn, "_world.add_child(cap)", "cap.global_position =", "mushroom visual");
});

test("Vine trigger and visual enter the tree before global transforms", () => {
  const fn = sliceFunction("_build_vine", null);
  assertAddBeforeGlobalPosition(fn, "_world.add_child(area)", "area.global_position =", "vine area");
  assertAddBeforeGlobalPosition(fn, "_world.add_child(vine)", "vine.global_position =", "vine visual");
});
