import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(path, 'utf8');
const gameManager = read('godot/scripts/game_manager.gd');
const round2 = read('godot/modes/fruit_collection/fruit_frenzy_v16_clear_balance.gd');
const recapScene = read('godot/scenes/round_recap.tscn');
const recap = read('godot/scenes/round_recap.gd');
const round3Scene = read('godot/modes/logspire_leap/logspire_leap.tscn');
const phase3V5 = read('godot/modes/logspire_leap/logspire_phase3_director_v5_route_clearance.gd');
const vineOnly = read('godot/modes/logspire_leap/logspire_water_recovery_v15_vine_only.gd');
const safeVine = read('godot/modes/logspire_leap/logspire_water_recovery_v14_safe_vine_reentry.gd');
const waterIntegrated = read('godot/modes/logspire_leap/logspire_water_recovery_v13_integrated_qa.gd');
const waterAuthority = read('godot/modes/logspire_leap/logspire_water_recovery_v12_reliability_authority.gd');

test('Round 2 completion still hands its result to the campaign manager', () => {
  assert.match(round2, /finish_mode\(success, player_score/);
  assert.match(gameManager, /ResultManager\.record_round_result\(mode_id, success, score, details\)/);
  assert.match(gameManager, /call_deferred\("_transition_after_round"\)/);
});

test('recap cannot freeze when a finished round leaves the tree paused', () => {
  assert.match(recapScene, /\[node name="RoundRecap" type="Node3D"\]\nprocess_mode = 3/);
  assert.match(recap, /RECAP_TOTAL_SECONDS: float = 9\.0/);
  assert.match(recap, /GameManager\.advance_from_round_recap\(\)/);
});

test('campaign order advances Round 2 recap directly to Logspire Round 3', () => {
  const fruitIndex = gameManager.indexOf('&"fruit_collection"');
  const logspireIndex = gameManager.indexOf('&"logspire_leap"');
  assert.ok(fruitIndex >= 0 && logspireIndex > fruitIndex, 'Logspire must follow Fruit Collection');
  assert.match(gameManager, /current_round_index \+= 1/);
  assert.match(gameManager, /call_deferred\("_load_current_round"\)/);
});

test('Round 3 campaign scene uses Vine-only V15 and V5 route clearance over the proven reliability stack', () => {
  assert.match(round3Scene, /P0 CAMPAIGN-SAFE ROUND 3/);
  assert.match(round3Scene, /logspire_leap_v4_phase_b\.gd/);
  assert.match(round3Scene, /logspire_water_recovery_v15_vine_only\.gd/);
  assert.match(vineOnly, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v14_safe_vine_reentry\.gd"/);
  assert.match(safeVine, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v13_integrated_qa\.gd"/);
  assert.match(waterIntegrated, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v12_reliability_authority\.gd"/);
  assert.match(waterAuthority, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v10_surface_collision_guard\.gd"/);
  assert.match(round3Scene, /logspire_jump_rebalance_v3_titan_tree_accessibility\.gd/);
  assert.match(round3Scene, /logspire_ladder_system_v6_vine_only_cleanup\.gd/);
  assert.match(round3Scene, /logspire_phase3_director_v5_route_clearance\.gd/);
  assert.match(phase3V5, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v4_major_collision\.gd"/);
  assert.doesNotMatch(round3Scene, /graphics_phase2_world_art\.gd/);
  assert.doesNotMatch(round3Scene, /round_vfx_safe_loader\.gd/);
  assert.doesNotMatch(round3Scene, /logspire_water_recovery_v11_wild_moments\.gd/);
});
