import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const mode = readFileSync("godot/modes/logspire_leap/logspire_leap_v4_phase_b.gd", "utf8");
const ai = readFileSync("godot/modes/logspire_leap/logspire_platform_ai_v5_phase_b.gd", "utf8");
const playerAssist = readFileSync("godot/modes/logspire_leap/logspire_jump_rebalance_v2_phase_b.gd", "utf8");
const titanAssist = readFileSync("godot/modes/logspire_leap/logspire_jump_rebalance_v3_titan_tree_accessibility.gd", "utf8");
const combat = readFileSync("godot/modes/logspire_leap/logspire_combat_safety_v3_phase_b.gd", "utf8");

test("Phase B scene wires crowd AI, inherited player ledge catch and Titan accessibility", () => {
  assert.match(scene, /logspire_leap_v4_phase_b\.gd/);
  assert.match(scene, /logspire_jump_rebalance_v3_titan_tree_accessibility\.gd/);
  assert.match(titanAssist, /extends "res:\/\/modes\/logspire_leap\/logspire_jump_rebalance_v2_phase_b\.gd"/);
  assert.match(scene, /logspire_combat_safety_v3_phase_b\.gd/);
  assert.match(mode, /logspire_platform_ai_v5_phase_b\.gd/);
});

test("AI landing targets spread across five safe lanes without edge cheating", () => {
  assert.match(mode, /PHASE_B_LANE_COUNT: int = 5/);
  assert.match(mode, /PHASE_B_LANE_SPACING: float = 0\.70/);
  assert.match(mode, /driver\.preferred_lane/);
  assert.match(ai, /PHASE_B_FIVE_LANES: int = 5/);
  assert.match(ai, /PHASE_B_MAX_LANE_OFFSET: float = 2\.20/);
  assert.match(ai, /_phase_b_landing_offset/);
  assert.match(ai, /_same_target_failures >= 2/);
});

test("Safe Route AI receives mild airborne steering and stronger repeated-failure centering", () => {
  assert.match(ai, /PHASE_B_SAFE_AIR_RESPONSE: float = 4\.6/);
  assert.match(ai, /PHASE_B_SAFE_LANDING_RESPONSE: float = 8\.8/);
  assert.match(ai, /PHASE_B_REPEAT_AIR_RESPONSE: float = 6\.2/);
  assert.match(ai, /PHASE_B_REPEAT_LANDING_RESPONSE: float = 11\.0/);
  assert.match(ai, /PHASE_B_LANDING_WINDOW_METERS: float = 2\.0/);
  assert.match(ai, /current_velocity\.lerp\(desired_velocity, blend\)/);
  assert.match(ai, /teleport=false/);
});

test("Player near-misses get bounded ledge catch while water recovery remains authoritative", () => {
  assert.match(playerAssist, /LEDGE_CATCH_WINDOW_SECONDS: float = 0\.42/);
  assert.match(playerAssist, /LEDGE_CATCH_EXTRA_RANGE: float = 0\.85/);
  assert.match(playerAssist, /LEDGE_CATCH_MAX_BELOW_TOP: float = 1\.45/);
  assert.match(playerAssist, /_is_player_water_recovering/);
  assert.match(playerAssist, /_authority_allows_jump_assist/);
  assert.match(playerAssist, /move_and_collide\(motion\)/);
});

test("crowded landings suppress only the dangerous first knockback window", () => {
  assert.match(combat, /PHASE_B_LANDING_PROTECTION_SECONDS: float = 0\.65/);
  assert.match(combat, /PHASE_B_LANDING_KNOCKBACK_CAP: float = 0\.85/);
  assert.match(combat, /PHASE_B_FIRST_CONTACT_SECONDS: float = 0\.18/);
  assert.match(combat, /body_check_preserved=true/);
});

test("AI fall and completion telemetry support 10, 15 and 18 racer validation", () => {
  assert.match(ai, /LOGSPIRE AI FALL REPORT/);
  assert.match(mode, /QA_RACER_COUNTS: Array\[int\] = \[10, 15, 18\]/);
  assert.match(mode, /LOGSPIRE AI COMPLETION REPORT/);
  assert.match(mode, /LOGSPIRE R3 QA PROFILE/);
  assert.match(mode, /expected=10\|15\|18/);
  assert.match(mode, /zone1_success_target=97-100%%/);
  assert.match(mode, /zone2_success_target=95%%/);
  assert.match(mode, /manual_success_rate_required=true/);
});
