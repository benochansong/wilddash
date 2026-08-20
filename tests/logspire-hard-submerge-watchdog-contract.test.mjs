import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const watchdog = readFileSync("godot/modes/logspire_leap/logspire_water_submerge_watchdog.gd", "utf8");
const recovery = readFileSync("godot/modes/logspire_leap/logspire_recovery_system.gd", "utf8");

test("Round 3 production wires an independent deep-water watchdog", () => {
  assert.match(scene, /logspire_water_submerge_watchdog\.gd/);
  assert.match(scene, /\[node name="WaterSubmergeWatchdog" type="Node" parent="\."\]/);
  assert.match(watchdog, /HARD_SUBMERGE_DEPTH: float = 0\.58/);
  assert.match(watchdog, /SUPPORTED_FLOOR_ESCAPE_DEPTH: float = 1\.20/);
  assert.match(watchdog, /HARD_SUBMERGE_CONFIRM_SECONDS: float = 0\.14/);
  assert.match(watchdog, /_hard_checkpoint_escape\(racer, submerged_depth\)/);
});

test("working Vine Rescue is preserved but an unsupported deep-water stall is not", () => {
  assert.match(watchdog, /_vine_rescue_active\(racer_id\)/);
  assert.match(watchdog, /== &"vine_rescue"/);
  assert.match(watchdog, /_has_surface_support\(racer\)/);
  assert.match(watchdog, /submerged_depth < HARD_SUBMERGE_DEPTH/);
  assert.match(watchdog, /racer\.reset_motion\(safe_spawn\)/);
  assert.match(watchdog, /BACK TO THE RACE · WATER RESET/);
});

test("a hidden floor far below the waterline can no longer exempt a racer from recovery", () => {
  assert.match(watchdog, /var has_surface_support: bool = _has_surface_support\(racer\)/);
  assert.match(watchdog, /supported_floor_invalid: bool = has_surface_support and submerged_depth >= SUPPORTED_FLOOR_ESCAPE_DEPTH/);
  assert.match(watchdog, /if has_surface_support and not supported_floor_invalid:/);
  assert.match(watchdog, /LOGSPIRE SUBMERGED FLOOR INVALID/);
  assert.match(watchdog, /support_ignored=true force_checkpoint_pending=true/);
});

test("hard escape clears water authority before restoring the racer", () => {
  assert.match(watchdog, /_release_racer_control/);
  assert.match(watchdog, /_clear_reliability_runtime/);
  assert.match(watchdog, /_clear_water_runtime/);
  assert.match(watchdog, /racer\.remove_meta\(WATER_META\)/);
  assert.match(watchdog, /_set_water_state_racing\(racer_id\)/);
  assert.match(watchdog, /begin_retry_grace/);
  assert.match(watchdog, /immediate=true water_authority_cleared=true/);
});

test("watchdog bypasses the normal checkpoint water veto that caused the stall", () => {
  assert.match(recovery, /func force_checkpoint_recovery/);
  assert.match(recovery, /if _water_should_handle\(racer\):/);
  assert.doesNotMatch(watchdog, /force_checkpoint_recovery/);
  assert.match(watchdog, /_latest_checkpoint_target\(racer\)/);
  assert.match(watchdog, /_first_safe_route_target\(\)/);
});
