import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/fruit_collection/fruit_collection.tscn", "utf8");
const v20 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v20_economy_combat_ai.gd", "utf8");
const v19 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v19_species_interaction.gd", "utf8");
const v18 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v18_wild_moments.gd", "utf8");
const v17 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v17_fart_dizzy.gd", "utf8");
const v15 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v15_active_ai_dispersion.gd", "utf8");
const v12 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v12_vertical_dispersion.gd", "utf8");
const v2 = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v2_polish.gd", "utf8");
const baseMode = readFileSync("godot/modes/fruit_collection/fruit_collection_mode.gd", "utf8");
const gameManager = readFileSync("godot/scripts/game_manager.gd", "utf8");

function numericConstant(source, name) {
  const match = source.match(new RegExp(`const ${name}(?:[^=]*)=\\s*([0-9.]+)`));
  assert.ok(match, `missing ${name}`);
  return Number(match[1]);
}

function functionSlice(source, name, nextMarker = "\n# -----------------------------------------------------------------------------") {
  const start = source.indexOf(`func ${name}`);
  assert.ok(start >= 0, `missing function ${name}`);
  const end = source.indexOf(nextMarker, start);
  return source.slice(start, end >= 0 ? end : source.length);
}

test("Round 2 V20 is production-only and remains a thin adapter over V19 species combat", () => {
  assert.match(scene, /fruit_frenzy_v20_economy_combat_ai\.gd/);
  assert.match(v20, /extends "res:\/\/modes\/fruit_collection\/fruit_frenzy_v19_species_interaction\.gd"/);
  assert.match(v19, /GameManager\.get_current_round_id\(\) == &"fruit_collection"/);
  assert.doesNotMatch(v20, /&"grand_prix"|&"logspire_leap"|&"push_out"|&"neon_harbor_race"/);
});

test("fruit spill keeps the existing carry and loose-fruit authority while adding a bounded loss cap", () => {
  assert.equal(numericConstant(baseMode, "MAX_CARRY"), 5);
  assert.equal(numericConstant(v20, "R2_SPILL_MAX_PER_HIT"), 2);
  assert.equal(numericConstant(v20, "R2_SPILL_RATIO_TARGET"), 0.30);
  assert.match(v20, /var loss_cap: int = mini\(R2_SPILL_MAX_PER_HIT, mini\(maxi\(0, carry - 1\), ratio_cap\)\)/);
  assert.match(v20, /super\(racer, bounded, reason\)/);
  assert.match(baseMode, /carried_by_id\[racer\.get_instance_id\(\)\] = carry - actual/);
  assert.match(baseMode, /_spawn_spilled_fruit\(position, _spill_type_for_index\(i\), 1\)/);
});

test("one normal hit cannot wipe all carried fruit and a full bag loses at most two", () => {
  const cap = (carry) => Math.min(2, Math.max(0, carry - 1), Math.max(1, Math.round(carry * 0.30)));
  assert.equal(cap(1), 0);
  assert.equal(cap(2), 1);
  assert.equal(cap(3), 1);
  assert.equal(cap(4), 1);
  assert.equal(cap(5), 2);
  for (let carry = 1; carry <= 5; carry += 1) {
    assert.ok(cap(carry) < carry);
  }
});

test("fruit spill chain protection is full first hit, reduced second hit and zero from third hit", () => {
  assert.equal(numericConstant(v20, "R2_SPILL_SECOND_SCALE"), 0.50);
  assert.equal(numericConstant(v20, "R2_SPILL_THIRD_SCALE"), 0.0);
  assert.match(v20, /if chain_index == 2:[\s\S]*?R2_SPILL_SECOND_SCALE/);
  assert.match(v20, /elif chain_index >= 3:[\s\S]*?R2_SPILL_THIRD_SCALE/);
  assert.match(v20, /fruit_spill_protected=1/);
});

