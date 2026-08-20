import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const watchdogBase = readFileSync("godot/modes/logspire_leap/logspire_water_submerge_watchdog.gd", "utf8");
const watchdogV2 = readFileSync("godot/modes/logspire_leap/logspire_water_submerge_watchdog_v2_route_support.gd", "utf8");
const watchdogV3 = readFileSync("godot/modes/logspire_leap/logspire_water_submerge_watchdog_v3_live_route_corridor.gd", "utf8");
const waterV16 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v16_route_corridor_authority.gd", "utf8");
const recovery = readFileSync("godot/modes/logspire_leap/logspire_recovery_system.gd", "utf8");

test("Round 3 production wires live-route watchdog V3 and water authority V16", () => {
  assert.match(scene, /logspire_water_submerge_watchdog_v3_live_route_corridor\.gd/);
  assert.match(scene, /logspire_water_recovery_v16_route_corridor_authority\.gd/);
  assert.match(scene, /\[node name="WaterSubmergeWatchdog" type="Node" parent="\."\]/);
  assert.match(watchdogV3, /extends "res:\/\/modes\/logspire_leap\/logspire_water_submerge_watchdog_v2_route_support\.gd"/);
  assert.match(waterV16, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v15_vine_only\.gd"/);
  assert.match(watchdogBase, /HARD_SUBMERGE_DEPTH: float = 0\.58/);
  assert.match(watchdogBase, /SUPPORTED_FLOOR_ESCAPE_DEPTH: float = 1\.20/);
  assert.match(watchdogBase, /HARD_SUBMERGE_CONFIRM_SECONDS: float = 0\.14/);
});

test("live Safe Route corridor protects jump seams even when foot rays miss", () => {
  assert.match(waterV16, /ROUTE_CORRIDOR_RADIUS: float = 7\.25/);
  assert.match(waterV16, /ROUTE_CORRIDOR_MAX_DROP: float = 3\.40/);
  assert.match(waterV16, /get_route_ids", &"safe"/);
  assert.match(waterV16, /get_platform_position/);
  assert.match(waterV16, /var sample: Vector3 = a\.lerp\(b, t\)/);
  assert.match(waterV16, /best_planar_distance <= ROUTE_CORRIDOR_RADIUS/);
  assert.match(waterV16, /below_route <= ROUTE_CORRIDOR_MAX_DROP/);
  assert.match(watchdogV3, /is_route_corridor_protected/);
  assert.match(watchdogV3, /LiveRouteCorridor/);
});

test("WaterRecovery itself cannot seize transform authority inside the live route corridor", () => {
  assert.match(waterV16, /func _is_real_water_entry/);
  assert.match(waterV16, /func should_handle_racer/);
  assert.match(waterV16, /func _enter_water/);
  assert.match(waterV16, /LOGSPIRE ROUTE WATER SUPPRESSED/);
  assert.match(waterV16, /racing_authority=true/);
  assert.match(waterV16, /return super\(racer, water_y\)/);
  assert.match(waterV16, /super\(racer, zone, water_y\)/);
});

test("physical Safe Route support remains a higher-priority stale-pool guard", () => {
  const routeGuard = watchdogV2.indexOf("var route_support: Dictionary = _route_support_hit(racer)");
  const hiddenFloorGuard = watchdogV2.indexOf("var has_surface_support: bool = _has_surface_support(racer)");
  assert.ok(routeGuard >= 0 && hiddenFloorGuard > routeGuard, "route support must be checked before hidden-floor invalidation");
  assert.match(watchdogV2, /LOGSPIRE WATER RESET SUPPRESSED/);
  assert.match(watchdogV2, /route_support=true stale_pool_overlap=true/);
  assert.match(watchdogV2, /logspire_route_connector/);
  assert.match(watchdogV2, /node_name\.begins_with\("Phase2_"\)/);
});

test("genuine off-route deep falls still use the proven hard checkpoint escape", () => {
  assert.match(watchdogV2, /supported_floor_invalid: bool = has_surface_support and submerged_depth >= SUPPORTED_FLOOR_ESCAPE_DEPTH/);
  assert.match(watchdogV2, /LOGSPIRE SUBMERGED FLOOR INVALID/);
  assert.match(watchdogV2, /_hard_checkpoint_escape\(racer, submerged_depth\)/);
  assert.match(watchdogBase, /racer\.reset_motion\(safe_spawn\)/);
  assert.match(watchdogBase, /BACK TO THE RACE · WATER RESET/);
});

test("hard escape still clears water authority before restoring the racer", () => {
  assert.match(watchdogBase, /_release_racer_control/);
  assert.match(watchdogBase, /_clear_reliability_runtime/);
  assert.match(watchdogBase, /_clear_water_runtime/);
  assert.match(watchdogBase, /racer\.remove_meta\(WATER_META\)/);
  assert.match(watchdogBase, /_set_water_state_racing\(racer_id\)/);
  assert.match(watchdogBase, /begin_retry_grace/);
});

test("watchdog still bypasses normal checkpoint water veto for genuine failures", () => {
  assert.match(recovery, /func force_checkpoint_recovery/);
  assert.match(recovery, /if _water_should_handle\(racer\):/);
  assert.doesNotMatch(watchdogBase, /force_checkpoint_recovery/);
  assert.doesNotMatch(watchdogV2, /force_checkpoint_recovery/);
  assert.doesNotMatch(watchdogV3, /force_checkpoint_recovery/);
  assert.match(watchdogBase, /_latest_checkpoint_target\(racer\)/);
  assert.match(watchdogBase, /_first_safe_route_target\(\)/);
});
