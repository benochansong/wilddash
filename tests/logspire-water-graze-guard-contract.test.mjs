import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const v3 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v3_entry_guard.gd", "utf8");
const v15 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v15_vine_only.gd", "utf8");

test("Vine-only recovery keeps the original floor and descent entry guards", () => {
  assert.match(v3, /if racer\.is_on_floor\(\):\n\t\treturn false/);
  assert.match(v3, /WATER_ENTRY_MIN_DOWN_SPEED: float = -0\.55/);
  assert.match(v15, /if not super\(racer, water_y\):/);
});

test("Round 3 requires meaningful immersion instead of a foot-level water graze", () => {
  assert.match(v15, /VINE_ONLY_ENTRY_MAX_BODY_ABOVE_SURFACE: float = 0\.72/);
  assert.match(v15, /racer\.global_position\.y > water_y \+ VINE_ONLY_ENTRY_MAX_BODY_ABOVE_SURFACE/);
});

test("Rounded logs and cylinders count as support even when is_on_floor briefly flickers", () => {
  assert.match(v15, /func _has_nearby_surface_support\(/);
  assert.match(v15, /VINE_ONLY_SUPPORT_PROBE_DEPTH: float = 1\.65/);
  assert.match(v15, /PhysicsRayQueryParameters3D\.create\(ray_from, ray_to\)/);
  assert.match(v15, /query\.collision_mask = VINE_ONLY_WORLD_SUPPORT_MASK/);
  assert.match(v15, /query\.collide_with_areas = false/);
  assert.match(v15, /query\.collide_with_bodies = true/);
  assert.match(v15, /hit_position\.y >= water_y - VINE_ONLY_SUPPORT_SURFACE_TOLERANCE/);
});

test("A real fall must remain in the water band briefly before Vine Rescue becomes authoritative", () => {
  assert.match(v15, /VINE_ONLY_ENTRY_CONFIRM_SECONDS: float = 0\.12/);
  assert.match(v15, /Time\.get_ticks_msec\(\)/);
  assert.match(v15, /confirmed_seconds >= VINE_ONLY_ENTRY_CONFIRM_SECONDS/);
  assert.match(v15, /_vine_only_entry_candidate_since_msec_by_id\.erase\(racer_id\)/);
});
