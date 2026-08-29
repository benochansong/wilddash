import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const project = readFileSync("godot/project.godot", "utf8");
const baseItems = readFileSync("godot/systems/item_system.gd", "utf8");
const rc9Items = readFileSync("godot/systems/item_system_rc9_party_turbo.gd", "utf8");
const round1Items = readFileSync("godot/systems/item_system_rc9_round1_impact.gd", "utf8");
const round5Pressure = readFileSync("godot/systems/item_system_rc9_round5_leader_pressure.gd", "utf8");
const raceCore = readFileSync("godot/systems/race_combat_core_v3.gd", "utf8");
const raceCorePower = readFileSync("godot/systems/race_combat_core_v3_power.gd", "utf8");
const profiles = readFileSync("godot/systems/race_impact_profile.gd", "utf8");
const expandedCatalog = readFileSync("godot/items/expanded_item_catalog.gd", "utf8");
const expandedController = readFileSync("godot/items/item_combat_expansion_controller.gd", "utf8");
const springTrap = readFileSync("godot/items/spring_trap.gd", "utf8");
const gameManager = readFileSync("godot/scripts/game_manager.gd", "utf8");

function numericConstant(source, name) {
  const match = source.match(new RegExp(`const ${name}(?:[^=]*)=\\s*([0-9.]+)`));
  assert.ok(match, `missing ${name}`);
  return Number(match[1]);
}

