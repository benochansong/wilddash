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

test("Phase A makes the complete Safe Route physically forgiving", () => {
  assert.match(gapGuard, /ZONE1_MAX_GAP: float = 2\.25/);
  assert.match(gapGuard, /ZONE2_MAX_GAP: float = 2\.80/);
  assert.match(gapGuard, /ZONE3_MAX_GAP: float = 2\.35/);
  assert.match(gapGuard, /ZONE4_SAFE_MAX_GAP: float = 3\.00/);
  assert.match(gapGuard, /TITAN_MAX_GAP: float = 3\.25/);
  assert.match(gapGuard, /FINALE_MAX_GAP: float = 3\.55/);
  assert.match(gapGuard, /FINAL_JUMP_MAX_GAP: float = 4\.25/);
  assert.match(gapGuard, /ZONE1_MIN_SIZE := Vector3\(14\.0, 0\.0, 12\.5\)/);
  assert.match(gapGuard, /PLAZA_MIN_WIDTH: float = 16\.0/);
  assert.match(gapGuard, /shape\.size = Vector3\(size\.x \+ 0\.80, size\.y, size\.z \+ 0\.80\)/);
  assert.match(gapGuard, /LOGSPIRE PHASE A GAP REPORT/);
});

test("Phase A adds actual running connectors without flattening Wild-exclusive geometry", () => {
  assert.match(gapGuard, /SafeFlowBridge_/);
  assert.match(gapGuard, /_build_flow_bridge\(&"Z1_02", &"Z1_03", 9\.0/);
  assert.match(gapGuard, /_build_flow_bridge\(&"Z2_05", &"Z2_06", 8\.5/);
  assert.match(gapGuard, /_build_flow_bridge\(&"Z4_SAFE_06", &"Z4_SAFE_07", 8\.5/);
  assert.match(gapGuard, /_build_flow_bridge\(&"Z5_APPROACH_01", &"Z5_APPROACH_02", 9\.0/);
  assert.match(gapGuard, /_reanchor_wild_exclusive_route/);
  assert.match(gapGuard, /wild_exclusive_preserved=true/);
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
