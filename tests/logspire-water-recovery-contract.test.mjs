import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const worldDeep = readFileSync("godot/modes/logspire_leap/logspire_world_v2_deep_water.gd", "utf8");
const water = readFileSync("godot/modes/logspire_leap/logspire_water_recovery.gd", "utf8");
const waterV2 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v2.gd", "utf8");
const waterV3 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v3_entry_guard.gd", "utf8");
const waterV4 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v4_deep_swim.gd", "utf8");
const waterV5 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v5_ladder_priority.gd", "utf8");
const swim = readFileSync("godot/modes/logspire_leap/logspire_swim_controller.gd", "utf8");
const ladder = readFileSync("godot/modes/logspire_leap/logspire_ladder_system.gd", "utf8");
const ladderV2 = readFileSync("godot/modes/logspire_leap/logspire_ladder_system_v2.gd", "utf8");
const ladderV3 = readFileSync("godot/modes/logspire_leap/logspire_ladder_system_v3_easy_attach.gd", "utf8");
const phase3Perf = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v2_performance.gd", "utf8");
const phase3Water = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v3_water_priority.gd", "utf8");
const waterAI = readFileSync("godot/modes/logspire_leap/logspire_water_ai.gd", "utf8");
const recovery = readFileSync("godot/modes/logspire_leap/logspire_recovery_system.gd", "utf8");
const graph = readFileSync("godot/modes/logspire_leap/logspire_platform_graph.gd", "utf8");
const character = readFileSync("godot/characters/character_controller.gd", "utf8");

