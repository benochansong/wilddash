import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const phase3V5 = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v5_route_clearance.gd", "utf8");
const watchdog = readFileSync("godot/modes/logspire_leap/logspire_water_submerge_watchdog.gd", "utf8");
const finishAuthority = readFileSync("godot/modes/logspire_leap/logspire_finish_authority.gd", "utf8");
const gameManager = readFileSync("godot/scripts/game_manager.gd", "utf8");

function functionBlock(source, name) {
  const marker = `func ${name}`;
  const start = source.indexOf(marker);
  assert.ok(start >= 0, `${name} should exist`);
  const next = source.indexOf("\nfunc ", start + marker.length);
  return source.slice(start, next >= 0 ? next : source.length);
}

test("production Round 3 activates the Sky Finale safety override", () => {
  assert.match(scene, /logspire_phase3_director_v5_route_clearance\.gd/);
  assert.match(scene, /logspire_water_submerge_watchdog\.gd/);
  assert.match(scene, /logspire_finish_authority\.gd/);
});

test("playable Finale log is flat and has no hollow cylinder or rolling force", () => {
  const buildLog = functionBlock(phase3V5, "_build_finale_rolling_log() -> void:");
  assert.match(buildLog, /BoxMesh\.new\(\)/);
  assert.match(buildLog, /FINALE_FLAT_LOG_SIZE/);
  assert.match(buildLog, /_finale_roll_area = null/);
  assert.doesNotMatch(buildLog, /CylinderMesh/);
  assert.match(phase3V5, /r3_finale_log_removed/);
});

test("moving Finale route pieces are converted to stable box traversal", () => {
  assert.match(phase3V5, /SkyFinaleMovingBranch shape=box static=true moving=false/);
  assert.match(phase3V5, /_finale_moving_branch\.global_position = _finale_moving_branch_base/);
  assert.match(phase3V5, /_last_tree_state = &"STATIC_READY"/);
  assert.match(phase3V5, /LastFallingTree shape=box static=true falling_event=false camera_cut=false/);
  assert.match(phase3V5, /_final_jump_area\.monitoring = true/);
});

test("final gap recovery volume is deep, bounded, and support-first", () => {
  const buildRecovery = functionBlock(phase3V5, "_build_final_recovery_area() -> void:");
  assert.match(buildRecovery, /FINALE_RECOVERY_DROP/);
  assert.match(buildRecovery, /BoxShape3D\.new\(\)/);
  assert.match(buildRecovery, /FINALE_RECOVERY_VOLUME_SIZE/);
  assert.match(phase3V5, /FINALE_RECOVERY_VOLUME_SIZE := Vector3\(28\.0, 2\.4, 22\.0\)/);
  assert.match(phase3V5, /FINALE_RECOVERY_DROP: float = 7\.2/);

  const recover = functionBlock(phase3V5, "_recover_final_after_delay(racer: WildDashCharacterController, racer_id: int) -> void:");
  const supportGuard = recover.indexOf("_finale_route_support_platform(racer)");
  const reset = recover.indexOf("racer.reset_motion(target)");
  assert.ok(supportGuard >= 0 && reset > supportGuard, "valid support must be checked before reset_motion");
  assert.match(recover, /r3_finale_false_water_blocked/);
  assert.match(recover, /r3_finale_recovery_trigger/);
  assert.match(recover, /r3_finale_recovery_exit/);
  assert.match(recover, /begin_retry_grace/);
});

test("hard submerge watchdog cannot override a valid Finale platform", () => {
  const physics = functionBlock(watchdog, "_physics_process(delta: float) -> void:");
  const supportGuard = physics.indexOf("_finale_route_support_platform(racer)");
  const hardEscape = physics.indexOf("_hard_checkpoint_escape(racer, submerged_depth)");
  assert.ok(supportGuard >= 0 && hardEscape > supportGuard, "Finale route support must be checked before hard escape");
  assert.match(watchdog, /r3_finale_false_water_blocked/);
  assert.match(watchdog, /support_priority=true/);
});

test("genuine Finale water recovery exits to a nearby safe Z6 platform and remains loop-bounded", () => {
  assert.match(watchdog, /func _nearest_finale_recovery_target\(racer: WildDashCharacterController\) -> StringName:/);
  assert.match(watchdog, /FINALE_RECOVERY_MAX_PLANAR_DISTANCE: float = 12\.5/);
  assert.match(watchdog, /FINALE_RECOVERY_IDS/);
  assert.match(watchdog, /r3_finale_recovery_trigger/);
  assert.match(watchdog, /r3_finale_recovery_exit/);
  assert.match(watchdog, /begin_retry_grace/);
  assert.match(watchdog, /racer\.reset_motion\(safe_spawn\)/);
});

test("Crown Nest remains the finish authority with Finale telemetry", () => {
  assert.match(finishAuthority, /FINISH_PLATFORM_ID: StringName = &"CROWN_NEST"/);
  assert.match(finishAuthority, /_complete_final_checkpoint_if_needed\(racer\)/);
  assert.match(finishAuthority, /RaceManager\.can_finish\(racer\)/);
  assert.match(finishAuthority, /RaceManager\.record_finish\(racer\)/);
  assert.match(finishAuthority, /r3_finale_finish_enter/);
  assert.match(finishAuthority, /r3_finale_finish_clear/);
});

test("Round 3 completion still routes through recap before Round 4", () => {
  const order = ["grand_prix", "fruit_collection", "logspire_leap", "push_out", "neon_harbor_race"];
  let last = -1;
  for (const id of order) {
    const index = gameManager.indexOf(`&"${id}"`);
    assert.ok(index > last, `${id} should remain after the previous campaign round`);
    last = index;
  }
  assert.match(gameManager, /set_state\(GameState\.ROUND_RECAP\)/);
  assert.match(gameManager, /func advance_from_round_recap\(\) -> void:/);
});
