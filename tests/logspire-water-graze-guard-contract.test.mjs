import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const racerScene = readFileSync("godot/characters/test_racer.tscn", "utf8");
const baseWater = readFileSync("godot/modes/logspire_leap/logspire_water_recovery.gd", "utf8");
const v3 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v3_entry_guard.gd", "utf8");
const v10 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v10_surface_collision_guard.gd", "utf8");
const v15 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v15_vine_only.gd", "utf8");

test("CharacterRoot is the foot origin and Vine-only recovery keeps floor/descent guards", () => {
  assert.match(racerScene, /position = Vector3\(0, 0\.95, 0\)/);
  assert.match(v3, /WATER_ENTRY_MIN_DOWN_SPEED: float = -0\.55/);
  assert.match(v15, /if racer\.is_on_floor\(\) or _has_nearby_surface_support\(racer\):/);
  assert.match(v15, /if racer\.velocity\.y > WATER_ENTRY_MIN_DOWN_SPEED:/);
});

test("Round 3 requires the feet to be meaningfully below water before recovery is possible", () => {
  assert.match(v15, /VINE_ONLY_REQUIRED_FOOT_SUBMERSION: float = 0\.26/);
  assert.match(v15, /racer\.global_position\.y > water_y - VINE_ONLY_REQUIRED_FOOT_SUBMERSION/);
  assert.doesNotMatch(v15, /VINE_ONLY_ENTRY_MAX_BODY_ABOVE_SURFACE/);
});

test("Rounded logs and cylinders use a nine-sample footprint support probe", () => {
  assert.match(v15, /func _has_nearby_surface_support\(racer: WildDashCharacterController\)/);
  assert.match(v15, /VINE_ONLY_WORLD_SUPPORT_MASK: int = 5/);
  assert.match(v15, /VINE_ONLY_SUPPORT_MAX_DROP: float = 0\.92/);
  assert.match(v15, /var offsets: Array\[Vector3\] = \[/);
  assert.match(v15, /diagonal_a \* sample_radius/);
  assert.match(v15, /diagonal_b \* sample_radius/);
  assert.match(v15, /PhysicsRayQueryParameters3D\.create\(ray_from, ray_to\)/);
  assert.match(v15, /query\.hit_from_inside = true/);
  assert.match(v15, /drop >= -0\.12 and drop <= VINE_ONLY_SUPPORT_MAX_DROP/);
});

test("A real fall must lose support, stay submerged and remain confirmed before Vine Rescue", () => {
  assert.match(v15, /VINE_ONLY_SUPPORT_GRACE_SECONDS: float = 0\.24/);
  assert.match(v15, /VINE_ONLY_ENTRY_CONFIRM_SECONDS: float = 0\.18/);
  assert.match(v15, /_vine_only_last_support_msec_by_id/);
  assert.match(v15, /since_support_seconds < VINE_ONLY_SUPPORT_GRACE_SECONDS/);
  assert.match(v15, /confirmed_seconds >= VINE_ONLY_ENTRY_CONFIRM_SECONDS/);
  assert.match(v15, /_vine_only_entry_candidate_since_msec_by_id\.erase\(racer_id\)/);
});

test("Other R3 assists do not take water authority while the racer still has support", () => {
  assert.match(v15, /func should_handle_racer\(racer: WildDashCharacterController\) -> bool:/);
  assert.match(v15, /if racer\.is_on_floor\(\) or _has_nearby_surface_support\(racer\):\n\t\treturn false/);
  assert.match(v15, /water_y - VINE_ONLY_REQUIRED_FOOT_SUBMERSION \* 0\.5/);
});

test("V10 deep reacquire cannot bypass the V15 strict entry authority", () => {
  assert.match(v10, /_enter_water\(racer, int\(pool\.get\("zone", 0\)\), water_y\)/);
  assert.match(v15, /if not is_water_recovering\(racer\) and state in \[WaterState\.RACING, WaterState\.FALLING\]:/);
  assert.match(v15, /if not _is_real_water_entry\(racer, water_y\):/);
  assert.match(v15, /LOGSPIRE VINE ENTRY BYPASS REJECT/);
});

test("confirmed R3 falls skip the obsolete water-surface camera tableau", () => {
  assert.match(baseWater, /position\.y = water_y \+ 0\.62/);
  assert.match(v15, /var fall_position: Vector3 = racer\.global_position/);
  assert.match(v15, /racer\.global_position = fall_position/);
  assert.match(v15, /_begin_vine_rescue\(racer\)/);
  assert.match(v15, /water_surface_snap=false/);
});
