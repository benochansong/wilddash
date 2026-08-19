import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const modeV3 = readFileSync("godot/modes/logspire_leap/logspire_leap_v3_recovery_camera.gd", "utf8");
const recoveryCamera = readFileSync("godot/modes/logspire_leap/logspire_recovery_chase_camera.gd", "utf8");
const worldDeep = readFileSync("godot/modes/logspire_leap/logspire_world_v2_deep_water.gd", "utf8");
const depthGuard = readFileSync("godot/modes/logspire_leap/logspire_water_depth_guard.gd", "utf8");
const water = readFileSync("godot/modes/logspire_leap/logspire_water_recovery.gd", "utf8");
const waterV3 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v3_entry_guard.gd", "utf8");
const waterV5 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v5_ladder_priority.gd", "utf8");
const waterV6 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v6_nearest_ladder.gd", "utf8");
const waterV7 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v7_jumpout_safe_exit.gd", "utf8");
const waterV8 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v8_traversal_ux.gd", "utf8");
const waterV9 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v9_priority_camera.gd", "utf8");
const waterV10 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v10_surface_collision_guard.gd", "utf8");
const waterV12 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v12_reliability_authority.gd", "utf8");
const swim = readFileSync("godot/modes/logspire_leap/logspire_swim_controller.gd", "utf8");
const ladder = readFileSync("godot/modes/logspire_leap/logspire_ladder_system.gd", "utf8");
const ladderV4 = readFileSync("godot/modes/logspire_leap/logspire_ladder_system_v4_safe_exit.gd", "utf8");
const ladderV5 = readFileSync("godot/modes/logspire_leap/logspire_ladder_system_v5_traversal_paths.gd", "utf8");
const phase3V4 = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v4_major_collision.gd", "utf8");
const combatV2 = readFileSync("godot/modes/logspire_leap/logspire_combat_safety_v2_recovery_protection.gd", "utf8");
const recovery = readFileSync("godot/modes/logspire_leap/logspire_recovery_system.gd", "utf8");
const recoveryV2 = readFileSync("godot/modes/logspire_leap/logspire_recovery_system_v2_ladder_only.gd", "utf8");
const graph = readFileSync("godot/modes/logspire_leap/logspire_platform_graph.gd", "utf8");
const character = readFileSync("godot/characters/character_controller.gd", "utf8");