test("hit-chain protection keeps interaction but sharply reduces repeated displacement", () => {
  assert.equal(numericConstant(v20, "R2_HIT_PROTECTION_SECONDS"), 0.84);
  assert.equal(numericConstant(v20, "R2_HIT_SECOND_SCALE"), 0.56);
  assert.equal(numericConstant(v20, "R2_HIT_THIRD_SCALE"), 0.30);
  assert.equal(numericConstant(v20, "R2_HIT_FURTHER_SCALE"), 0.12);
  assert.match(v20, /if count == 2:[\s\S]*?R2_HIT_SECOND_SCALE/);
  assert.match(v20, /elif count == 3:[\s\S]*?R2_HIT_THIRD_SCALE/);
  assert.match(v20, /elif count >= 4:[\s\S]*?R2_HIT_FURTHER_SCALE/);
  assert.match(v20, /target\.apply_knockback\(offset\.normalized\(\), result\.knockback \* hit_scale\)/);
});

test("bank remains risky but repeat knockback is bounded instead of creating a safe zone", () => {
  assert.equal(numericConstant(v20, "R2_BANK_REPEAT_KNOCKBACK_SCALE"), 0.68);
  assert.equal(numericConstant(v20, "R2_BANK_PROTECTION_RADIUS_BONUS"), 1.35);
  assert.match(v20, /if bank_attack and count >= 2:/);
  assert.match(v20, /scale \*= R2_BANK_REPEAT_KNOCKBACK_SCALE/);
  assert.doesNotMatch(v20, /return false[^\n]*bank_attack|invulnerable|safe_zone/i);
  assert.match(v20, /bank_attack=1/);
  assert.match(baseMode, /func _try_bank_racer/);
  assert.match(baseMode, /_bank_racer\(racer\)/);
});

test("normal combat recovery stays under one second while inherited power stun remains bounded", () => {
  assert.match(v20, /R2_TIER_LIGHT:[\s\S]*?return 0\.34/);
  assert.match(v20, /R2_TIER_HEAVY:[\s\S]*?return 0\.68/);
  assert.match(v20, /R2_TIER_CONTROL:[\s\S]*?return 0\.48/);
  assert.match(v20, /return 0\.50/);
  assert.match(v20, /signature in \[&"running_stomp", &"ground_slam"\][\s\S]*?return 0\.70/);
  assert.match(v20, /clampf\(recovery, 0\.25, 0\.80\)/);
  assert.equal(numericConstant(v2, "POWER_STUN_MAX_SECONDS"), 0.55);
  assert.equal(numericConstant(v2, "POWER_STUN_IMMUNITY_SECONDS"), 1.10);
  assert.equal(numericConstant(v17, "FART_DIZZY_SECONDS"), 1.0);
});

test("Golden Fruit keeps its existing objective rules and ordinary spill creates only normal loose fruit", () => {
  assert.match(baseMode, /func _try_pickup_golden_fruit/);
  assert.match(baseMode, /_add_carry\(racer, 3\)/);
  assert.match(baseMode, /GOLDEN FRUIT CLAIMED · \+3/);
  assert.match(v18, /func _try_pickup_golden_fruit/);
  const spillType = functionSlice(baseMode, "_spill_type_for_index");
  assert.match(spillType, /FRUIT_APPLE/);
  assert.match(spillType, /FRUIT_BANANA/);
  assert.match(spillType, /FRUIT_BERRY/);
  assert.doesNotMatch(spillType, /FRUIT_GOLDEN/);
});

test("Raccoon steal is bounded by source cooldown, target protection, hit-chain protection and last-fruit protection", () => {
  assert.equal(numericConstant(v19, "R2_RACCOON_STEAL_AMOUNT"), 1);
  assert.equal(numericConstant(v19, "R2_RACCOON_TARGET_PROTECTION_SECONDS"), 1.25);
  assert.match(v20, /_r2_current_hit_count\(target\) > 1/);
  assert.match(v20, /_get_carry\(target\) <= 1/);
  assert.match(v20, /_phase3_steal_cooldown_by_id\[source_id\] = RACCOON_STEAL_COOLDOWN/);
  assert.match(v20, /_r2_raccoon_target_protected_until\[target_id\] = now \+ R2_RACCOON_TARGET_PROTECTION_SECONDS/);
  assert.match(v20, /fruit_steal=%d/);
});

