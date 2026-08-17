import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const depthGuard = readFileSync("godot/modes/logspire_leap/logspire_water_depth_guard.gd", "utf8");
const gapGuard = readFileSync("godot/modes/logspire_leap/logspire_jump_gap_guard.gd", "utf8");
const platformAI = readFileSync("godot/modes/logspire_leap/logspire_platform_ai.gd", "utf8");

test("legacy recovery basin decks stay deep and invisible so the river surface remains clear", () => {
  assert.match(depthGuard, /BASIN_DEPTH_METERS: float = 7\.0/);
  assert.match(depthGuard, /deck\.position\.y = floor_top_y - 0\.30/);
  assert.match(depthGuard, /deck\.visible = false/);
  assert.match(depthGuard, /legacy_deck_visuals_hidden=/);
  assert.match(depthGuard, /water_surface_clear=true/);
});

test("Zone 1 and early Zone 2 are physically forgiving tutorial platforms", () => {
  assert.match(gapGuard, /TUTORIAL_ZONE1_MAX_SURFACE_GAP: float = 2\.60/);
  assert.match(gapGuard, /TUTORIAL_ZONE2_MAX_SURFACE_GAP: float = 3\.20/);
  assert.match(gapGuard, /TUTORIAL_ZONE1_WIDTH_SCALE: float = 1\.12/);
  assert.match(gapGuard, /TUTORIAL_ZONE1_LENGTH_SCALE: float = 1\.10/);
  assert.match(gapGuard, /Z2_01/);
  assert.match(gapGuard, /Z2_02/);
  assert.match(gapGuard, /Z2_03/);
  assert.match(gapGuard, /shape\.size = Vector3\(size\.x \+ 0\.70, size\.y, size\.z \+ 0\.70\)/);
});

test("tutorial AI waits until the platform edge and keeps a mild airborne landing assist", () => {
  assert.match(platformAI, /TUTORIAL_ZONE1_JUMP_TRIGGER: float = 8\.6/);
  assert.match(platformAI, /TUTORIAL_ZONE2_JUMP_TRIGGER: float = 9\.4/);
  assert.match(platformAI, /TUTORIAL_MIN_JUMP_SCALE: float = 1\.11/);
  assert.match(platformAI, /TUTORIAL_SPEED_FLOOR_RATIO: float = 1\.04/);
  assert.match(platformAI, /TUTORIAL_AIR_ASSIST_RANGE: float = 11\.5/);
  assert.match(platformAI, /_apply_tutorial_air_assist\(delta\)/);
  assert.match(platformAI, /current_velocity\.lerp\(desired_velocity, blend\)/);
  assert.match(platformAI, /tutorial_safe=/);
});
