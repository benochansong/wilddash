import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const grandPrixScene = readFileSync("godot/modes/grand_prix/grand_prix.tscn", "utf8");
const fairItems = readFileSync("godot/modes/grand_prix/grand_prix_v6_item_fairness.gd", "utf8");
const fruitScene = readFileSync("godot/modes/fruit_collection/fruit_collection.tscn", "utf8");
const fartDizzy = readFileSync("godot/modes/fruit_collection/fruit_frenzy_v17_fart_dizzy.gd", "utf8");

test("Round 1 uses the fair item relay layer", () => {
  assert.match(grandPrixScene, /grand_prix_v6_item_fairness\.gd/);
  assert.match(fairItems, /FAIR_RELAY_WINDOW_MSEC: int = 2600/);
  assert.match(fairItems, /FAIR_STATION_LOCK_MSEC: int = 6000/);
  assert.match(fairItems, /if rank <= 1:/);
  assert.match(fairItems, /racer\.get_held_item\(\) != &""/);
  assert.match(fairItems, /ItemSystem\.grant_weighted_item\(racer\)/);
  assert.match(fairItems, /ROUND1 FAIR ITEM RELAY/);
});

test("Round 1 item boxes respawn faster for 5, 15 and 18 racer fields", () => {
  assert.match(fairItems, /FAIR_RESPAWN_DEFAULT: float = 2\.25/);
  assert.match(fairItems, /FAIR_RESPAWN_15: float = 1\.95/);
  assert.match(fairItems, /FAIR_RESPAWN_18: float = 1\.65/);
  assert.match(fairItems, /box\.respawn_seconds = respawn/);
});

test("Round 2 activates the fart dizzy layer", () => {
  assert.match(fruitScene, /fruit_frenzy_v17_fart_dizzy\.gd/);
  assert.match(fartDizzy, /FART_DIZZY_SECONDS: float = 1\.0/);
  assert.match(fartDizzy, /mud_gas/);
  assert.match(fartDizzy, /heavy_gas/);
  assert.match(fartDizzy, /stink_cloud/);
  assert.match(fartDizzy, /jet_fart/);
});

test("A valid fart hit locks movement and skills through the existing Round 2 stun authority", () => {
  assert.match(fartDizzy, /stun_remaining_by_id\[target_id\]/);
  assert.match(fartDizzy, /stun_immunity_by_id\[target_id\]/);
  assert.match(fartDizzy, /target\.skill_cooldown_remaining/);
  assert.match(fartDizzy, /visual\.play_action\(&"Hit", FART_DIZZY_SECONDS\)/);
  assert.match(fartDizzy, /ROUND2 FART DIZZY/);
  assert.match(fartDizzy, /duration=1\.00 movement_lock=true skill_lock=true/);
});
