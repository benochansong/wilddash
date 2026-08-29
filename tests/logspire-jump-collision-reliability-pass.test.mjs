import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(path, 'utf8');

const scene = read('godot/modes/logspire_leap/logspire_leap.tscn');
const jump = read('godot/modes/logspire_leap/logspire_jump_rebalance_v2_phase_b.gd');
const jumpV3 = read('godot/modes/logspire_leap/logspire_jump_rebalance_v3_titan_tree_accessibility.gd');
const gap = read('godot/modes/logspire_leap/logspire_jump_gap_guard.gd');
const phase3 = read('godot/modes/logspire_leap/logspire_phase3_director_v4_major_collision.gd');
const phase3V5 = read('godot/modes/logspire_leap/logspire_phase3_director_v5_route_clearance.gd');
const phase3V5Core = read('godot/modes/logspire_leap/logspire_phase3_director_v5_route_clearance_core.gd');
const audit = read('godot/modes/logspire_leap/logspire_jump_collision_reliability.gd');
const gameplay = read('godot/modes/logspire_leap/logspire_platform_gameplay.gd');
const water = read('godot/modes/logspire_leap/logspire_water_recovery_v13_integrated_qa.gd');
const waterV15 = read('godot/modes/logspire_leap/logspire_water_recovery_v15_vine_only.gd');

