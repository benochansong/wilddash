import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const finale = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v7_finale_log_collision.gd", "utf8");

function functionSlice(source, name, nextName) {
  const start = source.indexOf(`func ${name}`);
  assert.ok(start >= 0, `missing function ${name}`);
  const end = nextName ? source.indexOf(`func ${nextName}`, start + 1) : source.length;
  return source.slice(start, end >= 0 ? end : source.length);
}

test("Round 3 production uses the V7 physical finale rolling log", () => {
  assert.match(scene, /logspire_phase3_director_v7_finale_log_collision\.gd/);
  assert.match(finale, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v6_titan_tree_safe\.gd"/);
  assert.match(finale, /LOGSPIRE FINALE LOG COLLISION READY/);
});

test("visible finale log is an AnimatableBody3D with a matched cylinder collision", () => {
  const build = functionSlice(finale, "_build_finale_rolling_log", "_update_finale_obstacles");
  assert.match(build, /AnimatableBody3D\.new\(\)/);
  assert.match(build, /body\.sync_to_physics = true/);
  assert.match(build, /body\.collision_layer = 1/);
  assert.match(build, /body\.collision_mask = 2/);
  assert.match(build, /CylinderMesh\.new\(\)/);
  assert.match(build, /mesh\.top_radius = FINALE_LOG_RADIUS/);
  assert.match(build, /mesh\.bottom_radius = FINALE_LOG_RADIUS/);
  assert.match(build, /mesh\.height = FINALE_LOG_LENGTH/);
  assert.match(build, /CylinderShape3D\.new\(\)/);
  assert.match(build, /shape\.radius = FINALE_LOG_RADIUS/);
  assert.match(build, /shape\.height = FINALE_LOG_LENGTH/);
  assert.match(build, /collision\.rotation\.x = deg_to_rad\(90\.0\)/);
  assert.match(build, /mesh_instance\.rotation\.x = deg_to_rad\(90\.0\)/);
});

test("finale log transform and collision children are ready before physics registration", () => {
  const build = functionSlice(finale, "_build_finale_rolling_log", "_update_finale_obstacles");
  const positionIndex = build.indexOf("body.position = _world_local(global_position)");
  const collisionIndex = build.indexOf("body.add_child(collision)");
  const addIndex = build.indexOf("_world.add_child(body)");
  assert.ok(positionIndex >= 0, "missing authored local position before registration");
  assert.ok(collisionIndex >= 0, "missing physical collision child");
  assert.ok(addIndex >= 0, "missing physics registration");
  assert.ok(positionIndex < addIndex, "body position must be assigned before add_child");
  assert.ok(collisionIndex < addIndex, "collision must exist before add_child");
  assert.doesNotMatch(build, /body\.global_position\s*=/);
});

test("rolling influence follows the log axis instead of using the old oversized box", () => {
  const build = functionSlice(finale, "_build_finale_rolling_log", "_update_finale_obstacles");
  assert.match(build, /influence_shape := CylinderShape3D\.new\(\)/);
  assert.match(build, /influence_shape\.radius = FINALE_LOG_INFLUENCE_RADIUS/);
  assert.match(build, /influence_shape\.height = FINALE_LOG_INFLUENCE_LENGTH/);
  assert.match(build, /influence_collision\.rotation\.x = deg_to_rad\(90\.0\)/);
  assert.match(build, /body\.add_child\(_finale_roll_area\)/);
  assert.doesNotMatch(build, /BoxShape3D\.new\(\)/);
  assert.doesNotMatch(build, /Vector3\(11\.0, 4\.0, 12\.0\)/);
});

test("deep penetration guard preserves race momentum and only removes inward motion", () => {
  const guard = functionSlice(finale, "_guard_finale_log_penetration", null);
  assert.match(finale, /FINALE_LOG_INTERIOR_RADIUS: float = 1\.92/);
  assert.match(finale, /FINALE_LOG_RACER_CLEARANCE: float = 0\.72/);
  assert.match(guard, /get_overlapping_bodies\(\)/);
  assert.match(guard, /body\.to_local\(racer\.global_position\)/);
  assert.match(guard, /body\.to_global\(safe_local\)/);
  assert.match(guard, /if inward_velocity < 0\.0/);
  assert.match(guard, /if inward_knockback < 0\.0/);
  assert.match(guard, /racer\.global_position = safe_global/);
  assert.doesNotMatch(guard, /reset_motion\(/);
  assert.doesNotMatch(guard, /current_speed\s*=\s*0/);
  assert.match(guard, /progress_preserved=true speed_reset=false/);
});