test("Logspire scene wires deep water, easy ladders, performance pass and ladder-priority recovery", () => {
  assert.match(scene, /logspire_world_v2_deep_water\.gd/);
  assert.match(scene, /logspire_water_recovery_v5_ladder_priority\.gd/);
  assert.match(scene, /logspire_ladder_system_v3_easy_attach\.gd/);
  assert.match(scene, /logspire_phase3_director_v3_water_priority\.gd/);
  assert.match(phase3Water, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v2_performance\.gd"/);
  assert.match(scene, /WaterRecovery/);
  assert.match(scene, /LadderSystem/);
  assert.match(scene, /RecoverySystem/);
  assert.match(scene, /PlatformGameplay/);
  assert.match(scene, /Phase3Director/);
});

test("Canopy River keeps normal water recovery on ladders instead of checkpoint restart", () => {
  assert.equal((water.match(/\{"zone": [0-5], "center":/g) || []).length, 6);
  assert.match(water, /LADDER_CLIMB_SECONDS: float = 2\.15/);
  assert.match(water, /LOGSPIRE WATER ENTRY/);
  assert.match(water, /LOGSPIRE WATER RECOVERY/);
  assert.match(waterV2, /LOGSPIRE SWIM/);
  assert.match(waterV4, /checkpoint_respawn=false/);
  assert.match(waterV5, /LOGSPIRE WATER NO RESTART/);
  assert.match(waterV5, /checkpoint_respawn=false/);
  assert.match(waterV5, /_state_by_id\[racer_id\] = WaterState\.SWIMMING/);
  assert.match(recovery, /set_water_recovery/);
  assert.match(recovery, /_water_should_handle/);
});

test("Water entry invalidates checkpoint recovery timers queued before the splash", () => {
  assert.match(recovery, /func cancel_pending_for_water\(/);
  assert.match(recovery, /_recovery_token_counter/);
  assert.match(recovery, /LOGSPIRE RECOVERY STALE TIMER DROPPED/);
  assert.match(recovery, /LOGSPIRE RECOVERY TIMER CANCELLED BY WATER/);
  assert.match(recovery, /if _water_should_handle\(racer\):\n\t\t_pending\.erase\(racer_id\)/);
  assert.match(waterV5, /func _enter_water\(/);
  assert.match(waterV5, /_cancel_stale_checkpoint_recovery\(racer\)/);
  assert.match(waterV5, /func _update_ladder_climb\(/);
});

test("Finale delayed recovery cannot override active swimming", () => {
  assert.match(phase3Water, /logspire_water_recovery_active/);
  assert.match(phase3Water, /FINAL RECOVERY CANCELLED BY WATER/);
  assert.match(phase3Water, /WaterRecovery/);
  assert.match(phase3Perf, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director\.gd"/);
});

test("Deep-water adapter gives every basin enough vertical clearance to swim", () => {
  assert.match(worldDeep, /_shift_node_y\("FOREST_FLOOR", -3\.30\)/);
  assert.equal((worldDeep.match(/_shift_recovery_pair\("Recovery_Z[2-6]", -2\.00\)/g) || []).length, 5);
  assert.match(worldDeep, /min_depth=3\.25m/);
  assert.match(worldDeep, /zone1_depth=3\.45m/);
});

test("Start-grid racers cannot be mistaken for swimmers", () => {
  assert.match(waterV3, /if racer\.is_on_floor\(\):\n\t\treturn false/);
  assert.match(waterV3, /WATER_ENTRY_MIN_DOWN_SPEED: float = -0\.55/);
  assert.match(waterV3, /WATER_ENTRY_MAX_BODY_ABOVE_SURFACE: float = 1\.05/);
  assert.match(waterV3, /racer\.global_position\.y > water_y \+ WATER_ENTRY_MAX_BODY_ABOVE_SURFACE/);
  assert.match(waterV3, /LOGSPIRE WATER ENTRY REJECT/);
});

test("Swimming stays a recovery route instead of a shortcut", () => {
  assert.match(swim, /SWIM_SPEED_RATIO: float = 0\.50/);
  assert.match(swim, /species_scale = 0\.92/);
  assert.match(swim, /racer\.animal_id == &"crocodile"/);
  assert.match(swim, /species_scale \*= 1\.10/);
  assert.match(swim, /SURFACE_BODY_OFFSET: float = 0\.52/);
  assert.match(waterV4, /visual\.play_state\(&"Jump", true\)/);
});

test("Ladder network has 20 exits and immediate 4.25m auto capture", () => {
  const entries = ladderV2.match(/\{"zone": \d, "platform": &"[^"]+"\}/g) || [];
  assert.equal(entries.length, 20);
  assert.match(ladderV2, /\{"zone": 0, "platform": &"START"\}/);
  assert.match(ladder, /DECK_SIZE := Vector3\(6\.0, 0\.45, 6\.0\)/);
  assert.match(ladderV3, /EASY_ATTACH_RADIUS: float = 4\.25/);
  assert.match(waterV5, /INSTANT_LADDER_CAPTURE_RADIUS: float = 4\.25/);
  assert.match(waterV5, /LOGSPIRE LADDER INSTANT CAPTURE/);
  assert.match(ladder, /CLIMB ↑/);
});

test("Titan Tree performance pass removes expensive dynamic shadows and lowers sphere tessellation", () => {
  assert.match(phase3Perf, /_sun\.shadow_enabled = false/);
  assert.match(phase3Perf, /sphere\.radial_segments = 18/);
  assert.match(phase3Perf, /sphere\.rings = 9/);
  assert.match(phase3Perf, /SHADOW_CASTING_SETTING_OFF/);
  assert.match(phase3Perf, /LOGSPIRE TITAN PERFORMANCE READY/);
});

test("Ladder system calls the actual PlatformGraph landing-radius API", () => {
  assert.match(graph, /func get_landing_radius\(platform_id: StringName\) -> float:/);
  assert.match(ladder, /_graph\.call\("get_landing_radius", platform_id\)/);
  assert.doesNotMatch(ladder, /_graph\.call\("get_platform_landing_radius"/);
});

test("Water AI selects ladders by distance and route progress", () => {
  assert.match(waterAI, /planar_distance/);
  assert.match(waterAI, /route_index/);
  assert.match(waterAI, /checkpoint_progress/);
});

test("Global CharacterController remains untouched by the water implementation", () => {
  assert.doesNotMatch(character, /CANOPY RIVER|WATER_ENTRY|LADDER_CLIMB/);
});
