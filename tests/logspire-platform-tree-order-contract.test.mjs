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

function assertTransformBeforeAdd(source, transformText, addText, label) {
  const transform = source.indexOf(transformText);
  const add = source.indexOf(addText);
  assert.ok(transform >= 0, `${label}: missing pre-tree transform`);
  assert.ok(add >= 0, `${label}: missing add_child`);
  assert.ok(transform < add, `${label}: local transform must be set before SceneTree registration`);
}

test("Round 3 production wires tree-safe platform gameplay", () => {
  assert.match(scene, /logspire_platform_gameplay_v2_tree_safe\.gd/);
  assert.match(treeSafe, /extends "res:\/\/modes\/logspire_leap\/logspire_platform_gameplay\.gd"/);
  assert.match(treeSafe, /LOGSPIRE PLATFORM TREE ORDER READY/);
  assert.match(treeSafe, /first_physics_transform_valid=true/);
});

test("Rolling Grove moving bodies register at their authored transform on the first physics frame", () => {
  const logBody = sliceFunction("_make_log_body", "_make_box_body");
  const boxBody = sliceFunction("_make_box_body", "_build_mushroom");
  assertTransformBeforeAdd(logBody, "body.transform = _local_transform_for", "_world.add_child(body)", "rolling log");
  assertTransformBeforeAdd(boxBody, "body.transform = _local_transform_for", "_world.add_child(body)", "box platform");
  assert.doesNotMatch(logBody, /body\.global_position\s*=/);
  assert.doesNotMatch(boxBody, /body\.global_position\s*=/);
});

test("Mushroom trigger and visual use parent-local coordinates before registration", () => {
  const fn = sliceFunction("_build_mushroom", "_build_vine");
  assertTransformBeforeAdd(fn, "area.position = _local_position_for", "_world.add_child(area)", "mushroom area");
  assertTransformBeforeAdd(fn, "cap.position = _local_position_for", "_world.add_child(cap)", "mushroom visual");
  assert.doesNotMatch(fn, /\.global_position\s*=/);
});

test("Vine trigger and visual use parent-local coordinates before registration", () => {
  const fn = sliceFunction("_build_vine", null);
  assertTransformBeforeAdd(fn, "area.position = _local_position_for", "_world.add_child(area)", "vine area");
  assertTransformBeforeAdd(fn, "vine.position = _local_position_for", "_world.add_child(vine)", "vine visual");
  assert.doesNotMatch(fn, /\.global_position\s*=/);
});
