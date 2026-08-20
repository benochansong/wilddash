import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const phase3 = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v5_route_clearance.gd", "utf8");
const watchdog = readFileSync("godot/modes/logspire_leap/logspire_water_submerge_watchdog.gd", "utf8");

test("Titan Living Tree bridges are static sloped ramps instead of moving overhead slabs", () => {
  assert.match(phase3, /STATIC_LIVING_BRIDGE_WIDTH: float = 3\.8/);
  assert.match(phase3, /STATIC_LIVING_BRIDGE_THICKNESS: float = 0\.55/);
  assert.match(phase3, /_stabilize_living_tree_route_bridges\(\)/);
  assert.match(phase3, /Z5_SPIRAL_03/);
  assert.match(phase3, /Z5_SPIRAL_04/);
  assert.match(phase3, /Z5_SPIRAL_05/);
  assert.match(phase3, /Z5_SPIRAL_06/);
  assert.match(phase3, /body\.look_at\(to, Vector3\.UP\)/);
  assert.match(phase3, /mesh\.size = bridge_size/);
  assert.match(phase3, /shape\.size = bridge_size/);
  assert.match(phase3, /_living_tree_state = &"STATE_B"/);
  assert.match(phase3, /moving_event=false camera_cut=false/);
});

test("hard water reset always normalizes the Round 3 chase camera", () => {
  assert.match(watchdog, /_reset_recovery_camera\(racer\)/);
  assert.match(watchdog, /clear_recovery_focus/);
  assert.match(watchdog, /clear_race_focus/);
  assert.match(watchdog, /camera\.call\("set_target", racer\)/);
  assert.match(watchdog, /camera_normalized=true/);
  assert.match(watchdog, /obstruction_recheck=true/);
});
