import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const path = 'godot/modes/logspire_leap/logspire_jump_collision_reliability.gd';
const source = fs.readFileSync(path, 'utf8');

test('Round 3 collision audit resolves World3D through its Node3D world owner', () => {
  assert.match(source, /^extends Node$/m);
  assert.match(source, /func _physics_world\(\) -> World3D:/);
  assert.match(source, /return _world\.get_world_3d\(\)/);
  assert.doesNotMatch(source, /\tif get_world_3d\(\) == null:/);
  assert.doesNotMatch(source, /= get_world_3d\(\)\.direct_space_state/);
});

test('Round 3 player lookup ignores freed racer references before casting', () => {
  assert.match(source, /racer_value == null or not is_instance_valid\(racer_value\)/);
});
