import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(path, 'utf8');

const scene = read('godot/modes/logspire_leap/logspire_leap.tscn');
const authority = read('godot/modes/logspire_leap/logspire_water_recovery_v12_reliability_authority.gd');
const v10 = read('godot/modes/logspire_leap/logspire_water_recovery_v10_surface_collision_guard.gd');
const swim = read('godot/modes/logspire_leap/logspire_swim_controller.gd');
const jump = read('godot/modes/logspire_leap/logspire_jump_rebalance_v2_phase_b.gd');
const mobility = read('godot/modes/logspire_leap/logspire_mobility_assist.gd');

test('Round 3 activates the reliability authority while preserving V10 as its proven base', () => {
  assert.match(scene, /logspire_water_recovery_v12_reliability_authority\.gd/);
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
});

test('deep water is reacquired before basin-floor walking can become normal movement', () => {
  assert.match(authority, /IMMEDIATE_REACQUIRE_DEPTH/);
  assert.match(authority, /DEEP_WATER_GUARD_DEPTH/);
  assert.match(authority, /reason=immediate_capture/);
  assert.match(authority, /reason=deep_guard/);
  assert.match(authority, /LOGSPIRE SURFACE REACQUIRE/);
  assert.match(authority, /LOGSPIRE SURFACE BLOCKED/);
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
});

test('jump and landing assists yield before base processing while WaterRecovery owns the player', () => {
  const waterGuard = jump.indexOf('\n\tif _is_player_water_recovering(player):');
  const superCall = jump.indexOf('\n\tsuper(delta)');
  assert.ok(waterGuard >= 0 && superCall >= 0 && waterGuard < superCall);
  assert.match(jump, /_landing_correction_used = 0\.0/);
  assert.match(jump, /_jump_buffer_remaining = 0\.0/);
  assert.match(mobility, /if _is_player_water_recovering\(player\):/);
  assert.match(mobility, /_reset_player_jump_assist_state\(\)/);
});

test('reliability pass does not rebalance global jump power, difficulty or graphics', () => {
  assert.doesNotMatch(authority, /jump_velocity\s*=/);
  assert.doesNotMatch(authority, /difficulty\s*=/i);
  assert.doesNotMatch(authority, /GraphicsPhase|WorldArt|RoundVFX/);
});