test('Round 3 wires the final collision audit after current jump, V5 route clearance and Vine Rescue layers', () => {
  assert.match(scene, /logspire_jump_rebalance_v3_titan_tree_accessibility\.gd/);
  assert.match(jumpV3, /logspire_jump_rebalance_v2_phase_b\.gd/);
  assert.match(scene, /logspire_jump_gap_guard\.gd/);
  assert.match(scene, /logspire_phase3_director_v5_route_clearance\.gd/);
  assert.match(phase3V5, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v5_route_clearance_core\.gd"/);
  assert.match(phase3V5Core, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v4_major_collision\.gd"/);
  assert.match(scene, /logspire_jump_collision_reliability\.gd/);
  assert.match(scene, /logspire_water_recovery_v15_vine_only\.gd/);
  assert.match(waterV15, /logspire_water_recovery_v14_safe_vine_reentry\.gd/);
  assert.match(water, /logspire_water_recovery_v12_reliability_authority\.gd/);
  const phase3Node = scene.indexOf('[node name="Phase3Director"');
  const auditNode = scene.indexOf('[node name="JumpCollisionAudit"');
  assert.ok(phase3Node >= 0 && auditNode > phase3Node);
});

test('Safe Route final geometry is audited only after both geometry passes settle', () => {
  assert.match(audit, /await get_tree\(\)\.physics_frame/);
  assert.match(audit, /_audit_final_platform_geometry/);
  assert.match(audit, /_audit_safe_jump_pairs/);
  assert.match(audit, /_platform_positions/);
  assert.match(audit, /_platform_sizes/);
  assert.match(audit, /final_geometry_desync/);
  assert.match(gap, /_update_route_geometry\(positions, sizes\)/);
});

test('Jump arc and head clearance use real Physics queries with the racer capsule', () => {
  assert.match(audit, /CapsuleShape3D\.new\(\)/);
  assert.match(audit, /CAPSULE_RADIUS: float = 0\.62/);
  assert.match(audit, /CAPSULE_HEIGHT: float = 1\.90/);
  assert.match(audit, /PhysicsShapeQueryParameters3D\.new\(\)/);
  assert.match(audit, /intersect_shape\(query, 12\)/);
  assert.match(audit, /PhysicsRayQueryParameters3D\.create/);
  assert.match(audit, /LOGSPIRE JUMP CLEARANCE/);
  assert.match(audit, /LOGSPIRE HEAD BLOCK/);
  assert.match(audit, /&"jump_block"/);
  assert.match(audit, /&"head_collision"/);
});

test('Titan and Giant Root collision are gameplay-only and audited against Safe Route', () => {
  assert.match(phase3, /audit_safe_route_collision/);
  assert.match(phase3, /SAFE_ROUTE_COLLISION_MARGIN: float = 1\.45/);
  assert.match(phase3, /TitanTrunkCollision/);
  assert.match(phase3, /TitanRootCollision_/);
  assert.match(phase3, /action=shrink_collision_only/);
  assert.match(phase3, /visual_mesh_unchanged=true/);
  assert.match(phase3, /LOGSPIRE TITAN COLLISION AUDIT/);
  assert.match(phase3, /LOGSPIRE COLLISION OVERLAP/);
  assert.match(phase3V5Core, /_sync_visible_geometry_to_collision/);
  assert.match(phase3V5Core, /_eject_racers_from_major_geometry/);
  assert.match(phase3V5, /_sync_event_geometry_visibility/);
});

test('Landing Magnet and Ledge Catch never move before test_move approves the motion', () => {
  const magnet = jump.slice(jump.indexOf('func _apply_landing_magnet'), jump.indexOf('func _try_begin_ledge_catch'));
  assert.match(magnet, /player\.test_move\(player\.global_transform, motion\)/);
  assert.match(magnet, /player\.move_and_collide\(motion\)/);
  assert.ok(magnet.indexOf('test_move') < magnet.indexOf('move_and_collide'));
  assert.doesNotMatch(magnet, /global_position\s*\+=/);

  const ledgeUpdate = jump.slice(jump.indexOf('func _update_ledge_catch'), jump.indexOf('func _resolve_landing_target'));
  assert.match(ledgeUpdate, /player\.test_move\(player\.global_transform, motion\)/);
  assert.match(ledgeUpdate, /player\.move_and_collide\(motion\)/);
  assert.ok(ledgeUpdate.indexOf('test_move') < ledgeUpdate.indexOf('move_and_collide'));
  assert.match(jump, /LOGSPIRE LANDING BLOCKED/);
  assert.match(jump, /&"ledge_catch"/);
});

test('Moving-platform landing assists use runtime prediction instead of stale static coordinates', () => {
  assert.match(jump, /MOVING_LANDING_PREDICT_MAX_SECONDS: float = 0\.45/);
  assert.match(jump, /_gameplay\.call\("predict_landing", target_id, travel_time\)/);
  assert.match(jump, /_is_moving_target/);
  assert.match(gameplay, /func predict_landing\(platform_id: StringName, travel_time: float\)/);
  assert.match(audit, /_audit_moving_platform_geometry/);
  assert.match(audit, /predicted_landing=true/);
});

test('Reliability pass preserves current jump power, Wild Route and water authority', () => {
  assert.doesNotMatch(audit, /(?:player|racer)\.jump_velocity\s*=/);
  assert.doesNotMatch(phase3, /(?:player|racer)\.jump_velocity\s*=/);
  assert.doesNotMatch(phase3V5Core, /(?:player|racer)\.jump_velocity\s*=/);
  assert.doesNotMatch(phase3V5, /(?:player|racer)\.jump_velocity\s*=/);
  assert.doesNotMatch(jump, /(?:player|racer)\.jump_velocity\s*=/);
  assert.match(audit, /player\.jump_velocity/);
  assert.match(audit, /wild_route_unchanged=true/);
  assert.match(audit, /water_recovery_unchanged=true/);
  assert.match(gap, /wild_exclusive_preserved=true/);
  assert.match(jump, /should_handle_racer/);
});

test('Required collision reliability telemetry remains available', () => {
  const combined = `${audit}\n${phase3}\n${phase3V5Core}\n${phase3V5}\n${jump}`;
  for (const marker of [
    'LOGSPIRE JUMP CLEARANCE',
    'LOGSPIRE HEAD BLOCK',
    'LOGSPIRE COLLISION OVERLAP',
    'LOGSPIRE TITAN COLLISION AUDIT',
    'LOGSPIRE LANDING BLOCKED',
    'LOGSPIRE SAFE ROUTE PASS',
    'LOGSPIRE ROUTE GEOMETRY CLEARANCE READY',
  ]) {
    assert.ok(combined.includes(marker), `missing telemetry: ${marker}`);
  }
});