test("Logspire scene wires V12 reliability over V10 surface recovery and scoped camera", () => {
  assert.match(scene, /logspire_leap_v3_recovery_camera\.gd/);
  assert.match(scene, /logspire_water_recovery_v12_reliability_authority\.gd/);
  assert.match(scene, /logspire_phase3_director_v4_major_collision\.gd/);
  assert.match(scene, /logspire_ladder_system_v5_traversal_paths\.gd/);
  assert.match(scene, /logspire_water_depth_guard\.gd/);
  assert.match(scene, /logspire_recovery_system_v2_ladder_only\.gd/);
  assert.match(scene, /logspire_combat_safety_v2_recovery_protection\.gd/);
  assert.match(waterV12, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v10_surface_collision_guard\.gd"/);
  assert.match(waterV10, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v9_priority_camera\.gd"/);
  assert.match(waterV9, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v8_traversal_ux\.gd"/);
  assert.match(ladderV5, /extends "res:\/\/modes\/logspire_leap\/logspire_ladder_system_v4_safe_exit\.gd"/);
  assert.match(modeV3, /logspire_recovery_chase_camera\.gd/);
  assert.match(modeV3, /round3_only=true/);
});

test("Swimming is camera-relative and recovery camera yaw remains user-controlled", () => {
  assert.match(swim, /func get_player_direction\(camera: Camera3D = null\)/);
  assert.match(swim, /camera_forward := -camera\.global_transform\.basis\.z/);
  assert.match(swim, /camera_right := camera\.global_transform\.basis\.x/);
  assert.match(swim, /camera_forward \* \(-axis\.y\)/);
  assert.match(swim, /SWIM_TURN_SPEED: float = 7\.0/);
  assert.match(recoveryCamera, /func set_recovery_focus\(world_point: Vector3\)/);
  assert.match(recoveryCamera, /func clear_recovery_focus\(\)/);
  assert.match(recoveryCamera, /InputEventMouseMotion/);
  assert.match(recoveryCamera, /JOY_AXIS_RIGHT_X/);
  assert.match(recoveryCamera, /_recovery_yaw/);
  assert.match(waterV9, /set_recovery_focus/);
  assert.match(waterV9, /clear_recovery_focus/);
  assert.match(waterV9, /OS\.is_debug_build\(\)/);
  assert.match(waterV9, /LOGSPIRE WATER INPUT/);
});

test("WaterRecovery exclusively hard-locks swimmers to visible surface instead of basin floor walking", () => {
  assert.match(waterV10, /SURFACE_LOCK_OFFSET: float = 0\.52/);
  assert.match(waterV10, /SURFACE_ASCEND_SPEED: float = 9\.0/);
  assert.match(waterV12, /func _enforce_surface_lock/);
  assert.match(waterV12, /_find_safe_surface_position/);
  assert.match(waterV12, /LOGSPIRE SURFACE BLOCKED/);
  assert.match(waterV12, /LOGSPIRE SURFACE REACQUIRE/);
  assert.doesNotMatch(swim, /SURFACE_BODY_OFFSET|SURFACE_LOCK_TOLERANCE/);
  assert.doesNotMatch(swim, /move_and_collide\(Vector3\.UP/);
  assert.match(swim, /WaterRecovery is the single Y-axis authority/);
  assert.match(swim, /racer\.velocity\.y = 0\.0/);
});

test("Crocodile keeps full land-speed swimming while normal racers remain recovery-paced", () => {
  assert.match(swim, /SWIM_SPEED_RATIO: float = 0\.50/);
  assert.match(swim, /CROCODILE_SWIM_SPEED_RATIO: float = 1\.00/);
  assert.match(swim, /racer\.max_speed \* CROCODILE_SWIM_SPEED_RATIO/);
  assert.match(swim, /CROCODILE_SWIM_ACCELERATION: float = 24\.0/);
});

test("Low ledges use close auto vault instead of wall pushing", () => {
  assert.match(waterV8, /LOW_LEDGE_DETECTION_RADIUS: float = 2\.0/);
  assert.match(waterV8, /LOW_LEDGE_AUTO_VAULT_RADIUS: float = 1\.0/);
  assert.match(waterV8, /AUTO_VAULT_DURATION: float = 0\.45/);
  assert.match(waterV8, /AUTO_VAULT_ARC_HEIGHT: float = 0\.70/);
  assert.match(waterV9, /InputManager\.consume_jump\(\)/);
  assert.match(waterV9, /_vault_landing_is_safe/);
  assert.match(waterV8, /LOGSPIRE AUTO VAULT/);
  assert.match(waterV7, /MAX_JUMP_OUT_HEIGHT: float = 1\.70/);
});

test("Root ramps own the entire recovery climb with authored path points", () => {
  assert.match(ladderV5, /ROOT_PATH_POINT_COUNT: int = 5/);
  assert.match(ladderV5, /path_points/);
  assert.match(waterV8, /ROOT_AUTO_ATTACH_RADIUS: float = 4\.0/);
  assert.match(waterV8, /ROOT_CLIMB_SPEED_MPS: float = 4\.5/);
  assert.match(waterV8, /_begin_root_climb/);
  assert.match(waterV8, /_update_root_climb/);
  assert.match(waterV8, /_point_on_path/);
  assert.match(waterV8, /LOGSPIRE ROOT AUTO CLIMB/);
  assert.match(waterV12, /_recovery_target_clear/);
  assert.match(waterV12, /LOGSPIRE ROOT ATTACH/);
});

test("Ladders align smoothly and climb much slower than legacy V6", () => {
  assert.match(waterV6, /LADDER_CLIMB_SPEED_MPS: float = 8\.0/);
  assert.match(waterV8, /LADDER_AUTO_ATTACH_RADIUS: float = 5\.0/);
  assert.match(waterV8, /LADDER_ALIGN_SECONDS: float = 0\.32/);
  assert.match(waterV8, /PLAYER_LADDER_SPEED_MPS: float = 3\.2/);
  assert.match(waterV8, /AI_LADDER_SPEED_MPS: float = 3\.7/);
  assert.match(waterV8, /LADDER_MIN_SECONDS: float = 1\.8/);
  assert.match(waterV8, /LADDER_MAX_SECONDS: float = 6\.5/);
  assert.match(waterV8, /climb_height \/ climb_speed/);
  assert.match(waterV8, /LOGSPIRE LADDER ALIGN/);
  assert.match(waterV8, /LOGSPIRE LADDER CLIMB/);
  assert.match(waterV8, /&"ladder_exit"/);
  assert.match(waterV12, /LOGSPIRE LADDER ATTACH/);
  assert.match(waterV12, /LOGSPIRE RECOVERY EXIT CLEAR/);
});

test("Major Titan geometry has real gameplay collision and traversal-only query layer", () => {
  assert.match(phase3V4, /TitanTrunkCollision/);
  assert.match(phase3V4, /TITAN_TRUNK_COLLISION_RADIUS: float = 9\.15/);
  assert.match(phase3V4, /TitanRootCollision_/);
  assert.match(phase3V4, /MAJOR_WORLD_COLLISION_LAYER: int = 5/);
  assert.match(phase3V4, /logspire_major_world_collision/);
  assert.match(phase3V4, /LOGSPIRE MAJOR WORLD COLLISION READY/);
  assert.match(waterV10, /MAJOR_WORLD_QUERY_MASK: int = 4/);
  assert.match(waterV10, /move_and_collide\(motion, true\)/);
  assert.match(waterV10, /LOGSPIRE RECOVERY WORLD BLOCK/);
  assert.match(waterV10, /phase_through=false/);
});

test("Recovery targets score distance, type priority, progress, congestion and player yield", () => {
  assert.match(waterV9, /TARGET_JUMP_OUT/);
  assert.match(waterV9, /TARGET_ROOT/);
  assert.match(waterV9, /TARGET_LADDER/);
  assert.match(waterV9, /TARGET_SWITCH_HYSTERESIS: float = 1\.25/);
  assert.match(waterV9, /CONGESTION_PENALTY_PER_RACER: float = 1\.10/);
  assert.match(waterV9, /AI_PLAYER_YIELD_PENALTY: float = 7\.5/);
  assert.match(waterV9, /BEHIND_PROGRESS_PENALTY: float = 2\.0/);
  assert.match(waterV9, /_score_recovery_target/);
  assert.match(waterV9, /_player_is_near/);
  assert.match(waterV9, /LOGSPIRE RECOVERY TARGET/);
  assert.match(waterV10, /MAJOR_BLOCKED_SCORE_PENALTY: float = 1000\.0/);
  assert.match(waterV12, /_blocked_targets_by_id/);
});

test("Recovery congestion protects player and separates AI queues", () => {
  assert.match(character, /collision_layer = 2/);
  assert.match(character, /collision_mask = 3/);
  assert.match(waterV8, /racer\.collision_mask = 1/);
  assert.match(waterV8, /AI_QUEUE_OFFSET_METERS: float = 1\.2/);
  assert.match(waterV8, /int\(racer_id % 3\) - 1/);
  assert.match(waterV8, /LOGSPIRE RECOVERY CONGESTION/);
  assert.match(waterV9, /logspire_recovery_player_priority/);
  assert.match(waterV9, /PLAYER_PRIORITY_RADIUS: float = 5\.0/);
  assert.match(waterV8, /_restore_recovery_collision/);
});

test("Explicit recovery UX states and traversal action lock cover the full water flow", () => {
  for (const state of [
    "RACING", "FALLING", "WATER_ENTRY", "SWIMMING", "JUMP_OUT_APPROACH",
    "AUTO_VAULT", "ROOT_APPROACH", "ROOT_CLIMB", "LADDER_APPROACH",
    "LADDER_ALIGN", "LADDER_CLIMB", "SAFE_EXIT",
  ]) {
    assert.match(waterV9, new RegExp(state));
  }
  assert.match(waterV9, /logspire_traversal_action_lock/);
  assert.match(waterV9, /_set_traversal_action_lock\(racer, true\)/);
  assert.match(waterV9, /_set_traversal_action_lock\(racer, false\)/);
  assert.match(water, /_pause_racer_control/);
  assert.match(water, /node\.set_physics_process\(false\)/);
});

test("Deep water and no-restart protections remain intact", () => {
  assert.equal((water.match(/\{"zone": [0-5], "center":/g) || []).length, 6);
  assert.match(worldDeep, /min_depth=3\.25m/);
  assert.match(depthGuard, /BASIN_DEPTH_METERS: float = 7\.0/);
  assert.match(depthGuard, /walking_floor=false/);
  assert.match(recoveryV2, /area\.monitoring = false/);
  assert.match(recoveryV2, /checkpoint_restart=false/);
  assert.match(waterV5, /LOGSPIRE WATER NO RESTART/);
  assert.match(recovery, /LOGSPIRE RECOVERY TIMER CANCELLED BY WATER/);
  assert.match(waterV12, /DEEP_WATER_GUARD_DEPTH/);
});

test("Start grid and safe exits retain earlier regression guards", () => {
  assert.match(waterV3, /if racer\.is_on_floor\(\):\n\t\treturn false/);
  assert.match(waterV3, /WATER_ENTRY_MIN_DOWN_SPEED: float = -0\.55/);
  assert.match(ladderV4, /SAFE_EXIT_EDGE_MARGIN: float = 2\.75/);
  assert.match(ladderV4, /HIGH_DECK_SIZE := Vector3\(10\.0, 0\.45, 10\.0\)/);
  assert.match(waterV7, /RECOVERY_PROTECTION_SECONDS: float = 0\.75/);
  assert.match(combatV2, /logspire_recovery_protection_until/);
  assert.match(waterV12, /func _exit_position_clear/);
});

test("PlatformGraph API and global CharacterController remain isolated", () => {
  assert.match(graph, /func get_landing_radius\(platform_id: StringName\) -> float:/);
  assert.match(ladder, /_graph\.call\("get_landing_radius", platform_id\)/);
  assert.doesNotMatch(ladder, /get_platform_landing_radius/);
  assert.doesNotMatch(character, /CANOPY RIVER|WATER_ENTRY|ROOT AUTO CLIMB|LADDER ALIGN/);
});
