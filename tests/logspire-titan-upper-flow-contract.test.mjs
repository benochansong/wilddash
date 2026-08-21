import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const flowV3 = readFileSync("godot/modes/logspire_leap/logspire_jump_gap_guard_v3_cp5_upper_landing.gd", "utf8");
const flowV2 = readFileSync("godot/modes/logspire_leap/logspire_jump_gap_guard_v2_titan_upper_flow.gd", "utf8");
const base = readFileSync("godot/modes/logspire_leap/logspire_jump_gap_guard.gd", "utf8");
const audit = readFileSync("godot/modes/logspire_leap/logspire_jump_collision_reliability.gd", "utf8");

test("Round 3 production uses the CP5 upper-landing guard layered over Titan continuous flow", () => {
  assert.match(scene, /logspire_jump_gap_guard_v3_cp5_upper_landing\.gd/);
  assert.match(flowV3, /extends "res:\/\/modes\/logspire_leap\/logspire_jump_gap_guard_v2_titan_upper_flow\.gd"/);
  assert.match(flowV2, /extends "res:\/\/modes\/logspire_leap\/logspire_jump_gap_guard\.gd"/);
  assert.match(flowV2, /TITAN_UPPER_FLOW_WIDTH: float = 7\.2/);
  assert.match(flowV2, /continuous_walkable=true/);
  assert.match(flowV2, /collision_backed=true/);
  assert.match(flowV3, /CP5_BRIDGE_WIDTH: float = 9\.6/);
  assert.match(flowV3, /CP5UpperLandingShelf/);
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
    assert.match(flowV2, new RegExp(`&"${from}"\\s*,\\s*&"${to}"`));
  }
  assert.match(flowV2, /_build_flow_bridge\(from_id, to_id, TITAN_UPPER_FLOW_WIDTH, positions\)/);
  assert.match(base, /bridge\.name = "SafeFlowBridge_%s_%s"/);
  assert.match(base, /StaticBody3D\.new\(\)/);
  assert.match(base, /BoxShape3D\.new\(\)/);
});

test("upper-flow repair does not cheat movement or checkpoints", () => {
  for (const source of [flowV2, flowV3]) {
    assert.doesNotMatch(source, /reset_motion/);
    assert.doesNotMatch(source, /checkpoint_progress/);
    assert.doesNotMatch(source, /jump_velocity\s*=/);
    assert.match(source, /teleport=false/);
  }
  assert.doesNotMatch(flowV2, /global_position\s*=/);
  assert.match(flowV2, /route_points_unchanged=true/);
  assert.match(flowV2, /jump_power_unchanged=true/);
  assert.match(flowV3, /jump_required=false/);
});

test("jump collision audit treats the pair bridges as expected support geometry", () => {
  assert.match(audit, /SafeFlowBridge_%s_%s/);
  assert.match(audit, /node_name == bridge_a or node_name == bridge_b/);
});
