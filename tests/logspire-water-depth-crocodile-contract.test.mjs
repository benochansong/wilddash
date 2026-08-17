import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const depthGuard = readFileSync("godot/modes/logspire_leap/logspire_water_depth_guard.gd", "utf8");
const recoveryV2 = readFileSync("godot/modes/logspire_leap/logspire_recovery_system_v2_ladder_only.gd", "utf8");
const swim = readFileSync("godot/modes/logspire_leap/logspire_swim_controller.gd", "utf8");

test("Logspire final water depth is applied after jump rebalance", () => {
  assert.match(scene, /logspire_water_depth_guard\.gd/);
  assert.match(scene, /WaterDepthGuard/);
  assert.match(depthGuard, /BASIN_DEPTH_METERS: float = 7\.0/);
  assert.match(depthGuard, /call_deferred\("_apply_final_water_depth"\)/);
  assert.match(depthGuard, /Recovery_Z2/);
  assert.match(depthGuard, /Recovery_Z6/);
  assert.match(depthGuard, /walking_floor=false/);
});

test("Canopy River disables legacy area restart while ladder recovery is active", () => {
  assert.match(scene, /logspire_recovery_system_v2_ladder_only\.gd/);
  assert.match(recoveryV2, /extends "res:\/\/modes\/logspire_leap\/logspire_recovery_system\.gd"/);
  assert.match(recoveryV2, /area\.monitoring = false/);
  assert.match(recoveryV2, /LOGSPIRE LEGACY AREA RECOVERY DISABLED/);
  assert.match(recoveryV2, /ladder_only=true checkpoint_restart=false/);
});

test("Crocodile swims at full race max speed with stronger water acceleration", () => {
  assert.match(swim, /SWIM_SPEED_RATIO: float = 0\.50/);
  assert.match(swim, /CROCODILE_SWIM_SPEED_RATIO: float = 1\.00/);
  assert.match(swim, /CROCODILE_SWIM_ACCELERATION: float = 24\.0/);
  assert.match(swim, /racer\.max_speed \* CROCODILE_SWIM_SPEED_RATIO/);
  assert.match(swim, /racer\.animal_id == &"crocodile"/);
});
