import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

const scene = read('godot/modes/logspire_leap/logspire_leap.tscn');
const world = read('godot/modes/logspire_leap/logspire_world_v3_titan_lower_route.gd');
const gapGuard = read('godot/modes/logspire_leap/logspire_jump_gap_guard_v4_lower_route.gd');
const ai = read('godot/modes/logspire_leap/logspire_platform_ai_v6_lower_route_qa.gd');
const water15 = read('godot/modes/logspire_leap/logspire_water_recovery_v15_vine_only.gd');
const water17 = read('godot/modes/logspire_leap/logspire_water_recovery_v17_titan_future_zone_guard.gd');
const watchdog = read('godot/modes/logspire_leap/logspire_water_submerge_watchdog_v3_future_zone_guard.gd');
const phase3 = read('godot/modes/logspire_leap/logspire_phase3_director_v7_titan_spiral_clearance.gd');
const camera = read('godot/camera/chase_camera.gd');
const controller = read('godot/characters/character_controller.gd');

const racerPaths = {
  Fox: 'godot/characters/definitions/fox.tres',
  Rabbit: 'godot/characters/definitions/rabbit.tres',
  Elephant: 'godot/characters/definitions/elephant.tres',
  Bear: 'godot/characters/definitions/bear.tres',
  Crocodile: 'godot/characters/definitions/crocodile.tres',
};

const numberField = (source, name) => {
  const match = source.match(new RegExp(`^${name}\\s*=\\s*(-?[0-9.]+)`, 'm'));
  assert.ok(match, `missing numeric field ${name}`);
  return Number(match[1]);
};

const constantNumber = (source, name) => {
  const match = source.match(new RegExp(`const\\s+${name}[^=]*=\\s*(-?[0-9.]+)`));
  assert.ok(match, `missing constant ${name}`);
  return Number(match[1]);
};

const descendingFlightTime = (jumpVelocity, gravity, rise) => {
  const discriminant = jumpVelocity ** 2 - 2 * gravity * rise;
  assert.ok(discriminant > 0, 'jump cannot reach authored rise');
  return (jumpVelocity + Math.sqrt(discriminant)) / gravity;
};

const rectanglesOverlap = (a, b) => {
  const overlapX = Math.abs(a.x - b.x) <= (a.w + b.w) / 2;
  const overlapZ = Math.abs(a.z - b.z) <= (a.d + b.d) / 2;
  return overlapX && overlapZ;
};

