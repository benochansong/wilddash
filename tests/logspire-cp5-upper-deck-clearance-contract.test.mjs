import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const rebalance = readFileSync("godot/modes/logspire_leap/logspire_jump_rebalance_v4_cp5_outer_clearance.gd", "utf8");
const gapGuard = readFileSync("godot/modes/logspire_leap/logspire_jump_gap_guard_v3_cp5_upper_landing.gd", "utf8");

test("production R3 uses the CP5 outer-clearance and upper-landing layers", () => {
  assert.match(scene, /logspire_jump_rebalance_v4_cp5_outer_clearance\.gd/);
  assert.match(scene, /logspire_jump_gap_guard_v3_cp5_upper_landing\.gd/);
});

test("CP5+ Titan route is opened before PlatformGraph consumes route positions", () => {
  assert.match(rebalance, /Z5_SPIRAL_06/);
  assert.match(rebalance, /Z5_SPIRAL_07/);
  assert.match(rebalance, /Z5_SPIRAL_08/);
  assert.match(rebalance, /CP5 OUTER CLEARANCE READY/);
  assert.match(rebalance, /ai_route_synced=true/);
  assert.match(rebalance, /jump_power_unchanged=true/);
  assert.doesNotMatch(rebalance, /global_position\s*=\s*[^\n]*player/);
});

test("CP5 to Z5_SPIRAL_07 has a widened connector and collision-backed landing shelf", () => {
  assert.match(gapGuard, /CP5_CLIMB_FROM: StringName = &"Z5_SPIRAL_06"/);
  assert.match(gapGuard, /CP5_CLIMB_TO: StringName = &"Z5_SPIRAL_07"/);
  assert.match(gapGuard, /CP5_BRIDGE_WIDTH: float = 9\.6/);
  assert.match(gapGuard, /CP5UpperLandingShelf/);
  assert.match(gapGuard, /StaticBody3D\.new\(\)/);
  assert.match(gapGuard, /jump_required=false/);
  assert.match(gapGuard, /lip_snag=false/);
  assert.match(gapGuard, /teleport=false/);
});
