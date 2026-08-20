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

test("Round 3 production keeps the V7 finale safety override", () => {
  assert.match(scene, /logspire_phase3_director_v7_finale_log_collision\.gd/);
  assert.match(finale, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v6_titan_tree_safe\.gd"/);
  assert.match(finale, /LOGSPIRE FINALE ROLLING LOG REMOVED/);
});

test("Z6_01 rolling cylinder is completely removed from production", () => {
  const build = functionSlice(finale, "_build_finale_rolling_log", null);
  assert.match(build, /_finale_roll_visual = null/);
  assert.match(build, /_finale_roll_area = null/);
  assert.doesNotMatch(build, /AnimatableBody3D\.new\(\)/);
  assert.doesNotMatch(build, /Node3D\.new\(\)/);
  assert.doesNotMatch(build, /MeshInstance3D\.new\(\)/);
  assert.doesNotMatch(build, /CylinderMesh\.new\(\)/);
  assert.doesNotMatch(build, /CollisionShape3D\.new\(\)/);
  assert.doesNotMatch(build, /CylinderShape3D\.new\(\)/);
  assert.doesNotMatch(build, /Area3D\.new\(\)/);
  assert.doesNotMatch(build, /_world\.add_child/);
});

test("removed obstacle has no push influence or penetration correction path", () => {
  assert.doesNotMatch(finale, /FINALE_LOG_RADIUS/);
  assert.doesNotMatch(finale, /FINALE_LOG_LATERAL_OFFSET/);
  assert.doesNotMatch(finale, /FINALE_LOG_INFLUENCE_RADIUS/);
  assert.doesNotMatch(finale, /FINALE_LOG_INTERIOR_RADIUS/);
  assert.doesNotMatch(finale, /get_overlapping_bodies\(\)/);
  assert.doesNotMatch(finale, /racer\.global_position\s*=/);
  assert.doesNotMatch(finale, /_knockback_velocity/);
});
