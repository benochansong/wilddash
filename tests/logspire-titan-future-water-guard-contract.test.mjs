import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const scene = readFileSync('godot/modes/logspire_leap/logspire_leap.tscn', 'utf8');
const water = readFileSync(
  'godot/modes/logspire_leap/logspire_water_recovery_v17_titan_future_zone_guard.gd',
  'utf8',
);
const watchdog = readFileSync(
  'godot/modes/logspire_leap/logspire_water_submerge_watchdog_v3_future_zone_guard.gd',
  'utf8',
);

test('Round 3 production scene wires both Titan future-zone water guards', () => {
  assert.match(scene, /logspire_water_recovery_v17_titan_future_zone_guard\.gd/);
  assert.match(scene, /logspire_water_submerge_watchdog_v3_future_zone_guard\.gd/);
});

test('future Z6 water cannot own a racer before the Z6_START checkpoint', () => {
  assert.match(water, /FUTURE_WATER_ZONE_INDEX: int = 5/);
  assert.match(water, /FUTURE_WATER_UNLOCK_CHECKPOINT: int = 6/);
  assert.match(water, /RaceManager\.get_checkpoint_progress\(racer\) < FUTURE_WATER_UNLOCK_CHECKPOINT/);
  assert.match(water, /no_checkpoint_rewind=true/);
  assert.match(water, /_vine_only_entry_candidate_since_msec_by_id\.erase/);
});

test('guard layer does not move racers or mutate checkpoint progress', () => {
  assert.doesNotMatch(water, /reset_motion\s*\(/);
  assert.doesNotMatch(water, /_hard_checkpoint_escape\s*\(/);
  assert.doesNotMatch(water, /global_position\s*=/);
  assert.doesNotMatch(water, /set_checkpoint|checkpoint_progress\s*=/);
});

test('secondary watchdog defers hard escape while primary future-zone lock is active', () => {
  assert.match(watchdog, /is_future_water_locked_for_racer/);
  assert.match(watchdog, /func _primary_water_recovery_active/);
  assert.match(watchdog, /hard_checkpoint_escape=false/);
  assert.match(watchdog, /return true/);
});
