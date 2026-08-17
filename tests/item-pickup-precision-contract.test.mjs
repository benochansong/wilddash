import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const itemBox = readFileSync("godot/items/item_box.gd", "utf8");
const round1 = readFileSync("godot/modes/grand_prix/grand_prix_v6_item_fairness.gd", "utf8");
const round3 = readFileSync("godot/modes/logspire_leap/logspire_leap_v2_item_precision.gd", "utf8");
const round3Scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");

test("Shared item box exposes a per-round pickup profile", () => {
  assert.match(itemBox, /func configure_pickup_profile\(/);
  assert.match(itemBox, /pickup_radius_scale/);
  assert.match(itemBox, /pickup_global_lock_msec/);
  assert.match(itemBox, /allow_player_replace_held/);
  assert.match(itemBox, /HELD_ITEM_PLAYER/);
});

test("Round 1 narrows pickup lanes and prevents multi-box replacement chains", () => {
  assert.match(round1, /ROUND1_PICKUP_RADIUS_SCALE: float = 0\.50/);
  assert.match(round1, /ROUND1_PICKUP_COLLISION_RADIUS: float = 1\.35/);
  assert.match(round1, /FAIR_GLOBAL_LOCK_MSEC: int = 1100/);
  assert.match(round1, /FAIR_RELAY_RADIUS: float = 2\.60/);
  assert.match(round1, /configure_pickup_profile\(/);
  assert.match(round1, /one_item_at_a_time=true/);
});

test("Round 3 narrows pickup lanes and keeps only one held item at a time", () => {
  assert.match(round3Scene, /logspire_leap_v2_item_precision\.gd/);
  assert.match(round3, /LOGSPIRE_PICKUP_RADIUS_SCALE: float = 0\.50/);
  assert.match(round3, /LOGSPIRE_PICKUP_COLLISION_RADIUS: float = 1\.35/);
  assert.match(round3, /LOGSPIRE_PICKUP_LOCK_MSEC: int = 1100/);
  assert.match(round3, /configure_pickup_profile\(/);
  assert.match(round3, /one_item_at_a_time=true/);
});
