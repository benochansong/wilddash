import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const ladderV5 = readFileSync("godot/modes/logspire_leap/logspire_ladder_system_v5_traversal_paths.gd", "utf8");
const ladderV6 = readFileSync("godot/modes/logspire_leap/logspire_ladder_system_v6_vine_only_cleanup.gd", "utf8");
const waterV10 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v10_surface_collision_guard.gd", "utf8");
const vineV15 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v15_vine_only.gd", "utf8");
const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");

test("Production Round 3 retires recovery stairs and ladders in favor of Vine Rescue", () => {
  assert.match(scene, /logspire_ladder_system_v6_vine_only_cleanup\.gd/);
  assert.match(scene, /logspire_water_recovery_v15_vine_only\.gd/);
  assert.match(ladderV6, /extends "res:\/\/modes\/logspire_leap\/logspire_ladder_system_v5_traversal_paths\.gd"/);
  assert.match(ladderV6, /_ladders\.clear\(\)/);
  assert.match(ladderV6, /_root_ramps\.clear\(\)/);
  assert.match(ladderV6, /collision_layer = 0/);
  assert.match(ladderV6, /queue_free\(\)/);
  assert.match(vineV15, /VINE_ONLY_CAPTURE_DELAY_SECONDS: float = 0\.22/);
  assert.match(vineV15, /ladder=false stairs=false/);
});

test("Legacy recovery stair geometry remains preserved only for rollback", () => {
  assert.match(ladderV5, /STAIR_MAX_RISE: float = 0\.48/);
  assert.match(ladderV5, /STAIR_WIDTH: float = 5\.6/);
  assert.match(ladderV5, /RecoveryStairSlope_/);
  assert.match(ladderV5, /logspire_recovery_stair/);
  assert.match(ladderV5, /continuous_collision=true/);
  assert.match(ladderV5, /ceil\(vertical_height \/ STAIR_MAX_RISE\)/);
});

test("Legacy high recovery exits remain preserved for rollback", () => {
  assert.match(ladderV5, /HIGH_DECK_OUTWARD_SHIFT: float = 3\.8/);
  assert.match(ladderV5, /HIGH_CLEAR_DECK_SIZE := Vector3\(12\.0, 0\.45, 12\.0\)/);
  assert.match(ladderV5, /EXIT_FORWARD_CLEARANCE_METERS: float = 5\.0/);
  assert.match(ladderV5, /EXIT_HEAD_CLEARANCE_METERS: float = 3\.2/);
  assert.match(ladderV5, /safe_exit := Vector3\(new_deck_center\.x, platform_position\.y \+ 1\.15, new_deck_center\.z\)/);
  assert.match(ladderV5, /LOGSPIRE RECOVERY EXIT AUDIT/);
});

test("Legacy stair traversal source remains available without production authority", () => {
  assert.match(waterV10, /STAIR_AUTO_ATTACH_RADIUS: float = 1\.5/);
  assert.match(waterV10, /STAIR_CLIMB_SPEED_MPS: float = 3\.4/);
  assert.match(waterV10, /target_distance <= STAIR_AUTO_ATTACH_RADIUS/);
  assert.match(waterV10, /_begin_root_climb\(racer, target\)/);
  assert.match(waterV10, /_apply_ai_recovery_swim\(racer, target, water_y, delta\)/);
  assert.match(waterV10, /_set_ux_state\(racer, RecoveryUXState\.ROOT_APPROACH\)/);
  assert.match(waterV10, /LOGSPIRE STAIR ATTACH/);
  assert.match(waterV10, /LOGSPIRE STAIR CLIMB/);
  assert.match(waterV10, /LOGSPIRE STAIR EXIT/);
});

test("Legacy blocked recovery paths still fail safely back to swimming", () => {
  assert.match(waterV10, /LOGSPIRE RECOVERY PATH BLOCKED/);
  assert.match(waterV10, /_state_by_id\[racer_id\] = WaterState\.SWIMMING/);
  assert.match(waterV10, /_set_traversal_action_lock\(racer, false\)/);
  assert.match(waterV10, /MAJOR_BLOCKED_SCORE_PENALTY: float = 1000\.0/);
});
