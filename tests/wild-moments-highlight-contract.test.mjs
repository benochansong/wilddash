import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const resultManager = readFileSync("godot/scripts/result_manager.gd", "utf8");
const recap = readFileSync("godot/scenes/round_recap.gd", "utf8");
const grandScene = readFileSync("godot/modes/grand_prix/grand_prix.tscn", "utf8");
const fruitScene = readFileSync("godot/modes/fruit_collection/fruit_collection.tscn", "utf8");
const logspireScene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const rumbleScene = readFileSync("godot/modes/push_out/push_out.tscn", "utf8");
const r1 = readFileSync("godot/modes/grand_prix/grand_prix_v7_wild_moments.gd", "utf8");
const r2Economy = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v20_economy_combat_ai.gd", "utf8");
const r2Species = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v19_species_interaction.gd", "utf8");
const r2 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v18_wild_moments.gd", "utf8");
const r3 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v11_wild_moments.gd", "utf8");
const r3Integrated = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v13_integrated_qa.gd", "utf8");
const r3Authority = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v12_reliability_authority.gd", "utf8");
const r4 = readFileSync("godot/modes/push_out/wild_rumble_round4_wild_moments.gd", "utf8");

test("shared Wild Moments schema has four importance tiers and normalized event fields", () => {
  assert.match(resultManager, /HIGHLIGHT_NORMAL: int = 10/);
  assert.match(resultManager, /HIGHLIGHT_COOL: int = 30/);
  assert.match(resultManager, /HIGHLIGHT_EPIC: int = 60/);
  assert.match(resultManager, /HIGHLIGHT_LEGENDARY: int = 100/);
  for (const field of ["type", "racer", "target", "timestamp", "importance", "zone", "description", "metadata"]) {
    assert.match(resultManager, new RegExp(`copy\\["${field}"\\]`));
  }
  assert.match(resultManager, /WILD HIGHLIGHT EVENT/);
  assert.match(resultManager, /WILD HIGHLIGHT SELECTED/);
});

test("Replay Lite keeps only recent transforms at 10Hz for player plus four nearby racers", () => {
  assert.match(resultManager, /REPLAY_SAMPLE_INTERVAL: float = 0\.10/);
  assert.match(resultManager, /REPLAY_SECONDS: float = 4\.0/);
  assert.match(resultManager, /REPLAY_MAX_SAMPLES: int = 40/);
  assert.match(resultManager, /REPLAY_MAX_RACERS: int = 5/);
  assert.match(resultManager, /"position": racer\.global_position/);
  assert.match(resultManager, /"rotation": racer\.rotation/);
  assert.match(resultManager, /"action": _replay_action_state/);
  assert.match(resultManager, /if int\(copy\["importance"\]\) >= HIGHLIGHT_EPIC/);
  assert.doesNotMatch(resultManager, /get_viewport\(\)\.get_texture|Image\.save|capture.*frame/i);
});

test("production highlights remain wired while Round 3 prioritizes the V13 guard over reliability authority", () => {
  assert.match(grandScene, /grand_prix_v7_wild_moments\.gd/);
  assert.match(fruitScene, /fruit_frenzy_v20_economy_combat_ai\.gd/);
  assert.match(r2Economy, /extends "res:\/\/modes\/fruit_collection\/fruit_frenzy_v19_species_interaction\.gd"/);
  assert.match(r2Species, /extends "res:\/\/modes\/fruit_collection\/fruit_frenzy_v18_wild_moments\.gd"/);
  assert.match(rumbleScene, /wild_rumble_round4_wild_moments\.gd/);
  assert.match(logspireScene, /logspire_water_recovery_v13_integrated_qa\.gd/);
  assert.match(r3Integrated, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v12_reliability_authority\.gd"/);
  assert.doesNotMatch(logspireScene, /logspire_water_recovery_v11_wild_moments\.gd/);
  assert.match(logspireScene, /P0 CAMPAIGN-SAFE ROUND 3/);
  assert.match(r1, /extends "res:\/\/modes\/grand_prix\/grand_prix_v6_item_fairness\.gd"/);
  assert.match(r2, /extends "res:\/\/modes\/fruit_collection\/fruit_frenzy_v17_fart_dizzy\.gd"/);
  assert.match(r3, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v10_surface_collision_guard\.gd"/);
  assert.match(r3Authority, /extends "res:\/\/modes\/logspire_leap\/logspire_water_recovery_v10_surface_collision_guard\.gd"/);
  assert.match(r4, /extends "res:\/\/modes\/push_out\/wild_rumble_round4_result_balance\.gd"/);
});

test("Round 1 records meaningful overtake stories", () => {
  assert.match(r1, /overtake_combo/);
  assert.match(r1, /window_gain >= 3/);
  assert.match(r1, /EPIC OVERTAKE/);
  assert.match(r1, /lead_retake/);
  assert.match(r1, /BACK IN FRONT!/);
});

test("Round 2 records Golden Fruit, spill, steal and late bank moments", () => {
  assert.match(r2, /golden_fruit/);
  assert.match(r2, /GOLDEN FRUIT!/);
  assert.match(r2, /big_spill/);
  assert.match(r2, /FRUIT STEAL!/);
  assert.match(r2, /last_second_bank/);
  assert.match(r2, /time_remaining <= 7\.0/);
});

test("Round 3 highlight adapter source remains ready without replacing recovery physics", () => {
  assert.match(r3, /func _finish_assisted_recovery/);
  assert.match(r3, /func _finish_water_recovery/);
  assert.match(r3, /&"water_recovery"/);
  assert.match(r3, /BACK IN %.1f SEC/);
  assert.match(r3Authority, /LOGSPIRE RECOVERY EXIT CLEAR/);
});

test("Round 4 records ring-out, final-three and Titan Champion moments", () => {
  assert.match(r4, /&"ring_out"/);
  assert.match(r4, /DOUBLE RING OUT!/);
  assert.match(r4, /&"final_three"/);
  assert.match(r4, /&"titan_champion"/);
  assert.match(r4, /TITAN CHAMPION!/);
});

test("recap selects at most two highlights and plays them sequentially with safe fallback", () => {
  assert.match(recap, /get_highlights_for_entry\(_entry, 2\)/);
  assert.match(recap, /_update_wild_moment_slot/);
  assert.match(recap, /_show_wild_moment\(slot\)/);
  assert.match(recap, /SOLID RUN!/);
  assert.match(recap, /WILD RECAP PLAY/);
  assert.match(recap, /ROUND_RESULT_END: float = 3\.5/);
  assert.match(recap, /WILD_MOMENTS_END: float = 7\.0/);
  assert.match(recap, /RECAP_TOTAL_SECONDS: float = 9\.0/);
});
