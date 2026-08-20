import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const watchdogBase = readFileSync("godot/modes/logspire_leap/logspire_water_submerge_watchdog.gd", "utf8");
const watchdogV2 = readFileSync("godot/modes/logspire_leap/logspire_water_submerge_watchdog_v2_route_support.gd", "utf8");
const recovery = readFileSync("godot/modes/logspire_leap/logspire_recovery_system.gd", "utf8");

test("Round 3 production wires route-aware deep-water watchdog V2 over the proven hard escape", () => {
  assert.match(scene, /logspire_water_submerge_watchdog_v2_route_support\.gd/);
  assert.match(scene, /\[node name="WaterSubmergeWatchdog" type="Node" parent="\."\]/);
  assert.match(watchdogV2, /extends "res:\/\/modes\/logspire_leap\/logspire_water_submerge_watchdog\.gd"/);
  assert.match(watchdogBase, /HARD_SUBMERGE_DEPTH: float = 0\.58/);
  assert.match(watchdogBase, /SUPPORTED_FLOOR_ESCAPE_DEPTH: float = 1\.20/);
  assert.match(watchdogBase, /HARD_SUBMERGE_CONFIRM_SECONDS: float = 0\.14/);
  assert.match(watchdogBase, /_hard_checkpoint_escape\(racer, submerged_depth\)/);
});

test("valid Safe Route support suppresses false WATER RESET from stale pool overlap", () => {
  const routeGuard = watchdogV2.indexOf("var route_support: Dictionary = _route_support_hit(racer)");
  const hiddenFloorGuard = watchdogV2.indexOf("var has_surface_support: bool = _has_surface_support(racer)");
  assert.ok(routeGuard >= 0 && hiddenFloorGuard > routeGuard, "route support must be checked before hidden-floor invalidation");
  assert.match(watchdogV2, /LOGSPIRE WATER RESET SUPPRESSED/);
  assert.match(watchdogV2, /route_support=true stale_pool_overlap=true/);
  assert.match(watchdogV2, /_submerged_elapsed_by_id\.erase\(racer_id\)/);
  assert.match(watchdogV2, /continue/);
});

test("route support recognizes authored platforms, moving replacements and CP5 connectors", () => {
  assert.match(watchdogV2, /get_route_ids", &"safe"/);
  assert.match(watchdogV2, /logspire_route_connector/);
  assert.match(watchdogV2, /node_name\.begins_with\("Phase2_"\)/);
  assert.match(watchdogV2, /trim_prefix\("Phase2_"\)/);
  assert.match(watchdogV2, /_safe_route_name_lookup\.has\(node_name\)/);
  assert.match(watchdogV2, /ROUTE_SUPPORT_SAMPLE_RADIUS: float = 0\.58/);
  assert.match(watchdogV2, /PhysicsRayQueryParameters3D\.create/);
});

test("working Vine Rescue is preserved but an off-route deep-water stall is not", () => {
  assert.match(watchdogV2, /_vine_rescue_active\(racer_id\)/);
  assert.match(watchdogBase, /== &"vine_rescue"/);
  assert.match(watchdogV2, /submerged_depth < HARD_SUBMERGE_DEPTH/);
  assert.match(watchdogBase, /racer\.reset_motion\(safe_spawn\)/);
  assert.match(watchdogBase, /BACK TO THE RACE · WATER RESET/);
});

test("hidden floor far below water still cannot exempt a racer from recovery", () => {
  assert.match(watchdogV2, /var has_surface_support: bool = _has_surface_support\(racer\)/);
  assert.match(watchdogV2, /supported_floor_invalid: bool = has_surface_support and submerged_depth >= SUPPORTED_FLOOR_ESCAPE_DEPTH/);
  assert.match(watchdogV2, /if has_surface_support and not supported_floor_invalid:/);
  assert.match(watchdogV2, /LOGSPIRE SUBMERGED FLOOR INVALID/);
  assert.match(watchdogV2, /route_support=false force_checkpoint_pending=true/);
  assert.match(watchdogV2, /_hard_checkpoint_escape\(racer, submerged_depth\)/);
});

test("hard escape still clears water authority before restoring the racer", () => {
  assert.match(watchdogBase, /_release_racer_control/);
  assert.match(watchdogBase, /_clear_reliability_runtime/);
  assert.match(watchdogBase, /_clear_water_runtime/);
  assert.match(watchdogBase, /racer\.remove_meta\(WATER_META\)/);
  assert.match(watchdogBase, /_set_water_state_racing\(racer_id\)/);
  assert.match(watchdogBase, /begin_retry_grace/);
  assert.match(watchdogBase, /immediate=true water_authority_cleared=true/);
});

test("watchdog still bypasses the normal checkpoint water veto for genuine failures", () => {
  assert.match(recovery, /func force_checkpoint_recovery/);
  assert.match(recovery, /if _water_should_handle\(racer\):/);
  assert.doesNotMatch(watchdogBase, /force_checkpoint_recovery/);
  assert.doesNotMatch(watchdogV2, /force_checkpoint_recovery/);
  assert.match(watchdogBase, /_latest_checkpoint_target\(racer\)/);
  assert.match(watchdogBase, /_first_safe_route_target\(\)/);
});
