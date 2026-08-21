import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const flow = readFileSync("godot/modes/logspire_leap/logspire_jump_gap_guard_v2_titan_upper_flow.gd", "utf8");
const base = readFileSync("godot/modes/logspire_leap/logspire_jump_gap_guard.gd", "utf8");
const audit = readFileSync("godot/modes/logspire_leap/logspire_jump_collision_reliability.gd", "utf8");

test("Round 3 production uses the upper Titan continuous-flow guard", () => {
  assert.match(scene, /logspire_jump_gap_guard_v2_titan_upper_flow\.gd/);
  assert.match(flow, /extends "res:\/\/modes\/logspire_leap\/logspire_jump_gap_guard\.gd"/);
  assert.match(flow, /TITAN_UPPER_FLOW_WIDTH: float = 7\.2/);
  assert.match(flow, /continuous_walkable=true/);
  assert.match(flow, /collision_backed=true/);
});

test("CP5 through Z6 start receives a physical bridge on every upper transition", () => {
  const expectedPairs = [
    ["Z5_SPIRAL_03", "Z5_SPIRAL_04"],
    ["Z5_SPIRAL_04", "Z5_SPIRAL_05"],
    ["Z5_SPIRAL_05", "Z5_SPIRAL_06"],
    ["Z5_SPIRAL_06", "Z5_SPIRAL_07"],
    ["Z5_SPIRAL_07", "Z5_SPIRAL_08"],
    ["Z5_SPIRAL_08", "Z5_SPIRAL_09"],
    ["Z5_SPIRAL_09", "Z5_SPIRAL_10"],
    ["Z5_SPIRAL_10", "Z6_START"],
  ];
  for (const [from, to] of expectedPairs) {
    assert.match(flow, new RegExp(`&"${from}"\\s*,\\s*&"${to}"`));
  }
  assert.match(flow, /_build_flow_bridge\(from_id, to_id, TITAN_UPPER_FLOW_WIDTH, positions\)/);
  assert.match(base, /bridge\.name = "SafeFlowBridge_%s_%s"/);
  assert.match(base, /StaticBody3D\.new\(\)/);
  assert.match(base, /BoxShape3D\.new\(\)/);
});

test("upper-flow repair does not cheat movement or checkpoints", () => {
  assert.doesNotMatch(flow, /reset_motion/);
  assert.doesNotMatch(flow, /global_position\s*=/);
  assert.doesNotMatch(flow, /checkpoint_progress/);
  assert.doesNotMatch(flow, /jump_velocity\s*=/);
  assert.match(flow, /route_points_unchanged=true/);
  assert.match(flow, /jump_power_unchanged=true/);
  assert.match(flow, /teleport=false/);
});

test("jump collision audit treats the new pair bridges as expected support geometry", () => {
  assert.match(audit, /SafeFlowBridge_%s_%s/);
  assert.match(audit, /node_name == bridge_a or node_name == bridge_b/);
});
