import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const phase3Base = readFileSync("godot/modes/logspire_leap/logspire_phase3_director.gd", "utf8");
const phase3V5 = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v5_route_clearance.gd", "utf8");

test("production R3 uses the route-clearance adapter over V4 major collision", () => {
  assert.match(scene, /logspire_phase3_director_v5_route_clearance\.gd/);
  assert.match(phase3V5, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v4_major_collision\.gd"/);
});

test("giant moving tree bridges are never visible while collision is disabled", () => {
  assert.match(phase3Base, /const LIVING_BRANCH_REVEAL_T: float = 0\.58/);
  assert.match(phase3Base, /body\.collision_layer = 0[\s\S]*?body\.visible = false/);
  assert.match(phase3Base, /body\.visible = collision_ready[\s\S]*?body\.collision_layer = 1 if collision_ready else 0/);
  assert.match(phase3Base, /const LAST_TREE_REVEAL_T: float = 0\.58/);
  assert.match(phase3Base, /_last_tree\.collision_layer = 0[\s\S]*?_last_tree\.visible = false/);
  assert.match(phase3Base, /_last_tree\.visible = collision_ready[\s\S]*?_last_tree\.collision_layer = 1 if collision_ready else 0/);
});

test("Titan roots and decorative branches are pulled away from the safe-route corridor", () => {
  assert.match(phase3V5, /TITAN_CLEAR_ROOT_SIZE := Vector3\(3\.8, 1\.8, 12\.0\)/);
  assert.match(phase3V5, /TITAN_CLEAR_ROOT_CENTER_RADIUS: float = 6\.2/);
  assert.match(phase3V5, /TITAN_CLEAR_BRANCH_MAX_LENGTH: float = 12\.5/);
  assert.match(phase3V5, /TITAN_CLEAR_BRANCH_CENTER_RADIUS: float = 6\.5/);
  assert.match(phase3V5, /branch_mesh\.size\.z = minf\(branch_mesh\.size\.z, TITAN_CLEAR_BRANCH_MAX_LENGTH\)/);
});

test("visible Titan roots synchronize to collision after the inherited safe-route audit", () => {
  assert.match(phase3V5, /audit_safe_route_collision\(\)/);
  assert.match(phase3V5, /_sync_visible_geometry_to_collision\(\)/);
  assert.match(phase3V5, /mesh\.size = shape\.size/);
  assert.match(phase3V5, /visual\.global_position = body\.global_position/);
  assert.match(phase3V5, /visual\.global_rotation = body\.global_rotation/);
});

test("recovery or teleport cannot leave a racer inside major Titan collision", () => {
  assert.match(phase3V5, /_eject_racers_from_major_geometry\(\)/);
  assert.match(phase3V5, /_eject_from_trunk\(racer\)/);
  assert.match(phase3V5, /_eject_from_box\(racer, root_body\)/);
  assert.match(phase3V5, /LOGSPIRE MAJOR GEOMETRY EJECT/);
  assert.match(phase3V5, /phase_through=false/);
});

test("Crown Nest finish poles stay outside the playable finish interior", () => {
  assert.match(phase3V5, /pole\.position = Vector3\(side \* 12\.5, 2\.5, 7\.5\)/);
  assert.match(phase3V5, /Vector3\(side \* 11\.4, 3\.6, 7\.5\)/);
});
