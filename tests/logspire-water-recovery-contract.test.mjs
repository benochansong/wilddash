import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const worldDeep = readFileSync("godot/modes/logspire_leap/logspire_world_v2_deep_water.gd", "utf8");
const depthGuard = readFileSync("godot/modes/logspire_leap/logspire_water_depth_guard.gd", "utf8");
const water = readFileSync("godot/modes/logspire_leap/logspire_water_recovery.gd", "utf8");
const waterV2 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v2.gd", "utf8");
const waterV3 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v3_entry_guard.gd", "utf8");
const waterV4 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v4_deep_swim.gd", "utf8");
const waterV5 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v5_ladder_priority.gd", "utf8");
const waterV6 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v6_nearest_ladder.gd", "utf8");
const waterV7 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v7_jumpout_safe_exit.gd", "utf8");
const swim = readFileSync("godot/modes/logspire_leap/logspire_swim_controller.gd", "utf8");
const ladder = readFileSync("godot/modes/logspire_leap/logspire_ladder_system.gd", "utf8");
const ladderV2 = readFileSync("godot/modes/logspire_leap/logspire_ladder_system_v2.gd", "utf8");
const ladderV3 = readFileSync("godot/modes/logspire_leap/logspire_ladder_system_v3_easy_attach.gd", "utf8");
const ladderV4 = readFileSync("godot/modes/logspire_leap/logspire_ladder_system_v4_safe_exit.gd", "utf8");
const combatV2 = readFileSync("godot/modes/logspire_leap/logspire_combat_safety_v2_recovery_protection.gd", "utf8");
const phase3Perf = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v2_performance.gd", "utf8");
const phase3Water = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v3_water_priority.gd", "utf8");
const waterAI = readFileSync("godot/modes/logspire_leap/logspire_water_ai.gd", "utf8");
const recovery = readFileSync("godot/modes/logspire_leap/logspire_recovery_system.gd", "utf8");
const recoveryV2 = readFileSync("godot/modes/logspire_leap/logspire_recovery_system_v2_ladder_only.gd", "utf8");
const graph = readFileSync("godot/modes/logspire_leap/logspire_platform_graph.gd", "utf8");
const character = readFileSync("godot/characters/character_controller.gd", "utf8");

