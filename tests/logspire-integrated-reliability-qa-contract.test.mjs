import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';

const read = (path) => readFileSync(path, 'utf8');

const scene = read('godot/modes/logspire_leap/logspire_leap.tscn');
const mode = read('godot/modes/logspire_leap/logspire_leap_v4_phase_b.gd');
const waterV15 = read('godot/modes/logspire_leap/logspire_water_recovery_v15_vine_only.gd');
const waterV14 = read('godot/modes/logspire_leap/logspire_water_recovery_v14_safe_vine_reentry.gd');
const waterV13 = read('godot/modes/logspire_leap/logspire_water_recovery_v13_integrated_qa.gd');
const waterV12 = read('godot/modes/logspire_leap/logspire_water_recovery_v12_reliability_authority.gd');
const waterV10 = read('godot/modes/logspire_leap/logspire_water_recovery_v10_surface_collision_guard.gd');
const jump = read('godot/modes/logspire_leap/logspire_jump_rebalance_v2_phase_b.gd');
const jumpV3 = read('godot/modes/logspire_leap/logspire_jump_rebalance_v3_titan_tree_accessibility.gd');
const mobility = read('godot/modes/logspire_leap/logspire_mobility_assist.gd');
const recovery = read('godot/modes/logspire_leap/logspire_recovery_system.gd');
const audit = read('godot/modes/logspire_leap/logspire_jump_collision_reliability.gd');
const phase3 = read('godot/modes/logspire_leap/logspire_phase3_director_v4_major_collision.gd');
const gameManager = read('godot/scripts/game_manager.gd');

test('R3 integrated QA keeps proven recovery authority under safe Vine-only production adapters', () => {
  assert.match(scene, /logspire_water_recovery_v15_vine_only\.gd/);
  assert.match(waterV15, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v14_safe_vine_reentry\.gd"/);
  assert.match(waterV14, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v13_integrated_qa\.gd"/);
  assert.match(waterV13, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v12_reliability_authority\.gd"/);
  assert.match(waterV12, /logspire_water_recovery_v10_surface_collision_guard\.gd/);
  assert.match(scene, /logspire_jump_rebalance_v3_titan_tree_accessibility\.gd/);
  assert.match(jumpV3, /logspire_jump_rebalance_v2_phase_b\.gd/);
  assert.doesNotMatch(waterV13, /jump_velocity\s*=/);
  assert.doesNotMatch(waterV13, /difficulty\s*=/i);
  assert.doesNotMatch(waterV13, /GraphicsPhase|WorldArt|RoundVFX/);
});

test('QA matrix explicitly covers six zones and 10, 15, 18 racer profiles', () => {
  assert.match(mode, /QA_RACER_COUNTS: Array\[int\] = \[10, 15, 18\]/);
  for (const zone of ['ZONE_1', 'ZONE_2', 'ZONE_3', 'ZONE_4', 'TITAN_TREE', 'FINALE']) {
    assert.ok(mode.includes(`"${zone}"`), `missing QA zone: ${zone}`);
  }
  assert.match(mode, /expected=10\|15\|18/);
  assert.match(mode, /manual_profiles_required=10\|15\|18/);
});

test('all requested per-zone reliability counters are present', () => {
  for (const metric of [
    'water_enter',
    'surface_reacquire',
    'deep_water_fail',
    'root_success',
    'ladder_success',
    'recovery_stuck',
    'jump_block',
    'head_collision',
    'ledge_catch',
    'ai_fall',
    'player_fall',
  ]) {
    assert.ok(mode.includes(`&"${metric}"`), `missing QA metric key: ${metric}`);
    assert.ok(mode.includes(`${metric}=%d`), `missing QA zone report field: ${metric}`);
  }
  assert.match(waterV13, /_qa_record_metric\(&"water_enter", racer, zone\)/);
  assert.match(waterV13, /_qa_record_metric\(&"player_fall" if racer\.is_player else &"ai_fall", racer, zone\)/);
});

test('motion authority is explicit and the registry never writes racer transforms', () => {
  for (const state of ['NORMAL', 'AIRBORNE', 'WATER', 'RECOVERY', 'SAFE_EXIT']) {
    assert.ok(mode.includes(`&"${state}"`), `missing motion authority state: ${state}`);
  }
  assert.match(mode, /QA_PROTECTED_STATES/);
  assert.match(mode, /QA_STATE_WATER/);
  assert.match(mode, /QA_STATE_RECOVERY/);
  assert.match(mode, /QA_STATE_SAFE_EXIT/);
  assert.doesNotMatch(mode, /(?:racer|player)\.global_position\s*=/);
  assert.doesNotMatch(mode, /reset_motion\(/);
});

test('jump and mobility helpers yield before base assist processing during protected authority', () => {
  const authorityGuard = jump.indexOf('if not _authority_allows_jump_assist(player):');
  const waterGuard = jump.indexOf('if _is_player_water_recovering(player):');
  const superCall = jump.indexOf('\n\tsuper(delta)');
  assert.ok(authorityGuard >= 0 && waterGuard > authorityGuard && superCall > waterGuard);
  assert.match(jump, /should_handle_racer/);
  assert.match(jump, /reliability_jump_assist_allowed/);
  assert.match(mobility, /_authority_allows_jump_assist\(player\)/);
  assert.match(mobility, /should_handle_racer/);
});

test('water and checkpoint emergency exits have explicit bounded termination', () => {
  assert.match(waterV10, /VINE_RESCUE_TRIGGER_SECONDS: float = 4\.80/);
  assert.match(waterV10, /VINE_RESCUE_DURATION: float = 1\.00/);
  assert.match(waterV10, /RECOVERY_HARD_LIMIT_SECONDS: float = 7\.00/);
  assert.match(waterV13, /DEEP_WATER_FAIL_SECONDS: float = 0\.75/);
  assert.match(waterV13, /_qa_begin_safe_exit/);
  assert.match(waterV13, /await get_tree\(\)\.physics_frame/);
  assert.match(recovery, /checkpoint_recovery_pending/);
  assert.match(recovery, /RECOVERY_DELAY_SECONDS: float = 0\.90/);
  assert.match(recovery, /&"SAFE_EXIT"/);
  assert.match(recovery, /checkpoint_safe_exit_complete/);
});

test('collision audit covers required jumps, moving platforms, Titan collision and QA counters', () => {
  assert.match(audit, /_audit_safe_jump_pairs/);
  assert.match(audit, /_audit_moving_platform_geometry/);
  assert.match(audit, /predicted_landing=true/);
  assert.match(audit, /&"jump_block"/);
  assert.match(audit, /&"head_collision"/);
  assert.match(jump, /&"ledge_catch"/);
  assert.match(phase3, /audit_safe_route_collision/);
  assert.match(phase3, /TitanTrunkCollision/);
  assert.match(phase3, /TitanRootCollision_/);
  assert.match(phase3, /visual_mesh_unchanged=true/);
});

test('R3 finish still routes through Round Recap and then loads R4 without changing campaign order', () => {
  const r3 = gameManager.indexOf('&"logspire_leap"');
  const r4 = gameManager.indexOf('&"push_out"');
  assert.ok(r3 >= 0 && r4 > r3);
  assert.match(gameManager, /ROUND_RECAP,/);
  assert.match(gameManager, /ROUND_RECAP_SCENE/);
  assert.match(gameManager, /set_state\(GameState\.ROUND_RECAP\)/);
  assert.match(gameManager, /func advance_from_round_recap\(\)/);
  assert.match(gameManager, /current_round_index \+= 1/);
  assert.match(gameManager, /call_deferred\("_load_current_round"\)/);
});