test("Round 1 impact pass remains an adapter over the existing ItemSystem architecture", () => {
  assert.match(project, /ItemSystem="\*res:\/\/systems\/item_system_rc9_round5_leader_pressure\.gd"/);
  assert.match(round5Pressure, /extends "res:\/\/systems\/item_system_rc9_round1_impact\.gd"/);
  assert.match(round5Pressure, /return super\.roll_item_for_rank\(rank, total, history\)/);
  assert.match(round1Items, /extends "res:\/\/systems\/item_system_rc9_party_turbo\.gd"/);
  assert.match(rc9Items, /extends "res:\/\/systems\/item_system\.gd"/);
  assert.match(baseItems, /const ITEM_IDS: Array\[StringName\] = \[/);
  assert.match(round1Items, /return GameManager\.round_active and RaceManager\.active and GameManager\.get_current_round_id\(\) == &"grand_prix"/);
  assert.match(round1Items, /return super\.apply_attack\(target, source, effect_id, duration, slow_multiplier, knockback_strength\)/);
});

test("Rocket Nut gains a 40 percent Round 1 knockback pass without changing its shared baseline", () => {
  const multiplier = numericConstant(raceCore, "ROUND1_ROCKET_KNOCKBACK_MULTIPLIER");
  assert.equal(multiplier, 1.40);
  assert.match(profiles, /static func rocket_nut\(\)[\s\S]*?p\.knockback = 4\.95/);
  assert.match(raceCore, /tuned\.knockback \*= ROUND1_ROCKET_KNOCKBACK_MULTIPLIER/);
  assert.match(raceCore, /tuned\.stagger_duration = minf\(0\.62, tuned\.stagger_duration \+ 0\.04\)/);
  assert.match(raceCore, /tuned\.speed_loss_ratio = minf\(0\.34, tuned\.speed_loss_ratio \+ 0\.04\)/);
  assert.ok(4.95 * multiplier > 4.95);
  assert.ok(4.95 * multiplier <= numericConstant(raceCore, "ROUND1_MAX_ITEM_KNOCKBACK"));
});

test("Shockwave uses center-middle-outer falloff and has no hidden second impulse", () => {
  assert.equal(numericConstant(round1Items, "ROUND1_SHOCKWAVE_CENTER_MULTIPLIER"), 1.38);
  assert.equal(numericConstant(round1Items, "ROUND1_SHOCKWAVE_MIDDLE_SCALE"), 0.70);
  assert.equal(numericConstant(round1Items, "ROUND1_SHOCKWAVE_OUTER_SCALE"), 0.40);
  assert.match(round1Items, /_round1_shockwave_falloff/);
  assert.match(round1Items, /lerpf\(1\.0, ROUND1_SHOCKWAVE_MIDDLE_SCALE, middle_t\)/);
  assert.match(round1Items, /lerpf\(ROUND1_SHOCKWAVE_MIDDLE_SCALE, ROUND1_SHOCKWAVE_OUTER_SCALE, outer_t\)/);
  assert.match(round1Items, /falloff=100\/70\/40/);
  assert.match(raceCorePower, /physics_owner=item_system distance_falloff=true extra_push=0/);
  assert.doesNotMatch(raceCorePower, /apply_knockback/);
});

test("Acorn Bomb rewards center hits more than outer hits while recovery stays bounded", () => {
  assert.equal(numericConstant(raceCore, "ROUND1_BOMB_INNER_IMPACT_MULTIPLIER"), 1.45);
  assert.equal(numericConstant(raceCore, "ROUND1_BOMB_OUTER_IMPACT_MULTIPLIER"), 1.20);
  assert.equal(numericConstant(raceCore, "ROUND1_BOMB_KNOCKBACK_MULTIPLIER"), 1.20);
  assert.match(raceCore, /var inner: bool = tuned\.impact_label == &"HEAVY"/);
  assert.match(raceCore, /0\.82 if inner else 0\.68/);
  assert.match(profiles, /static func pack_buster_inner\(\)[\s\S]*?p\.knockback = 6\.95/);
  assert.match(profiles, /static func pack_buster_outer\(\)[\s\S]*?p\.knockback = 5\.35/);
});

test("Round 1 hit-chain protection is bounded rather than infinite stun or full immunity", () => {
  assert.equal(numericConstant(round1Items, "ROUND1_CHAIN_WINDOW_SECONDS"), 0.82);
  assert.equal(numericConstant(round1Items, "ROUND1_CHAIN_SECOND_SCALE"), 0.55);
  assert.equal(numericConstant(round1Items, "ROUND1_CHAIN_THIRD_SCALE"), 0.32);
  assert.match(round1Items, /var bypass_immunity: bool = chain_scale < 0\.999 and previous_immunity > now/);
  assert.match(round1Items, /tuned_slow = 1\.0 - \(1\.0 - tuned_slow\) \* chain_scale/);
  assert.match(round1Items, /tuned_knockback \*= chain_scale/);
  assert.match(raceCore, /tuned\.stagger_duration \*= maxf\(0\.35, chain_scale\)/);
  assert.match(raceCore, /tuned\.slow_duration \*= maxf\(0\.45, chain_scale\)/);
  assert.match(round1Items, /recovery_complete=1/);
});

test("Trap disruption is stronger on the first hit but bounded on chained hits", () => {
  assert.match(raceCore, /ROUND1_BANANA_KNOCKBACK_MULTIPLIER: float = 1\.25/);
  assert.match(raceCore, /tuned\.slow_duration = minf\(tuned\.slow_duration, 0\.72\)/);
  assert.match(raceCore, /tuned\.slow_duration = minf\(tuned\.slow_duration, 1\.10\)/);
  assert.match(springTrap, /ItemSystem\.call\("get_round1_chain_scale", racer\)/);
  assert.match(springTrap, /ItemSystem\.apply_attack\(racer, owner_racer, &"spring_trap", 0\.20, 0\.96, 0\.0\)/);
  assert.match(springTrap, /launch_velocity \*= ROUND1_LAUNCH_MULTIPLIER \* chain_scale/);
  assert.match(springTrap, /speed_retention = 1\.0 - \(1\.0 - first_hit_retention\) \* chain_scale/);
});

test("Expanded attack and trap catalog plus AI utility remain wired", () => {
  for (const id of ["SNOWBALL", "BEE_SWARM", "MUD_SPLASH", "SPRING_TRAP"]) {
    assert.match(expandedCatalog, new RegExp(`const ${id}: StringName`));
  }
  assert.match(expandedCatalog, /SNOWBALL: \{[^\n]*role": &"attack"/);
  assert.match(expandedCatalog, /BEE_SWARM: \{[^\n]*role": &"attack"/);
  assert.match(expandedCatalog, /MUD_SPLASH: \{[^\n]*role": &"trap"/);
  assert.match(expandedCatalog, /SPRING_TRAP: \{[^\n]*role": &"trap"/);
  assert.match(expandedController, /func _update_ai_expanded_items\(\)/);
  assert.match(expandedController, /if _ai_utility\(racer, item_id\) >= threshold:/);
  assert.match(expandedController, /use_expanded_item\(racer, item_id\)/);
  assert.match(round1Items, /&"snowball": 1\.30/);
  assert.match(round1Items, /&"wind_boost": 1\.20/);
});

test("10, 15 and 18 racer profiles and five-round campaign order remain unchanged", () => {
  assert.match(gameManager, /const CASUAL_AI_COUNT := 9/);
  assert.match(gameManager, /const NORMAL_AI_COUNT := 14/);
  assert.match(gameManager, /const HARD_AI_COUNT := 17/);
  const r1 = gameManager.indexOf('&"grand_prix"');
  const r2 = gameManager.indexOf('&"fruit_collection"');
  const r3 = gameManager.indexOf('&"logspire_leap"');
  const r4 = gameManager.indexOf('&"push_out"');
  const r5 = gameManager.indexOf('&"neon_harbor_race"');
  assert.ok(r1 >= 0 && r2 > r1 && r3 > r2 && r4 > r3 && r5 > r4);
});

test("Impact telemetry exposes requested QA fields without per-frame spam", () => {
  for (const field of [
    "item_hit=1",
    "direct_hit=%d",
    "area_hit=%d",
    "knockback_applied=%.2f",
    "stagger_applied=%.2f",
    "chain_protection=%.2f",
    "multi_hit=%d",
    "recovery_complete=1",
  ]) {
    assert.ok(round1Items.includes(field) || raceCore.includes(field), `missing telemetry field ${field}`);
  }
  assert.match(round1Items, /_record_round1_chain_hit/);
  assert.match(round1Items, /_update_round1_chain_recovery/);
});
