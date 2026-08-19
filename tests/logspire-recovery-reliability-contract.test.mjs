import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const integrated = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v13_integrated_qa.gd", "utf8");
const authority = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v12_reliability_authority.gd", "utf8");
const water = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v10_surface_collision_guard.gd", "utf8");
const ladder = readFileSync("godot/modes/logspire_leap/logspire_ladder_system_v5_traversal_paths.gd", "utf8");
const swim = readFileSync("godot/modes/logspire_leap/logspire_swim_controller.gd", "utf8");
const recovery = readFileSync("godot/modes/logspire_leap/logspire_recovery_system.gd", "utf8");

test("Round 3 keeps stable V10/V12 recovery under the V13 QA guard and V5 ladder wiring", () => {
  assert.match(scene, /logspire_water_recovery_v13_integrated_qa\.gd/);
  assert.match(integrated, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v12_reliability_authority\.gd"/);
  assert.match(authority, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v10_surface_collision_guard\.gd"/);
  assert.match(scene, /logspire_ladder_system_v5_traversal_paths\.gd/);
  assert.match(water, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v9_priority_camera\.gd"/);
  assert.match(ladder, /extends "res:\/\/modes\/logspire_leap\/logspire_ladder_system_v4_safe_exit\.gd"/);
});

test("Submerged racers rise to the visible surface without vertical player input", () => {
  assert.match(water, /SUBMERGED_REACQUIRE_DEPTH: float = 0\.35/);
  assert.match(water, /SURFACE_LOCK_OFFSET: float = 0\.52/);
  assert.match(water, /SURFACE_ASCEND_SPEED: float = 9\.0/);
  assert.match(authority, /func _enforce_surface_lock/);
  assert.match(authority, /_find_safe_surface_position/);
  assert.match(authority, /LOGSPIRE SURFACE REACQUIRE/);
  assert.match(authority, /LOGSPIRE SURFACE BLOCKED/);
  assert.match(swim, /CROCODILE_SWIM_SPEED_RATIO: float = 1\.00/);
  assert.match(integrated, /surface_reacquire/);
  assert.match(integrated, /deep_water_fail/);
});

test("Recovery guidance is Root first, Ladder second", () => {
  const rootIndex = water.indexOf("var best_root: Dictionary");
  const ladderIndex = water.indexOf("var same_zone_ladders: Array");
  assert.ok(rootIndex >= 0, "missing Root selection");
  assert.ok(ladderIndex > rootIndex, "Ladder selection must follow Root selection");
  assert.match(water, /candidate\["recovery_type"\] = TARGET_ROOT/);
  assert.match(water, /candidate\["recovery_type"\] = TARGET_LADDER/);
  assert.match(water, /priority=ROOT/);
});

test("Ladder capture is generous, automatic, and does not require Jump", () => {
  assert.match(water, /LADDER_CAPTURE_HALF_WIDTH: float = 1\.50/);
  assert.match(water, /LADDER_CAPTURE_FRONT_METERS: float = 2\.50/);
  assert.match(water, /LADDER_CAPTURE_RADIAL_FALLBACK: float = 2\.20/);
  assert.match(water, /func _ladder_capture_candidate\(/);
  assert.match(water, /LOGSPIRE LADDER CAPTURE/);
  assert.match(water, /jump_required=false/);
  assert.match(water, /LADDER_ALIGN_RELIABLE_SECONDS: float = 0\.20/);
  assert.match(water, /LADDER_CLIMB_RELIABLE_MAX_SECONDS: float = 3\.00/);
});

test("Every major water basin has a broad Root recovery before Ladder fallback", () => {
  assert.match(ladder, /func _ensure_broad_root_ramp_per_basin\(\)/);
  assert.match(ladder, /Z3_05/);
  assert.match(ladder, /Z4_SAFE_03/);
  assert.match(ladder, /Z6_START/);
  assert.match(ladder, /LOGSPIRE BASIN ROOT READY/);
  assert.match(ladder, /root_first=true/);
  assert.match(ladder, /STAIR_WIDTH: float = 5\.6/);
});

test("Recovery reselects after one second without progress", () => {
  assert.match(water, /RECOVERY_STUCK_SECONDS: float = 1\.00/);
  assert.match(water, /RECOVERY_PROGRESS_METERS: float = 0\.18/);
  assert.match(water, /func _handle_recovery_stuck\(/);
  assert.match(water, /LOGSPIRE RECOVERY STUCK/);
  assert.match(water, /reselect=true/);
  assert.match(water, /stuck_watchdog/);
  assert.match(authority, /_blocked_targets_by_id/);
  assert.match(authority, /LOGSPIRE RECOVERY RETARGET/);
  assert.match(integrated, /recovery_stuck/);
});

test("Emergency Vine Rescue is bounded and remains a visible pull fail-safe", () => {
  assert.match(water, /VINE_RESCUE_TRIGGER_SECONDS: float = 4\.80/);
  assert.match(water, /VINE_RESCUE_DURATION: float = 1\.00/);
  assert.match(water, /RECOVERY_HARD_LIMIT_SECONDS: float = 7\.00/);
  assert.match(water, /func _begin_vine_rescue\(/);
  assert.match(water, /func _update_vine_rescue\(/);
  assert.match(water, /EmergencyVine_/);
  assert.match(water, /LOGSPIRE VINE RESCUE/);
  assert.match(water, /teleport=false/);
});

test("Water and checkpoint recovery both expose bounded SAFE_EXIT authority", () => {
  assert.match(integrated, /&"SAFE_EXIT"/);
  assert.match(integrated, /await get_tree\(\)\.physics_frame/);
  assert.match(recovery, /checkpoint_recovery_pending/);
  assert.match(recovery, /&"RECOVERY"/);
  assert.match(recovery, /&"SAFE_EXIT"/);
  assert.match(recovery, /checkpoint_safe_exit_complete/);
  assert.match(recovery, /await get_tree\(\)\.physics_frame/);
});

test("Required reliability telemetry remains available for manual playtest", () => {
  for (const marker of [
    "LOGSPIRE RECOVERY START",
    "LOGSPIRE ROOT RECOVERY SUCCESS",
    "LOGSPIRE LADDER CAPTURE",
    "LOGSPIRE LADDER SUCCESS",
    "LOGSPIRE RECOVERY STUCK",
    "LOGSPIRE VINE RESCUE",
  ]) {
    assert.ok(water.includes(marker), `missing telemetry: ${marker}`);
  }
  for (const marker of [
    "LOGSPIRE WATER ENTER",
    "LOGSPIRE SURFACE REACQUIRE",
    "LOGSPIRE SURFACE BLOCKED",
    "LOGSPIRE ROOT ATTACH",
    "LOGSPIRE LADDER ATTACH",
    "LOGSPIRE RECOVERY EXIT CLEAR",
    "LOGSPIRE RECOVERY RETARGET",
  ]) {
    assert.ok(authority.includes(marker), `missing V12 telemetry: ${marker}`);
  }
  for (const metric of [
    "water_enter",
    "surface_reacquire",
    "deep_water_fail",
    "root_success",
    "ladder_success",
    "recovery_stuck",
  ]) {
    assert.ok(integrated.includes(metric), `missing V13 metric: ${metric}`);
  }
});
