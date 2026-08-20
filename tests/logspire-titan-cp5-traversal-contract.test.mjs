import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const guard = readFileSync("godot/modes/logspire_leap/logspire_titan_cp5_corridor_guard.gd", "utf8");
const audit = readFileSync("godot/modes/logspire_leap/logspire_jump_collision_reliability_v2_route_connectors.gd", "utf8");
const phase3 = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v7_finale_log_collision.gd", "utf8");
const phase3V6 = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v6_titan_tree_safe.gd", "utf8");

function functionSlice(source, name, nextName) {
  const start = source.indexOf(`func ${name}`);
  assert.ok(start >= 0, `missing function ${name}`);
  const end = nextName ? source.indexOf(`func ${nextName}`, start + 1) : source.length;
  return source.slice(start, end >= 0 ? end : source.length);
}

test("Round 3 production wires the V7 finale safety override over the tree-safe Phase3 director", () => {
  assert.match(scene, /logspire_phase3_director_v7_finale_log_collision\.gd/);
  assert.match(phase3, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v6_titan_tree_safe\.gd"/);
  assert.match(phase3V6, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v5_route_clearance\.gd"/);
  assert.match(phase3, /LOGSPIRE FINALE ROLLING LOG REMOVED/);
  assert.match(phase3, /_finale_roll_visual = null/);
  assert.match(phase3, /_finale_roll_area = null/);
  assert.match(phase3V6, /LOGSPIRE PHASE3 TREE SAFE READY/);
});

test("CP5 late Titan route has five explicit zero-speed traversal connectors", () => {
  const expectedPairs = [
    ["Z5_SPIRAL_06", "Z5_SPIRAL_07"],
    ["Z5_SPIRAL_07", "Z5_SPIRAL_08"],
    ["Z5_SPIRAL_08", "Z5_SPIRAL_09"],
    ["Z5_SPIRAL_09", "Z5_SPIRAL_10"],
    ["Z5_SPIRAL_10", "Z6_START"],
  ];
  for (const [from, to] of expectedPairs) {
    assert.ok(guard.includes(`&"${from}", &"${to}"`), `missing connector ${from} -> ${to}`);
  }
  assert.match(guard, /LATE_CONNECTOR_WIDTH: float = 5\.8/);
  assert.match(guard, /checkpoint_exit=true zero_speed_escape=true/);
});

test("CP5 connector enters physics with its local transform already assigned", () => {
  const fn = functionSlice(guard, "_build_late_titan_connectors", "_refresh_route_rotations");
  const transformIndex = fn.indexOf("body.transform = connector_root.global_transform.affine_inverse() * desired_global");
  const addIndex = fn.indexOf("connector_root.add_child(body)");
  assert.ok(transformIndex >= 0, "missing pre-add local transform");
  assert.ok(addIndex >= 0, "missing connector add_child");
  assert.ok(transformIndex < addIndex, "connector must be positioned before physics registration");
  assert.doesNotMatch(fn, /body\.global_position\s*=/);
});

test("collision audit accepts a tagged connector only for its authored route pair", () => {
  assert.match(audit, /logspire_route_connector/);
  assert.match(audit, /logspire_route_from/);
  assert.match(audit, /logspire_route_to/);
  assert.match(audit, /_pair_matches\(from_id, to_id, route_from, route_to\)/);
});

test("Titan and Woodpecker builders no longer write orphan global positions", () => {
  const titan = functionSlice(phase3V6, "_build_titan_tree", "_make_animatable_bridge");
  const woodpecker = functionSlice(phase3V6, "_build_woodpecker_hazard", "_build_wood_chip_multimesh");
  const chips = functionSlice(phase3V6, "_build_wood_chip_multimesh", "_build_squirrel_stampede");
  assert.doesNotMatch(titan, /\.global_position\s*=/);
  assert.doesNotMatch(woodpecker, /\.global_position\s*=/);
  assert.doesNotMatch(chips, /\.global_position\s*=/);
  assert.match(titan, /root\.to_local/);
  assert.match(woodpecker, /_world_local/);
});
