import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const mode = readFileSync("godot/modes/logspire_leap/logspire_leap_v5_finish_ai_convergence.gd", "utf8");
const ai = readFileSync("godot/modes/logspire_leap/logspire_platform_ai_v5_phase_b.gd", "utf8");
const finish = readFileSync("godot/modes/logspire_leap/logspire_finish_authority.gd", "utf8");
const gameManager = readFileSync("godot/scripts/game_manager.gd", "utf8");

test("production Round 3 wires finish and AI convergence adapter", () => {
  assert.match(scene, /logspire_leap_v5_finish_ai_convergence\.gd/);
  assert.match(mode, /extends "res:\/\/modes\/logspire_leap\/logspire_leap_v4_phase_b\.gd"/);
});

test("direct editor finish is promoted into normal Round 3 recap flow", () => {
  assert.match(mode, /func _on_player_finished\(rank: int\) -> void:/);
  assert.match(mode, /if _direct_run:/);
  assert.match(mode, /_promote_direct_round3_finish_to_recap_flow\(\)/);
  assert.match(mode, /GameManager\.campaign_running = true/);
  assert.match(mode, /GameManager\.current_round_index = ROUND3_CAMPAIGN_INDEX/);
  assert.match(mode, /const ROUND3_CAMPAIGN_INDEX: int = 2/);
  assert.match(mode, /_direct_run = false/);
  assert.match(mode, /super\(rank\)/);
  assert.match(mode, /r3_direct_finish_promoted_to_campaign_slot/);
});

test("Crown Nest remains the authoritative Round 3 finish", () => {
  assert.match(finish, /const FINISH_PLATFORM_ID: StringName = &"CROWN_NEST"/);
  assert.match(finish, /RaceManager\.record_finish\(racer\)/);
  assert.match(finish, /r3_finale_finish_clear/);
});

test("four AI racers are selected as visible late-race contenders", () => {
  assert.match(mode, /FINALE_CONTENDER_AI_NUMBERS: Array\[int\] = \[2, 3, 5, 6\]/);
  assert.match(mode, /platform_ai\.call\("set_finale_contender", true\)/);
  assert.match(mode, /if racer == null or racer\.is_player:/);
  assert.match(mode, /r3_ai_finale_contender_selected/);
});

test("Finale contenders are forced onto Safe Route with stronger late landing assistance", () => {
  assert.match(ai, /func set_finale_contender\(enabled: bool\) -> void:/);
  assert.match(ai, /_finale_contender = enabled and _racer != null and not _racer\.is_player/);
  assert.match(ai, /_route_id = ROUTE_SAFE/);
  assert.match(ai, /_route = _copy_route\(_safe_route\)/);
  assert.match(ai, /CONTENDER_AIR_ASSIST_RANGE: float = 18\.5/);
  assert.match(ai, /CONTENDER_LANDING_RESPONSE: float = 13\.0/);
  assert.match(ai, /CONTENDER_MIN_JUMP_SCALE: float = 1\.16/);
});

test("late AI anti-stall recovery is bounded to one authored platform and never targets the player", () => {
  assert.match(ai, /CONTENDER_STALL_SECONDS: float = 6\.5/);
  assert.match(ai, /CONTENDER_MAX_REANCHORS: int = 5/);
  assert.match(ai, /if platform_id == &"CROWN_NEST":/);
  assert.match(ai, /if _racer == null or _driver == null or _racer\.is_player:/);
  assert.match(ai, /_racer\.reset_motion\(target\)/);
  assert.match(ai, /RaceManager\.sync_checkpoint_from_position\(_racer\)/);
  assert.match(ai, /bounded_one_platform=true player=false/);
});

test("campaign order remains Round 3 -> recap -> Round 4 push_out", () => {
  assert.match(gameManager, /&"logspire_leap",\s*\n\t&"push_out",/);
  assert.match(gameManager, /const ROUND_RECAP_SCENE := "res:\/\/scenes\/round_recap\.tscn"/);
  assert.match(gameManager, /func _transition_after_round\(\) -> void:/);
  assert.match(gameManager, /set_state\(GameState\.ROUND_RECAP\)/);
  assert.match(gameManager, /func advance_from_round_recap\(\) -> void:/);
});
