import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const gameManager = readFileSync("godot/scripts/game_manager.gd", "utf8");
const modeBase = readFileSync("godot/modes/mode_base.gd", "utf8");
const fruit = readFileSync("godot/modes/fruit_collection/fruit_collection_mode.gd", "utf8");
const logspireScene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const waterIntegrated = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v13_integrated_qa.gd", "utf8");
const waterAuthority = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v12_reliability_authority.gd", "utf8");

test("Round 2 completion delegates to GameManager and campaign index advances into Logspire", () => {
  assert.match(modeBase, /GameManager\.complete_round\(mode_id, success, score, details\)/);
  assert.match(fruit, /if time_remaining <= 0\.0:\s*\n\s*_finish_time_score_round\(\)/);
  assert.match(fruit, /finish_mode\(success, player_score,/);
  assert.match(gameManager, /&"fruit_collection",\s*\n\s*&"logspire_leap",/);
  assert.match(gameManager, /"res:\/\/modes\/fruit_collection\/fruit_collection\.tscn",\s*\n\s*"res:\/\/modes\/logspire_leap\/logspire_leap\.tscn",/);
  assert.match(gameManager, /current_round_index \+= 1/);
  assert.match(gameManager, /_load_current_round\(\)/);
});

test("Campaign Round 3 keeps Phase B, V4 director and V13 guard over V12/V10 reliability", () => {
  assert.match(logspireScene, /logspire_leap_v4_phase_b\.gd/);
  assert.match(logspireScene, /logspire_phase3_director_v4_major_collision\.gd/);
  assert.doesNotMatch(logspireScene, /logspire_phase3_director_v5_fun_pass\.gd/);
  assert.match(logspireScene, /logspire_water_recovery_v13_integrated_qa\.gd/);
  assert.match(waterIntegrated, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v12_reliability_authority\.gd"/);
  assert.match(waterAuthority, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v10_surface_collision_guard\.gd"/);
});
