import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/fruit_collection/fruit_collection.tscn", "utf8");
const v19 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v19_species_interaction.gd", "utf8");
const v18 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v18_wild_moments.gd", "utf8");
const v17 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v17_fart_dizzy.gd", "utf8");
const v16 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v16_clear_balance.gd", "utf8");
const v15 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v15_active_ai_dispersion.gd", "utf8");
const v12 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v12_vertical_dispersion.gd", "utf8");
const v10 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v10_combat_v2_final.gd", "utf8");
const v8 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v8_canopy_combat.gd", "utf8");
const baseMode = readFileSync("godot/modes/fruit_collection/fruit_collection_mode.gd", "utf8");
const modifier = readFileSync("godot/modes/fruit_collection/round2_combat_modifier.gd", "utf8");
const abilitySystem = readFileSync("godot/systems/combat_ability_system.gd", "utf8");
const phase3Profiles = readFileSync("godot/systems/combat_v2_phase3_profile.gd", "utf8");
const agileProfiles = readFileSync("godot/systems/animal_combat_profile.gd", "utf8");
const roster = readFileSync("godot/characters/animal_catalog.gd", "utf8");
const gameManager = readFileSync("godot/scripts/game_manager.gd", "utf8");

function numericConstant(source, name) {
  const match = source.match(new RegExp(`const ${name}(?:[^=]*)=\\s*([0-9.]+)`));
  assert.ok(match, `missing ${name}`);
  return Number(match[1]);
}

test("Round 2 production scene activates V19 as a thin adapter over V18 and V17", () => {
  assert.match(scene, /fruit_frenzy_v19_species_interaction\.gd/);
  assert.match(v19, /extends "res:\/\/modes\/fruit_collection\/fruit_frenzy_v18_wild_moments\.gd"/);
  assert.match(v18, /extends "res:\/\/modes\/fruit_collection\/fruit_frenzy_v17_fart_dizzy\.gd"/);
  assert.match(v17, /extends "res:\/\/modes\/fruit_collection\/fruit_frenzy_v16_clear_balance\.gd"/);
  assert.match(v19, /GameManager\.get_current_round_id\(\) == &"fruit_collection"/);
});

test("all twelve playable species keep explicit Round 2 interaction identities", () => {
  for (const id of ["dog", "wolf", "boar", "rabbit", "deer", "monkey", "elephant", "bear", "crocodile", "cat", "fox", "raccoon"]) {
    assert.match(roster, new RegExp(`&"${id}"`));
    assert.match(v19, new RegExp(`&"${id}"`));
  }
  assert.match(v19, /dog=shoulder/);
  assert.match(v19, /wolf=medium_pounce/);
  assert.match(v19, /boar=charge/);
  assert.match(v19, /rabbit=hop_kick/);
  assert.match(v19, /deer=running_stomp/);
  assert.match(v19, /monkey=ground_slam/);
  assert.match(v19, /elephant=push/);
  assert.match(v19, /bear=wide_shove/);
  assert.match(v19, /crocodile=tail_sweep/);
  assert.match(v19, /cat=fast_pounce/);
  assert.match(v19, /fox=dash_bump/);
  assert.match(v19, /raccoon=steal/);
});

test("Deer Running Stomp requires an intentional jump and forward running momentum", () => {
  assert.equal(numericConstant(v19, "R2_DEER_MIN_RUN_RATIO"), 0.42);
  assert.equal(numericConstant(v19, "R2_DEER_STOMP_RADIUS"), 2.15);
  assert.match(v19, /was_grounded and not racer\.is_on_floor\(\) and racer\.velocity\.y > 0\.45/);
  assert.match(v19, /_r2_jump_armed_by_id\[id\] = true/);
  assert.match(v19, /if run_ratio < R2_DEER_MIN_RUN_RATIO:/);
  assert.match(v19, /travel\.dot\(offset\.normalized\(\)\) < -0\.05/);
  assert.match(v19, /get_aerial_attack\(&"deer"\)/);
  assert.match(v19, /"DEER RUNNING STOMP"/);
});

test("Monkey Ground Slam has a stronger center, weaker outer ring and bounded multi-target count", () => {
  assert.equal(numericConstant(v19, "R2_MONKEY_SLAM_CENTER_RADIUS"), 1.35);
  assert.equal(numericConstant(v19, "R2_MONKEY_SLAM_OUTER_SCALE"), 0.55);
  assert.equal(numericConstant(v19, "R2_MONKEY_SLAM_MAX_TARGETS"), 5);
  assert.match(v19, /var center: bool = distance <= R2_MONKEY_SLAM_CENTER_RADIUS/);
  assert.match(v19, /var force_scale: float = 1\.0 if center else R2_MONKEY_SLAM_OUTER_SCALE/);
  assert.match(v19, /if center and spill_budget > 0:/);
  assert.match(v19, /center_scale=1\.00 outer_scale=%.2f spill_budget=1/);
});

test("Power class preserves Elephant push and Boar charge while Bear gains a wide three-target shove", () => {
  assert.match(phase3Profiles, /ELEPHANT_TRUNK_PUSH/);
  assert.match(phase3Profiles, /"TRUNK PUSH"/);
  assert.match(phase3Profiles, /BOAR_CHARGE/);
  assert.match(phase3Profiles, /"BOAR CHARGE"[\s\S]*?4\.75[\s\S]*?9\.2[\s\S]*?1\.18[\s\S]*?0\.78[\s\S]*?4\.0/);
  assert.equal(numericConstant(v19, "R2_BEAR_WIDE_MAX_TARGETS"), 3);
  assert.equal(numericConstant(v19, "R2_BEAR_WIDE_KNOCKBACK_SCALE"), 0.88);
  assert.match(v19, /func _r2_bear_wide_shove/);
  assert.match(v19, /if hits >= R2_BEAR_WIDE_MAX_TARGETS:/);
});

