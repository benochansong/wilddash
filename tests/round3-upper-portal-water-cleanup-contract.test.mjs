import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const portal = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v6_upper_portal_cleanup.gd", "utf8");
const water = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v16_upper_canopy_cleanup.gd", "utf8");

test("production Round 3 wires the upper portal and compact upper-water layers", () => {
  assert.match(scene, /logspire_phase3_director_v6_upper_portal_cleanup\.gd/);
  assert.match(scene, /logspire_water_recovery_v16_upper_canopy_cleanup\.gd/);
  assert.match(portal, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v5_route_clearance\.gd"/);
  assert.match(water, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v15_vine_only\.gd"/);
});

test("Titan upper transition is a real geometry opening, not collision hidden inside an intact cylinder", () => {
  assert.match(portal, /const TITAN_UPPER_PORTAL_TOP_Y: float = 45\.0/);
  assert.match(portal, /trunk_mesh\.height = lower_height/);
  assert.match(portal, /trunk\.global_position\.y = lower_center_y/);
  assert.match(portal, /shape\.height = height/);
  assert.match(portal, /TITAN_UPPER_PORTAL_COLLISION_RADIUS: float = 0\.70/);
  assert.match(portal, /branch\.visible = false/);
  assert.match(portal, /side_forks=2/);
  assert.match(portal, /visual_phase_through=false collision_phase_through=false/);
});

test("upper Z6 water uses a compact visible channel while recovery authority stays broad", () => {
  assert.match(water, /Z6_VISIBLE_WATER_WIDTH: float = 44\.0/);
  assert.match(water, /Z6_VISIBLE_WATER_LENGTH: float = 162\.0/);
  assert.match(water, /Z6_VISIBLE_WATER_THICKNESS: float = 0\.045/);
  assert.match(water, /surface\.mesh = compact_mesh/);
  assert.match(water, /area\.set_meta\(&"recovery_authority_unchanged", true\)/);
  assert.match(water, /broad_floating_slab=false/);
  assert.doesNotMatch(water, /shape\.size = Vector3\(Z6_VISIBLE_WATER_WIDTH/);
});