test("AI combat utility weighs fruit economy, bank race, score, time, miss risk and collection opportunity cost", () => {
  for (const token of [
    "_get_carry(target)",
    "_get_carry(source)",
    "_get_banked(target)",
    "_get_banked(source)",
    "time_remaining",
    "_golden_active",
    "_cart_root",
    "_nearest_collectible_position(source)",
    "alignment",
    "_r2_ai_species_style_modifier",
  ]) {
    assert.ok(v20.includes(token), `missing AI utility factor ${token}`);
  }
  assert.equal(numericConstant(v20, "R2_AI_MIN_UTILITY"), 0.50);
  assert.equal(numericConstant(v20, "R2_AI_HUNTER_MIN_UTILITY"), 0.43);
  assert.match(v20, /utility < threshold/);
});

test("AI understands species style without AI-only attack power or fruit-drop multipliers", () => {
  for (const id of ["deer", "monkey", "elephant", "bear", "boar", "crocodile", "wolf", "cat", "fox", "rabbit", "raccoon"]) {
    assert.match(v20, new RegExp(`&"${id}"`));
  }
  assert.match(v20, /_r2_clear_charge_lane/);
  assert.match(v20, /_r2_enemy_count_near/);
  assert.match(v20, /_r2_ai_species_style_modifier/);
  assert.doesNotMatch(v20, /AI_ATTACK_POWER|AI_FRUIT_DROP_MULTIPLIER|AI_KNOCKBACK_MULTIPLIER/);
  assert.match(v20, /super\(attacker, target, personality\)/);
});

test("collection-first AI architecture and 10, 15, 18 racer profiles remain supported", () => {
  assert.equal(numericConstant(v15, "V15_NORMAL_COMBAT_RANGE"), 2.8);
  assert.equal(numericConstant(v15, "V15_HUNTER_COMBAT_RANGE"), 5.2);
  assert.match(v12, /V12_INTENT_BANK/);
  assert.match(v12, /V12_INTENT_GOLDEN/);
  assert.match(v12, /V12_INTENT_COMBAT/);
  assert.match(v12, /V12_INTENT_COLLECT/);
  assert.match(gameManager, /const CASUAL_AI_COUNT := 9/);
  assert.match(gameManager, /const NORMAL_AI_COUNT := 14/);
  assert.match(gameManager, /const HARD_AI_COUNT := 17/);
});

test("Round 2 telemetry exposes the requested combat and economy events without frame-level hit logging", () => {
  for (const field of [
    "round2_attack=1",
    "species_attack=%s",
    "attack_hit=1",
    "stomp_hit=1",
    "push_hit=1",
    "pounce_hit=1",
    "tail_sweep_hit=1",
    "fruit_spill=",
    "fruit_steal=",
    "fruit_spill_protected=1",
    "hit_chain_protection=1",
    "recovery_complete=1",
    "bank_attack=1",
    "AI_attack_decision=execute",
  ]) {
    assert.ok(v20.includes(field), `missing telemetry ${field}`);
  }
  assert.match(v20, /R2_AI_DECISION_LOG_COOLDOWN: float = 1\.10/);
});

test("Round 2 finish, recap and campaign transition to Round 3 remain unchanged", () => {
  assert.match(baseMode, /time_remaining <= 0\.0/);
  assert.match(baseMode, /_finish_time_score_round\(\)/);
  assert.match(gameManager, /const ROUND_RECAP_SCENE := "res:\/\/scenes\/round_recap\.tscn"/);
  const r1 = gameManager.indexOf('&"grand_prix"');
  const r2 = gameManager.indexOf('&"fruit_collection"');
  const r3 = gameManager.indexOf('&"logspire_leap"');
  const r4 = gameManager.indexOf('&"push_out"');
  const r5 = gameManager.indexOf('&"neon_harbor_race"');
  assert.ok(r1 >= 0 && r2 > r1 && r3 > r2 && r4 > r3 && r5 > r4);
});
