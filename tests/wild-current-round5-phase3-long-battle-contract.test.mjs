import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

const scene = read('godot/modes/wild_current/wild_current.tscn');
const phase3 = read('godot/modes/wild_current/wild_current_race_phase3_long_battle.gd');
const swimmer3 = read('godot/modes/wild_current/wild_current_swimmer_phase3_item_combat.gd');
const itemBox = read('godot/items/item_box.gd');

test('Round 5 Phase 3 is the production long-river battle layer', () => {
  assert.match(scene, /wild_current_race_phase3_long_battle\.gd/);
  assert.match(phase3, /LONG_FINISH_Z: float = -1040\.0/);
  assert.match(phase3, /LONG_MIN_Z: float = -1075\.0/);
  assert.match(phase3, /target_track=1\.3km/);
  assert.match(phase3, /LONG_FINAL_SPRINT_Z: float = -955\.0/);
});

test('the long route has ten checkpoints and substantially more route samples', () => {
  const routeBlock = phase3.match(/func _build_route_points[\s\S]*?func _build_checkpoint_positions/)[0];
  const checkpointBlock = phase3.match(/func _build_checkpoint_positions[\s\S]*?func _build_water_world/)[0];
  assert.ok((routeBlock.match(/Vector3\(/g) || []).length >= 30);
  assert.equal((checkpointBlock.match(/Vector3\(/g) || []).length, 10);
});

test('item boxes are distributed as twelve three-lane battle stations', () => {
  assert.match(phase3, /ITEM_STATION_LANES: Array\[float\] = \[-8\.0, 0\.0, 8\.0\]/);
  const stations = phase3.match(/ITEM_STATION_Z: Array\[float\] = \[([^\]]+)\]/)?.[1] ?? '';
  assert.equal((stations.match(/-?\d+\.0/g) || []).length, 12);
  assert.match(phase3, /ITEM_BOX_SCENE/);
  assert.match(phase3, /r5_item_box_network/);
  assert.match(phase3, /weighted_by_rank=true comeback_items=true/);
  assert.match(itemBox, /grant_weighted_item/);
});

test('Phase 3 enables player and AI item use while swimming', () => {
  assert.match(swimmer3, /InputManager\.consume_item\(\)/);
  assert.match(swimmer3, /ItemSystem\.use_held_item\(racer\)/);
  assert.match(swimmer3, /should_ai_use_item_phase3/);
  assert.match(swimmer3, /r5_water_item_use/);
  assert.match(swimmer3, /ItemSystem\.has_effect\(racer, &"dash"\)/);
  assert.match(swimmer3, /ItemSystem\.has_effect\(racer, &"slow"\)/);
  assert.match(swimmer3, /racer\.get_knockback_velocity\(\)/);
  assert.match(swimmer3, /racer\.decay_knockback\(delta\)/);
});

test('leader pressure is visible, bounded, one-shot per gate and never teleports', () => {
  for (const gate of ['LeaderWaveA', 'LeaderWaveB', 'LeaderWaveC', 'LeaderWaveD', 'LeaderWaveE']) {
    assert.match(phase3, new RegExp(gate));
  }
  assert.match(phase3, /LEADER_WAVE_POWER: float = 6\.2/);
  assert.match(phase3, /LEADER_WAVE_RETENTION: float = 0\.84/);
  assert.match(phase3, /leader_only=true one_shot_per_gate=true teleport=false/);
  assert.match(phase3, /RaceManager\.get_rank\(racer\) == 1/);
  assert.match(phase3, /apply_water_combat_push/);
  assert.doesNotMatch(phase3, /reset_motion\(/);
});

test('the second half adds multiple obstacle families and route-choice zones', () => {
  for (const token of [
    'LongLogC', 'LongLogI', 'LongRockD', 'LongRockI',
    'LongReedsWestA', 'LongReedsEastB', 'LongDebrisD', 'LongDebrisG',
    'WhirlpoolDriftwood', 'WhirlpoolMangrove', 'WhirlpoolStorm',
    'DRIFTWOOD GAUNTLET', 'STONE SLALOM', 'MANGROVE MAZE', 'STORM CHANNEL', 'FINAL BATTLE SPRINT',
  ]) assert.match(phase3, new RegExp(token));
  assert.match(phase3, /safe_fast_risk=true/);
});
