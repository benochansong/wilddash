import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const lower = readFileSync("godot/modes/logspire_leap/logspire_jump_gap_guard_v4_lower_route.gd", "utf8");
const world = readFileSync("godot/modes/logspire_leap/logspire_world_v3_titan_lower_route.gd", "utf8");

test("Round 3 production no longer inherits the Titan upper-flow bridge stack", () => {
  assert.match(scene, /logspire_jump_gap_guard_v4_lower_route\.gd/);
  assert.match(lower, /extends "res:\/\/modes\/logspire_leap\/logspire_jump_gap_guard\.gd"/);
  assert.doesNotMatch(scene, /logspire_jump_gap_guard_v2_titan_upper_flow\.gd/);
  assert.doesNotMatch(scene, /logspire_jump_gap_guard_v3_cp5_upper_landing\.gd/);
  assert.match(lower, /temporary_bridge_stack=false/);
  assert.match(lower, /upper_spiral_collision=false/);
});

test("CP4 to CP5 is the authored lower route with safe and fast choices", () => {
  for (const id of [
    "Z5_ROOT_RUN_01",
    "Z5_ROOT_RUN_02",
    "Z5_BROKEN_TRUNK_TAKEOFF",
    "Z5_BROKEN_TRUNK_LANDING",
    "Z5_FORK_SAFE_01",
    "Z5_FORK_SAFE_02",
    "Z5_CANOPY_01",
    "Z5_CANOPY_02",
    "Z5_CANOPY_03",
    "Z5_CANOPY_04",
    "Z5_FINAL_TAKEOFF",
    "Z5_FINAL_LANDING",
  ]) {
    assert.match(lower, new RegExp(id));
  }
  for (const id of ["Z5_FORK_FAST_01", "Z5_FORK_FAST_02", "Z5_FORK_FAST_03"]) {
    assert.match(world, new RegExp(id));
  }
  assert.match(world, /_rebuild_wild_suffix_for_fast_fork/);
});

test("lower-route rebuild keeps honest movement and isolates future water", () => {
  assert.match(lower, /BROKEN_TRUNK_GAP: float = 4\.6/);
  assert.match(lower, /FINAL_ROOT_GAP: float = 5\.0/);
  assert.match(lower, /future_water_moved_with_finale=true/);
  assert.match(lower, /jump_power_unchanged=true/);
  assert.match(lower, /teleport=false/);
  assert.match(lower, /checkpoint_skip=false/);
  assert.doesNotMatch(lower, /reset_motion/);
  assert.doesNotMatch(lower, /checkpoint_progress\s*=/);
});
