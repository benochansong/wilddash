import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(path, 'utf8');

const scene = read('godot/modes/logspire_leap/logspire_leap.tscn');
const integrated = read('godot/modes/logspire_leap/logspire_water_recovery_v13_integrated_qa.gd');
const authority = read('godot/modes/logspire_leap/logspire_water_recovery_v12_reliability_authority.gd');
const v10 = read('godot/modes/logspire_leap/logspire_water_recovery_v10_surface_collision_guard.gd');
const swim = read('godot/modes/logspire_leap/logspire_swim_controller.gd');
const jump = read('godot/modes/logspire_leap/logspire_jump_rebalance_v2_phase_b.gd');
const mobility = read('godot/modes/logspire_leap/logspire_mobility_assist.gd');

test('Round 3 activates the V13 integrated guard over the proven V12/V10 recovery authority', () => {
  assert.match(scene, /logspire_water_recovery_v13_integrated_qa\.gd/);
  assert.match(integrated, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v12_reliability_authority\.gd"/);
  assert.match(authority, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v10_surface_collision_guard\.gd"/);
  assert.match(v10, /VINE_RESCUE_TRIGGER_SECONDS/);
  assert.match(v10, /STAIR_AUTO_ATTACH_RADIUS/);
});

test('WaterRecovery is the single vertical authority while swimming', () => {
  assert.match(authority, /func _enforce_surface_lock/);
  assert.match(authority, /SURFACE_ASCEND_SPEED/);
  assert.match(authority, /_find_safe_surface_position/);
  assert.match(authority, /PhysicsShapeQueryParameters3D/);
  assert.doesNotMatch(swim, /SURFACE_BODY_OFFSET|SURFACE_LOCK_TOLERANCE|move_and_collide\(Vector3\.UP/);
  assert.match(swim, /WaterRecovery is the single Y-axis authority/);
  assert.match(swim, /racer\.velocity\.y = 0\.0/);
  assert.match(integrated, /RECOVERY.*SAFE_EXIT/s);
});

test('deep water is reacquired before basin-floor walking can become normal movement', () => {
  assert.match(authority, /IMMEDIATE_REACQUIRE_DEPTH/);
  assert.match(authority, /DEEP_WATER_GUARD_DEPTH/);
  assert.match(authority, /reason=immediate_capture/);
  assert.match(authority, /reason=deep_guard/);
  assert.match(authority, /LOGSPIRE SURFACE REACQUIRE/);
  assert.match(authority, /LOGSPIRE SURFACE BLOCKED/);
  assert.match(integrated, /DEEP_WATER_FAIL_SECONDS: float = 0\.75/);
  assert.match(integrated, /deep_water_fail/);
});

test('normal recovery priority is Root then Ladder then inherited Vine fail-safe', () => {
  const swimStart = authority.indexOf('func _update_swimming');
  const surfaceStart = authority.indexOf('func _enforce_surface_lock');
  const swimBody = authority.slice(swimStart, surfaceStart);
  assert.ok(swimStart >= 0 && surfaceStart > swimStart);
  assert.match(swimBody, /recovery_type == TARGET_ROOT/);
  assert.match(swimBody, /recovery_type == TARGET_LADDER/);
  assert.doesNotMatch(swimBody, /TARGET_JUMP_OUT/);
  assert.doesNotMatch(swimBody, /super\(racer, delta\)/);
  assert.match(authority, /strict_priority=ROOT_LADDER_VINE/);
  assert.match(v10, /VINE_RESCUE_TRIGGER_SECONDS: float = 4\.80/);
});

test('Root and Ladder traversal require clearance and blocked targets cannot loop', () => {
  assert.match(authority, /func _recovery_target_clear/);
  assert.match(authority, /func _exit_position_clear/);
  assert.match(authority, /func _head_segment_clear/);
  assert.match(authority, /LOGSPIRE ROOT ATTACH/);
  assert.match(authority, /LOGSPIRE LADDER ATTACH/);
  assert.match(authority, /LOGSPIRE RECOVERY EXIT CLEAR/);
  assert.match(authority, /_blocked_targets_by_id/);
  assert.match(authority, /LOGSPIRE RECOVERY RETARGET/);
  assert.match(integrated, /_qa_begin_safe_exit/);
  assert.match(integrated, /await get_tree\(\)\.physics_frame/);
});

test('jump and landing assists yield before base processing while WaterRecovery or SAFE_EXIT owns the player', () => {
  const authorityGuard = jump.indexOf('\n\tif not _authority_allows_jump_assist(player):');
  const waterGuard = jump.indexOf('\n\tif _is_player_water_recovering(player):');
  const superCall = jump.indexOf('\n\tsuper(delta)');
  assert.ok(authorityGuard >= 0 && waterGuard > authorityGuard && superCall > waterGuard);
  assert.match(jump, /should_handle_racer/);
  assert.match(jump, /_landing_correction_used = 0\.0/);
  assert.match(jump, /_jump_buffer_remaining = 0\.0/);
  assert.match(mobility, /_authority_allows_jump_assist\(player\)/);
  assert.match(mobility, /_reset_player_jump_assist_state\(\)/);
});

test('reliability pass does not rebalance global jump power, difficulty or graphics', () => {
  assert.doesNotMatch(integrated, /jump_velocity\s*=/);
  assert.doesNotMatch(authority, /jump_velocity\s*=/);
  assert.doesNotMatch(integrated, /difficulty\s*=/i);
  assert.doesNotMatch(integrated, /GraphicsPhase|WorldArt|RoundVFX/);
});