test("Crocodile, Wolf, Cat, Fox, Rabbit and Dog retain their requested shared-profile attacks", () => {
  assert.match(agileProfiles, /CROCODILE_TAIL_ID/);
  assert.match(v19, /R2_CROCODILE_TAIL_ARC_DOT: float = -0\.34/);
  assert.match(v19, /arc_degrees=220/);
  assert.match(phase3Profiles, /WOLF_POUNCE/);
  assert.match(phase3Profiles, /DOG_SHOULDER/);
  assert.match(agileProfiles, /CAT_POUNCE_ID/);
  assert.match(agileProfiles, /FOX_DASH_ID/);
  assert.match(agileProfiles, /RABBIT_KICK_ID/);
  assert.match(v19, /R2_RABBIT_HOP_SCALE: float = 0\.28/);
  assert.match(v19, /player\.velocity\.y = maxf\(player\.velocity\.y, player\.jump_velocity \* R2_RABBIT_HOP_SCALE\)/);
});

test("Raccoon Fruit Swipe steals exactly one fruit with source cooldown and recent-target protection", () => {
  assert.equal(numericConstant(v19, "R2_RACCOON_STEAL_AMOUNT"), 1);
  assert.equal(numericConstant(v19, "R2_RACCOON_TARGET_PROTECTION_SECONDS"), 1.25);
  assert.match(v19, /_phase3_steal_cooldown_by_id\[source_id\] = RACCOON_STEAL_COOLDOWN/);
  assert.match(v19, /_r2_raccoon_target_protected_until\[target_id\] = now \+ R2_RACCOON_TARGET_PROTECTION_SECONDS/);
  assert.match(v19, /steal_amount: int = mini\(R2_RACCOON_STEAL_AMOUNT/);
  assert.match(v10, /const RACCOON_STEAL_COOLDOWN: float = 1\.85/);
});

test("player and AI execute the same species profiles while collection-first target selection stays authoritative", () => {
  assert.match(v19, /func _try_ai_attack/);
  assert.match(v19, /_phase3_round2_profile_attack\(attacker, true\)/);
  assert.match(v19, /_phase3_round2_profile_attack\(attacker, false\)/);
  assert.match(v19, /_r2_bear_wide_shove\(attacker\)/);
  assert.match(v19, /_r2_crocodile_tail_sweep\(attacker\)/);
  assert.match(v19, /_r2_apply_deer_stomp\(racer, target\)/);
  assert.match(v19, /_r2_apply_monkey_ground_slam\(racer\)/);
  assert.match(v12, /_try_ai_attack\(racer, victim, personality\)/);
  assert.match(v15, /combat_normal=%.1fm combat_hunter=%.1fm/);
  assert.match(abilitySystem, /WildDashCombatV2Phase3Profile\.get_basic_attack/);
  assert.match(modifier, /Fruit Frenzy remains authoritative for inventory changes/);
});

test("new species interactions stay short and do not add a second hard-stun authority", () => {
  assert.equal(numericConstant(v19, "R2_SIGNATURE_RECOVERY_MAX"), 0.80);
  assert.doesNotMatch(v19, /stun_remaining_by_id\[/);
  assert.doesNotMatch(v19, /FART_DIZZY_SECONDS\s*=/);
  assert.match(v19, /visual\.play_action\(&"Hit", clampf\(seconds, 0\.20, 0\.40\)\)/);
  assert.match(v17, /const FART_DIZZY_SECONDS: float = 1\.0/);
  assert.match(v17, /FART_DIZZY_IMMUNITY_SECONDS: float = 0\.35/);
});

test("Fruit pickup, loose-fruit recovery, Golden Fruit, Bank and Round 2 finish authorities remain intact", () => {
  assert.match(baseMode, /func _try_pickup_regular_fruit/);
  assert.match(baseMode, /func _try_pickup_spill_fruit/);
  assert.match(baseMode, /func _try_pickup_golden_fruit/);
  assert.match(baseMode, /func _bank_racer/);
  assert.match(baseMode, /func _spill_racer/);
  assert.match(v18, /func _try_pickup_golden_fruit/);
  assert.match(v18, /func _try_pickup_spill_fruit/);
  assert.match(v18, /func _spill_racer/);
  assert.match(v18, /func _bank_racer/);
  assert.match(v16, /const ROUND2_CLEAR_TARGET: int = 8/);
  assert.match(v16, /finish_mode\(success, player_score/);
});

test("Round 2 species pass is scoped away from the other four campaign rounds", () => {
  assert.doesNotMatch(v19, /&"grand_prix"/);
  assert.doesNotMatch(v19, /&"logspire_leap"/);
  assert.doesNotMatch(v19, /&"push_out"/);
  assert.doesNotMatch(v19, /&"neon_harbor_race"/);
  const r1 = gameManager.indexOf('&"grand_prix"');
  const r2 = gameManager.indexOf('&"fruit_collection"');
  const r3 = gameManager.indexOf('&"logspire_leap"');
  const r4 = gameManager.indexOf('&"push_out"');
  const r5 = gameManager.indexOf('&"neon_harbor_race"');
  assert.ok(r1 >= 0 && r2 > r1 && r3 > r2 && r4 > r3 && r5 > r4);
});

test("existing agile aerial, Combat V2 and fart/Wild Moments inheritance remains present underneath V19", () => {
  assert.match(v8, /func _update_round2_aerial_combat/);
  assert.match(v10, /func _phase3_round2_profile_attack/);
  assert.match(v10, /func _phase3_try_quick_steal/);
  assert.match(v17, /ROUND2 FART DIZZY READY/);
  assert.match(v18, /WILD MOMENTS R2 READY/);
});
