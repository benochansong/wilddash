import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(path, 'utf8');

const selectScene = read('godot/scenes/character_select.tscn');
const select = read('godot/scenes/character_select_spectator.gd');
const helper = read('godot/scripts/spectator_mode.gd');
const camera = read('godot/camera/spectator_camera_director.gd');
const r1Scene = read('godot/modes/grand_prix/grand_prix.tscn');
const r1 = read('godot/modes/grand_prix/grand_prix_v8_spectator.gd');
const r2Scene = read('godot/modes/fruit_collection/fruit_collection.tscn');
const r2 = read('godot/modes/fruit_collection/fruit_frenzy_v21_spectator.gd');
const r3Scene = read('godot/modes/logspire_leap/logspire_leap.tscn');
const r3 = read('godot/modes/logspire_leap/logspire_leap_v7_spectator.gd');
const r4Scene = read('godot/modes/push_out/push_out.tscn');
const r4 = read('godot/modes/push_out/wild_rumble_round4_spectator.gd');
const r5Scene = read('godot/modes/neon_harbor_race/neon_harbor_race.tscn');
const r5 = read('godot/modes/neon_harbor_race/neon_harbor_race_v9_spectator.gd');

test('production Character Select exposes AI Battle and normal START clears spectator state', () => {
  assert.match(selectScene, /character_select_spectator\.gd/);
  assert.match(select, /WATCH AI BATTLE/);
  assert.match(select, /func _start_spectator_run\(\)/);
  assert.match(select, /SPECTATOR_MODE\.set_enabled\(true\)/);
  assert.match(select, /func _start_run\(\)[\s\S]*SPECTATOR_MODE\.set_enabled\(false\)/);
  assert.match(select, /super\._start_run\(\)/);
});

test('spectator state persists through campaign scenes without changing GameManager campaign API', () => {
  assert.match(helper, /wilddash_spectator_mode/);
  assert.match(helper, /GameManager\.set_meta/);
  assert.match(helper, /GameManager\.get_meta/);
  assert.match(helper, /install_camera/);
});

test('spectator camera supports manual and automatic racer switching', () => {
  assert.match(camera, /AUTO_SWITCH_SECONDS: float = 7\.5/);
  assert.match(camera, /KEY_LEFT/);
  assert.match(camera, /KEY_RIGHT, KEY_TAB/);
  assert.match(camera, /SPECTATOR TARGET SWITCH/);
  assert.match(camera, /not racer\.finished/);
  assert.match(camera, /SPECTATOR MODE · WATCHING/);
});

test('all five production rounds are wired through thin spectator adapters', () => {
  assert.match(r1Scene, /grand_prix_v8_spectator\.gd/);
  assert.match(r2Scene, /fruit_frenzy_v21_spectator\.gd/);
  assert.match(r3Scene, /logspire_leap_v7_spectator\.gd/);
  assert.match(r4Scene, /wild_rumble_round4_spectator\.gd/);
  assert.match(r5Scene, /neon_harbor_race_v9_spectator\.gd/);
  assert.match(r1, /extends "res:\/\/modes\/grand_prix\/grand_prix_v7_wild_moments\.gd"/);
  assert.match(r2, /extends "res:\/\/modes\/fruit_collection\/fruit_frenzy_v20_economy_combat_ai\.gd"/);
  assert.match(r3, /extends "res:\/\/modes\/logspire_leap\/logspire_leap_v6_titan_lower_playability\.gd"/);
  assert.match(r4, /extends "res:\/\/modes\/push_out\/wild_rumble_round4_wild_moments\.gd"/);
  assert.match(r5, /extends "res:\/\/modes\/neon_harbor_race\/neon_harbor_race_v8_round5_campaign\.gd"/);
});

test('race rounds AI-drive the logical featured racer and preserve finish authority', () => {
  for (const source of [r1, r3, r5]) {
    assert.match(source, /spawn_ai_driver\(/);
    assert.match(source, /racer == player/);
    assert.match(source, /_on_player_finished\(rank\)/);
    assert.match(source, /SPECTATOR_MODE\.install_camera\(self, racers\)/);
  }
});

test('arena rounds add the logical featured racer to existing AI decision fields only in spectator adapters', () => {
  assert.match(r2, /ai_racers\.append\(player\)/);
  assert.match(r2, /ai_personalities\.append\(PERSONALITY_BALANCED\)/);
  assert.match(r4, /ai_racers\.append\(player\)/);
  assert.match(r4, /_ai_push_cooldowns\.append/);
});

test('spectator adapters do not rebalance core gameplay or reactivate graphics experiments', () => {
  const combined = [select, helper, camera, r1, r2, r3, r4, r5].join('\n');
  assert.doesNotMatch(combined, /jump_velocity\s*=/);
  assert.doesNotMatch(combined, /difficulty\s*=/i);
  assert.doesNotMatch(combined, /GraphicsPhase2|GraphicsPhase3|WorldArt|RoundVFX/);
  assert.doesNotMatch(combined, /change_scene_to_file\(/);
});