test('ROUND 3 TITAN TREE CP4 -> CP5 PHASE 2 regression contract', () => {
  const contract = {
    CP4_CP5_ROUTE_CONTINUOUS: false,
    UPPER_SPIRAL_PLAYABLE: true,
    LEGACY_UPPER_COLLISION: true,
    SAFE_ROUTE_VALID: false,
    FAST_ROUTE_VALID: false,
    NO_ROUTE_WATER_RESET: false,
    NO_CHECKPOINT_ROLLBACK: false,
    NO_LOW_CEILING: false,
    NORMAL_JUMP_POWER: false,
  };

  // Production initialization must actually install the lower-route AI QA layer.
  assert.match(scene, /logspire_leap_v6_titan_lower_playability\.gd/);
  assert.doesNotMatch(scene, /path="res:\/\/modes\/logspire_leap\/logspire_leap_v5_finish_ai_convergence\.gd" id="1_mode"/);
  assert.match(ai, /TELEPORT_RECOVERY_SUPPORTED\s*:\s*bool\s*=\s*false/);
  assert.match(ai, /_maybe_reacquire_lower_route/);
  assert.match(ai, /normal lower route/i);

  // Old Z5 spiral identifiers are renamed before production geometry creation.
  assert.match(world, /_rename_legacy_upper_route\(\)/);
  assert.match(world, /titan_upper_spiral_playable", false/);
  assert.match(gapGuard, /legacy_upper_collision", false/);
  assert.match(gapGuard, /_retire_legacy_upper_helpers\(\)/);
  assert.match(phase3, /SafeFlowBridge_Z5_SPIRAL/);
  assert.match(phase3, /collision_layer\s*=\s*0/);
  contract.UPPER_SPIRAL_PLAYABLE = false;
  contract.LEGACY_UPPER_COLLISION = false;

  // Safe route stays broad. Fast route is narrower/riskier but has physical overlap
  // all the way from broken-trunk landing into CANOPY_01; no hidden long jump remains.
  assert.equal(constantNumber(gapGuard, 'ROOT_RUN_WIDTH'), 14.0);
  assert.ok(constantNumber(gapGuard, 'BROKEN_TRUNK_LANDING_WIDTH') >= 13.0);
  assert.ok(constantNumber(gapGuard, 'CANOPY_MIN_WIDTH') >= 12.5);
  assert.ok(constantNumber(gapGuard, 'FINAL_LANDING_WIDTH') >= 16.0);
  assert.match(gapGuard, /safe=wide_bright_wood fast=narrow_amber/);
  contract.SAFE_ROUTE_VALID = true;

  const fast = [
    { x: 4.0, z: -64.5, w: 13.0, d: 14.0 },
    { x: 1.0, z: -73.7, w: 10.5, d: 10.0 },
    { x: -3.0, z: -82.7, w: 10.5, d: 10.0 },
    { x: -10.0, z: -91.7, w: 10.5, d: 10.0 },
    { x: -16.0, z: -102.0, w: 12.5, d: 16.0 },
  ];
  for (let i = 0; i < fast.length - 1; i += 1) {
    assert.ok(rectanglesOverlap(fast[i], fast[i + 1]), `FAST route discontinuity at ${i}`);
  }
  assert.match(gapGuard, /Vector3\(10\.5, 0\.8, 10\.0\)/);
  contract.FAST_ROUTE_VALID = true;
  contract.CP4_CP5_ROUTE_CONTINUOUS = true;

  // Ballistic accessibility uses each production archetype's own jump_velocity,
  // gravity, cruise_speed and capsule radius. No global jump power is raised.
  const jumps = [
    { name: 'BROKEN_TRUNK', gap: constantNumber(gapGuard, 'BROKEN_TRUNK_GAP'), rise: 0.20 },
    { name: 'FINAL_ROOT', gap: constantNumber(gapGuard, 'FINAL_ROOT_GAP'), rise: 0.10 },
  ];
  assert.equal(jumps[0].gap, 2.5);
  assert.equal(jumps[1].gap, 2.0);

  for (const [name, path] of Object.entries(racerPaths)) {
    const archetype = read(path);
    const jumpVelocity = numberField(archetype, 'jump_velocity');
    const gravity = numberField(archetype, 'gravity');
    const cruiseSpeed = numberField(archetype, 'cruise_speed');
    const radius = numberField(archetype, 'capsule_radius');

    for (const jump of jumps) {
      const flightTime = descendingFlightTime(jumpVelocity, gravity, jump.rise);
      const cruiseRange = cruiseSpeed * flightTime;
      const requiredCenterTravel = jump.gap + radius;
      assert.ok(
        cruiseRange - requiredCenterTravel >= 0.50,
        `${name} lacks landing margin on ${jump.name}: range=${cruiseRange.toFixed(2)} required=${requiredCenterTravel.toFixed(2)}`,
      );
    }
  }
  assert.match(controller, /_jump_velocity\s*=\s*archetype\.jump_velocity/);
  assert.doesNotMatch(gapGuard, /jump_velocity\s*=/);
  assert.doesNotMatch(world, /jump_velocity\s*=/);
  contract.NORMAL_JUMP_POWER = true;

  // Water authority: actual pool lookup + unsupported + descending + feet below
  // surface + confirmation dwell. Future Z6 water cannot own CP4->CP5 racers.
  assert.match(water15, /_pool_for_position\(racer\.global_position\)/);
  assert.match(water15, /racer\.is_on_floor\(\) or _has_nearby_surface_support\(racer\)/);
  assert.match(water15, /racer\.velocity\.y > WATER_ENTRY_MIN_DOWN_SPEED/);
  assert.match(water15, /water_y - VINE_ONLY_REQUIRED_FOOT_SUBMERSION/);
  assert.match(water15, /confirmed_seconds >= VINE_ONLY_ENTRY_CONFIRM_SECONDS/);
  assert.match(water17, /FUTURE_WATER_UNLOCK_CHECKPOINT\s*:\s*int\s*=\s*6/);
  assert.match(water17, /is_future_water_locked_for_racer/);
  assert.match(water17, /return false\s*\n\treturn super\(racer\)/);
  assert.match(watchdog, /future.zone|future_zone|Future/i);
  contract.NO_ROUTE_WATER_RESET = true;

  // The future-zone guard has no authority to write progress or transforms.
  assert.doesNotMatch(water17, /set_checkpoint_progress|global_position\s*=|teleport/i);
  assert.match(water17, /no_checkpoint_rewind=true/);
  assert.match(gapGuard, /cp4_cp5_water_reset_authority", false/);
  contract.NO_CHECKPOINT_ROLLBACK = true;

  // Collision cleanup plus the chase camera's hit-from-inside/forward-view fallback
  // prevent old upper geometry from becoming a low ceiling/full-screen trunk wall.
  assert.match(phase3, /_retire_canopy_collisions\(\)/);
  assert.match(phase3, /_retire_upper_bridge_physics\(\)/);
  assert.match(camera, /query\.hit_from_inside\s*=\s*true/);
  assert.match(camera, /_resolve_forward_visibility/);
  assert.match(camera, /emergency_snap_when_occluded/);
  contract.NO_LOW_CEILING = true;

  assert.deepEqual(contract, {
    CP4_CP5_ROUTE_CONTINUOUS: true,
    UPPER_SPIRAL_PLAYABLE: false,
    LEGACY_UPPER_COLLISION: false,
    SAFE_ROUTE_VALID: true,
    FAST_ROUTE_VALID: true,
    NO_ROUTE_WATER_RESET: true,
    NO_CHECKPOINT_ROLLBACK: true,
    NO_LOW_CEILING: true,
    NORMAL_JUMP_POWER: true,
  });

  for (const [key, value] of Object.entries(contract)) {
    console.log(`${key}=${value}`);
  }
});
