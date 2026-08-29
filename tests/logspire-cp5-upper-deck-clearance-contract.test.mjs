import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const world = readFileSync("godot/modes/logspire_leap/logspire_world_v3_titan_lower_route.gd", "utf8");
const gapGuard = readFileSync("godot/modes/logspire_leap/logspire_jump_gap_guard_v4_lower_route.gd", "utf8");

test("production R3 retires the CP5 upper-deck repair stack", () => {
  assert.match(scene, /logspire_world_v3_titan_lower_route\.gd/);
  assert.match(scene, /logspire_jump_rebalance_v3_titan_tree_accessibility\.gd/);
  assert.match(scene, /logspire_jump_gap_guard_v4_lower_route\.gd/);
  assert.doesNotMatch(scene, /logspire_jump_rebalance_v4_cp5_outer_clearance\.gd/);
  assert.doesNotMatch(scene, /logspire_jump_gap_guard_v3_cp5_upper_landing\.gd/);
});

test("legacy Z5 upper spiral ids are renamed before production geometry is built", () => {
  for (const id of [
    "Z5_ROOT_RUN_01",
    "Z5_BROKEN_TRUNK_TAKEOFF",
    "Z5_BROKEN_TRUNK_LANDING",
    "Z5_FORK_SAFE_01",
    "Z5_CANOPY_01",
    "Z5_FINAL_TAKEOFF",
    "Z5_FINAL_LANDING",
  ]) {
    assert.match(world, new RegExp(id));
  }
  assert.match(world, /LEGACY_TO_LOWER_ID/);
  assert.match(world, /_rename_legacy_upper_route/);
  assert.match(world, /titan_upper_spiral_playable/);
  assert.match(world, /false/);
});

test("new CP5 belongs to the wide final landing instead of the old upper spiral", () => {
  assert.match(world, /_checkpoint_ids\[4\] = &"Z5_FINAL_LANDING"/);
  assert.match(gapGuard, /FINAL_LANDING_WIDTH: float = 16\.0/);
  assert.match(gapGuard, /FINAL_ROOT_GAP: float = 5\.0/);
  assert.match(gapGuard, /jump_power_unchanged=true/);
  assert.match(gapGuard, /teleport=false/);
  assert.match(gapGuard, /checkpoint_skip=false/);
});