test("Logspire scene wires final-depth water, audited recovery routes and safe exits", () => {
  assert.match(scene, /logspire_world_v2_deep_water\.gd/);
  assert.match(scene, /logspire_water_depth_guard\.gd/);
  assert.match(scene, /logspire_water_recovery_v7_jumpout_safe_exit\.gd/);
  assert.match(waterV7, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v6_nearest_ladder\.gd"/);
  assert.match(scene, /logspire_ladder_system_v4_safe_exit\.gd/);
  assert.match(scene, /logspire_recovery_system_v2_ladder_only\.gd/);
  assert.match(scene, /logspire_combat_safety_v2_recovery_protection\.gd/);
  assert.match(scene, /logspire_phase3_director_v3_water_priority\.gd/);
  assert.match(phase3Water, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v2_performance\.gd"/);
  assert.match(scene, /WaterRecovery/);
  assert.match(scene, /LadderSystem/);
  assert.match(scene, /RecoverySystem/);
});

test("Canopy River keeps normal water recovery off checkpoint restart paths", () => {
  assert.equal((water.match(/\{"zone": [0-5], "center":/g) || []).length, 6);
  assert.match(waterV5, /LOGSPIRE WATER NO RESTART/);
  assert.match(waterV5, /checkpoint_respawn=false/);
  assert.match(recoveryV2, /area\.monitoring = false/);
  assert.match(recoveryV2, /checkpoint_restart=false/);
  assert.match(recovery, /set_water_recovery/);
  assert.match(recovery, /_water_should_handle/);
});

test("Water entry invalidates checkpoint recovery timers queued before the splash", () => {
  assert.match(recovery, /func cancel_pending_for_water\(/);
  assert.match(recovery, /_recovery_token_counter/);
  assert.match(recovery, /LOGSPIRE RECOVERY STALE TIMER DROPPED/);
  assert.match(recovery, /LOGSPIRE RECOVERY TIMER CANCELLED BY WATER/);
  assert.match(waterV5, /_cancel_stale_checkpoint_recovery\(racer\)/);
  assert.match(waterV6, /_update_ladder_climb/);
});

test("Finale delayed recovery cannot override active swimming", () => {
  assert.match(phase3Water, /logspire_water_recovery_active/);
  assert.match(phase3Water, /FINAL RECOVERY CANCELLED BY WATER/);
  assert.match(phase3Water, /WaterRecovery/);
  assert.match(phase3Perf, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director\.gd"/);
});

test("Final water depth stays deep after jump rebalance", () => {
  assert.match(worldDeep, /min_depth=3\.25m/);
  assert.match(depthGuard, /BASIN_DEPTH_METERS: float = 7\.0/);
  assert.match(depthGuard, /walking_floor=false/);
  assert.match(scene, /WaterDepthGuard/);
});

test("Start-grid racers cannot be mistaken for swimmers", () => {
  assert.match(waterV3, /if racer\.is_on_floor\(\):\n\t\treturn false/);
  assert.match(waterV3, /WATER_ENTRY_MIN_DOWN_SPEED: float = -0\.55/);
  assert.match(waterV3, /LOGSPIRE WATER ENTRY REJECT/);
});

test("Crocodile has full land-speed water identity while other racers remain recovery-paced", () => {
  assert.match(swim, /SWIM_SPEED_RATIO: float = 0\.50/);
  assert.match(swim, /CROCODILE_SWIM_SPEED_RATIO: float = 1\.00/);
  assert.match(swim, /racer\.max_speed \* CROCODILE_SWIM_SPEED_RATIO/);
  assert.match(swim, /CROCODILE_SWIM_ACCELERATION: float = 24\.0/);
});

test("Nearby physical ladder still beats stale route targets across zone boundaries", () => {
  assert.match(waterV6, /NEARBY_LADDER_CAPTURE_RADIUS: float = 5\.25/);
  assert.match(waterV6, /_nearest_physical_ladder\(racer\)/);
  assert.match(waterV6, /get_all_ladders/);
  assert.match(waterV6, /LOGSPIRE LADDER NEAREST CAPTURE/);
});

test("Audited ladder network removes early forced ladders and provides wide safe decks", () => {
  const legacyEntries = ladderV2.match(/\{"zone": \d, "platform": &"[^"]+"\}/g) || [];
  const auditedBlock = ladderV4.match(/func _ladder_layout\(\) -> Array:[\s\S]*?\n\t\]/)?.[0] || "";
  const auditedEntries = auditedBlock.match(/\{"zone": \d, "platform": &"[^"]+"\}/g) || [];
  assert.equal(legacyEntries.length, 20);
  assert.equal(auditedEntries.length, 17);
  assert.doesNotMatch(auditedBlock, /platform": &"START"/);
  assert.doesNotMatch(auditedBlock, /platform": &"Z1_04"/);
  assert.doesNotMatch(auditedBlock, /platform": &"Z2_03"/);
  assert.match(ladderV4, /SAFE_EXIT_EDGE_MARGIN: float = 2\.75/);
  assert.match(ladderV4, /HIGH_DECK_SIZE := Vector3\(10\.0, 0\.45, 10\.0\)/);
  assert.match(ladderV4, /RECOVERY_WALKWAY_WIDTH: float = 4\.5/);
  assert.match(ladderV4, /LOGSPIRE LADDER VALID/);
});

test("Early recovery provides jump-out and root-ramp alternatives", () => {
  assert.match(ladderV4, /_add_direct_platform_jump_out\(0, &"START"\)/);
  assert.match(ladderV4, /_add_jump_out_with_root_ramp\(0, &"Z1_02", -1\.0\)/);
  assert.match(ladderV4, /_add_jump_out_with_root_ramp\(0, &"Z1_04", 1\.0\)/);
  assert.match(ladderV4, /_add_jump_out_with_root_ramp\(1, &"Z2_01", -1\.0\)/);
  assert.match(ladderV4, /_add_jump_out_with_root_ramp\(1, &"Z2_03", 1\.0\)/);
  assert.match(ladderV4, /_add_root_ramp_only\(4, &"Z5_APPROACH_01", -1\.0\)/);
  assert.match(ladderV4, /JUMP_OUT_HEIGHT: float = 1\.35/);
  assert.match(ladderV4, /get_jump_outs_for_zone/);
  assert.match(ladderV4, /get_root_ramps_for_zone/);
});

test("Water recovery prioritizes jump-out then root ramp then ladder", () => {
  assert.match(waterV7, /MAX_JUMP_OUT_HEIGHT: float = 1\.70/);
  assert.match(waterV7, /JUMP BACK UP! · SPACE/);
  assert.match(waterV7, /Input\.is_action_just_pressed\("jump"\)/);
  assert.match(waterV7, /FOLLOW THE ROOT/);
  assert.match(waterV7, /_perform_jump_out/);
  assert.match(waterV7, /_finish_to_root_ramp/);
  assert.match(waterV7, /super\(racer, delta\)/);
});

test("Ladder recovery ends inside the deck with protection and second-fall telemetry", () => {
  assert.match(waterV7, /safe_exit/);
  assert.match(waterV7, /RECOVERY_PROTECTION_SECONDS: float = 0\.75/);
  assert.match(waterV7, /SECOND_FALL_WINDOW_SECONDS: float = 3\.0/);
  assert.match(waterV7, /LOGSPIRE LADDER SAFE EXIT/);
  assert.match(waterV7, /LOGSPIRE RECOVERY SECOND FALL/);
  assert.match(combatV2, /logspire_recovery_protection_until/);
  assert.match(combatV2, /_knockback_velocity/);
});

test("Tall ladders retain height-scaled climb timing and axis lock", () => {
  assert.match(waterV6, /LADDER_CLIMB_SPEED_MPS: float = 8\.0/);
  assert.match(waterV6, /LADDER_CLIMB_MIN_SECONDS: float = 1\.4/);
  assert.match(waterV6, /LADDER_CLIMB_MAX_SECONDS: float = 5\.5/);
  assert.match(waterV6, /climb_height \/ LADDER_CLIMB_SPEED_MPS/);
  assert.match(waterV6, /position\.x = from\.x/);
  assert.match(waterV6, /position\.z = from\.z/);
});

test("Titan Tree performance pass remains intact", () => {
  assert.match(phase3Perf, /_sun\.shadow_enabled = false/);
  assert.match(phase3Perf, /sphere\.radial_segments = 18/);
  assert.match(phase3Perf, /SHADOW_CASTING_SETTING_OFF/);
});

test("Ladder system calls the actual PlatformGraph landing-radius API", () => {
  assert.match(graph, /func get_landing_radius\(platform_id: StringName\) -> float:/);
  assert.match(ladder, /_graph\.call\("get_landing_radius", platform_id\)/);
  assert.doesNotMatch(ladder, /_graph\.call\("get_platform_landing_radius"/);
});

test("Water AI retains distance and route-progress scoring as ladder fallback", () => {
  assert.match(waterAI, /planar_distance/);
  assert.match(waterAI, /route_index/);
  assert.match(waterAI, /checkpoint_progress/);
});

test("Global CharacterController remains untouched by the water implementation", () => {
  assert.doesNotMatch(character, /CANOPY RIVER|WATER_ENTRY|LADDER_CLIMB|JUMP BACK UP/);
});
