import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

const project = read('godot/project.godot');
const pressure = read('godot/systems/item_system_rc9_round5_leader_pressure.gd');
const torpedo = read('godot/items/river_torpedo.gd');
const storm = read('godot/items/storm_bomb.gd');
const swimmer = read('godot/modes/wild_current/wild_current_swimmer_phase3_item_combat.gd');

test('production ItemSystem layers Round 5 leader pressure over existing RC9 and Round 1 behavior', () => {
  assert.match(project, /ItemSystem="\*res:\/\/systems\/item_system_rc9_round5_leader_pressure\.gd"/);
  assert.match(pressure, /extends "res:\/\/systems\/item_system_rc9_round1_impact\.gd"/);
  assert.match(pressure, /return super\.roll_item_for_rank\(rank, total, history\)/);
  assert.match(pressure, /get_current_round_id\(\) == &"wild_current"/);
});

test('Round 5 has four real anti-leader inventory items', () => {
  for (const item of ['river_torpedo', 'storm_bomb', 'current_anchor', 'tidal_barrage']) {
    assert.match(pressure, new RegExp(`&"${item}"`));
  }
  assert.match(pressure, /ROUND5_LEADER_ITEM_IDS/);
  assert.match(pressure, /RIVER TORPEDO/);
  assert.match(pressure, /STORM BOMB/);
  assert.match(pressure, /CURRENT ANCHOR/);
  assert.match(pressure, /TIDAL BARRAGE/);
  assert.match(pressure, /get_item_count\(\)[\s\S]*ROUND5_LEADER_ITEM_IDS\.size\(\)/);
});

test('first place cannot roll anti-leader items and runaway gaps increase comeback weight', () => {
  assert.match(pressure, /if rank <= 1:[\s\S]*return 0\.0/);
  assert.match(pressure, /leader_gap >= 22\.0/);
  assert.match(pressure, /leader_gap >= 45\.0/);
  assert.match(pressure, /leader_gap >= 80\.0/);
  assert.match(pressure, /return 1\.90/);
  assert.match(pressure, /r5_leader_item_roll/);
});

test('river torpedo is an actual long-range homing projectile that resolves through shared shield authority', () => {
  assert.match(pressure, /preload\("res:\/\/items\/river_torpedo\.gd"\)/);
  assert.match(torpedo, /class_name WildDashRiverTorpedo/);
  assert.match(torpedo, /SPEED: float = 52\.0/);
  assert.match(torpedo, /target_racer\.global_position/);
  assert.match(torpedo, /ItemSystem\.apply_attack/);
  assert.match(torpedo, /r5_river_torpedo_launch/);
  assert.match(torpedo, /r5_river_torpedo_hit/);
  assert.match(torpedo, /shield_counter=true/);
  assert.doesNotMatch(torpedo, /target_racer\.global_position\s*=/);
});

test('storm bomb gives the leader a readable warning before the strike', () => {
  assert.match(pressure, /preload\("res:\/\/items\/storm_bomb\.gd"\)/);
  assert.match(storm, /class_name WildDashStormBomb/);
  assert.match(storm, /WARNING_SECONDS: float = 1\.25/);
  assert.match(storm, /StormBombWarningDisc/);
  assert.match(storm, /StormBombWarningBeacon/);
  assert.match(storm, /ItemSystem\.apply_attack/);
  assert.match(storm, /r5_storm_bomb_warning/);
  assert.match(storm, /r5_storm_bomb_strike/);
  assert.match(storm, /shield_counter=true/);
});

test('current anchor directly disrupts first place while tidal barrage compresses the top three', () => {
  assert.match(pressure, /_use_current_anchor/);
  assert.match(pressure, /ANCHOR_SLOW: float = 0\.50/);
  assert.match(pressure, /ANCHOR_KNOCKBACK: float = 3\.6/);
  assert.match(pressure, /r5_current_anchor_resolve/);
  assert.match(pressure, /_use_tidal_barrage/);
  assert.match(pressure, /for target_rank in range\(1, 4\)/);
  assert.match(pressure, /BARRAGE_BASE_KNOCKBACK: float = 6\.4/);
  assert.match(pressure, /r5_tidal_barrage_resolve/);
});

test('Round 5 AI fires leader-pressure items globally instead of waiting for a nearby rival', () => {
  assert.match(swimmer, /is_round5_leader_pressure_item/);
  assert.match(swimmer, /leader_pressure_item/);
  assert.match(swimmer, /RaceManager\.get_rank\(racer\) <= 1/);
  assert.match(swimmer, /leader_pressure=%s/);
  const leaderBranch = swimmer.match(/if leader_pressure_item:[\s\S]*?elif provider/)[0];
  assert.doesNotMatch(leaderBranch, /16\.0|nearby|distance/);
});

test('leader pressure remains physical item combat rather than hidden rubber banding', () => {
  assert.match(pressure, /hidden_rubber_band=false/);
  assert.doesNotMatch(pressure, /global_position\s*=\s*target/);
  assert.doesNotMatch(pressure, /record_checkpoint|record_finish/);
  assert.doesNotMatch(pressure, /player.*slowdown/i);
});
