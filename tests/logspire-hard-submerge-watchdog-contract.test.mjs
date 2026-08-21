import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const watchdogBase = readFileSync("godot/modes/logspire_leap/logspire_water_submerge_watchdog.gd", "utf8");
const watchdog = readFileSync("godot/modes/logspire_leap/logspire_water_submerge_watchdog_v2_route_guard.gd", "utf8");
const recovery = readFileSync("godot/modes/logspire_leap/logspire_recovery_system.gd", "utf8");

test("Round 3 production wires the route-guarded deep-water watchdog", () => {
  assert.match(scene, /logspire_water_submerge_watchdog_v2_route_guard\.gd/);
  assert.match(scene, /\[node name="WaterSubmergeWatchdog" type="Node" parent="\."\]/);
  assert.match(watchdogBase, /HARD_SUBMERGE_DEPTH: float = 0\.58/);
  assert.match(watchdog, /ROUTE_HARD_SUBMERGE_CONFIRM_SECONDS: float = 0\.85/);
  assert.match(watchdog, /ROUTE_HARD_MIN_SUBMERGE_DEPTH: float = 0\.95/);
  assert.match(watchdog, /ROUTE_HARD_MIN_DESCENT_SPEED: float = -0\.65/);
  assert.match(watchdog, /ROUTE_SUPPORT_GRACE_SECONDS: float = 0\.55/);
  assert.match(watchdog, /primary_recovery_guard=true/);
  assert.match(watchdog, /deep_fail_safe=true/);
  assert.match(watchdog, /_hard_checkpoint_escape\(racer, submerged_depth\)/);
});

test("authored route support and recent support beat broad invisible water overlap", () => {
  assert.match(watchdog, /_authored_route_support_platform\(racer\)/);
  assert.match(watchdog, /racer\.is_on_floor\(\) or _has_surface_support\(racer\) or route_support_id != &""/);
  assert.match(watchdog, /_has_recent_route_support\(racer_id\)/);
  assert.match(watchdog, /get_route_ids", &"safe"/);
  assert.match(watchdog, /var foot_delta: float = racer\.global_position\.y - top\.y/);
  assert.doesNotMatch(watchdog, /top\.y \+ 0\.40/);
  assert.match(watchdog, /r3_false_water_reset_blocked/);
  assert.match(watchdog, /no_rewind=true/);
});

test("primary WaterRecovery owns ordinary falls and watchdog cannot become a second transform writer", () => {
  assert.match(watchdog, /_primary_water_recovery_active\(racer\)/);
  assert.match(watchdog, /racer\.get_meta\(PRIMARY_WATER_META, false\)/);
  assert.match(watchdog, /_water\.has_method\("is_water_recovering"\)/);
  assert.match(watchdog, /r3_water_watchdog_deferred/);
  assert.match(watchdog, /hard_checkpoint_escape=false/);
  assert.match(watchdog, /transform_owner=WaterRecovery/);
});

test("emergency hard reset requires deep sustained unsupported descent", () => {
  assert.match(watchdog, /submerged_depth < maxf\(HARD_SUBMERGE_DEPTH, ROUTE_HARD_MIN_SUBMERGE_DEPTH\)/);
  assert.match(watchdog, /_water\.has_method\("should_handle_racer"\)/);
  assert.match(watchdog, /not bool\(_water\.call\("should_handle_racer", racer\)\)/);
  assert.match(watchdog, /racer\.velocity\.y > ROUTE_HARD_MIN_DESCENT_SPEED/);
  assert.match(watchdog, /elapsed < ROUTE_HARD_SUBMERGE_CONFIRM_SECONDS/);
  assert.match(watchdog, /r3_true_water_reset_confirmed/);
  assert.match(watchdog, /primary_water_inactive=true/);
  assert.match(watchdog, /emergency_only=true/);
  assert.match(watchdog, /_vine_rescue_active\(racer_id\)/);
});

test("genuine hard escape still clears water authority and restores a bounded route spawn", () => {
  assert.match(watchdogBase, /_release_racer_control/);
  assert.match(watchdogBase, /_clear_reliability_runtime/);
  assert.match(watchdogBase, /_clear_water_runtime/);
  assert.match(watchdogBase, /racer\.remove_meta\(WATER_META\)/);
  assert.match(watchdogBase, /_set_water_state_racing\(racer_id\)/);
  assert.match(watchdogBase, /racer\.reset_motion\(safe_spawn\)/);
  assert.match(watchdogBase, /BACK TO THE RACE · WATER RESET/);
  assert.match(watchdogBase, /begin_retry_grace/);
});

test("watchdog remains independent from normal checkpoint recovery veto", () => {
  assert.match(recovery, /func force_checkpoint_recovery/);
  assert.match(recovery, /if _water_should_handle\(racer\):/);
  assert.doesNotMatch(watchdog, /force_checkpoint_recovery/);
  assert.match(watchdogBase, /_latest_checkpoint_target\(racer\)/);
  assert.match(watchdogBase, /_first_safe_route_target\(\)/);
});
