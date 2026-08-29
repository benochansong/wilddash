import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const itemBox = readFileSync("godot/items/item_box.gd", "utf8");
const round1 = readFileSync("godot/modes/grand_prix/grand_prix_v6_item_fairness.gd", "utf8");
const round3 = readFileSync("godot/modes/logspire_leap/logspire_leap_v2_item_precision.gd", "utf8");

test("Shared item box exposes per-round pickup tuning", () => {
  assert.match(itemBox, /func configure_pickup_profile/);
  assert.match(itemBox, /pickup_radius_scale/);
  assert.match(itemBox, /pickup_global_lock_msec/);
  assert.match(itemBox, /allow_player_replace_held/);
});

test("Round 1 uses forgiving pickup plus anti-sweep lock", () => {
  assert.match(round1, /ROUND1_PICKUP_RADIUS_SCALE: float = 0\.82/);
  assert.match(round1, /ROUND1_PICKUP_COLLISION_RADIUS: float = 1\.85/);
  assert.match(round1, /FAIR_GLOBAL_LOCK_MSEC: int = 900/);
  assert.match(round1, /easy_pickup=true/);
});

test("Round 3 uses forgiving pickup plus anti-sweep lock", () => {
  assert.match(round3, /LOGSPIRE_PICKUP_RADIUS_SCALE: float = 0\.82/);
  assert.match(round3, /LOGSPIRE_PICKUP_COLLISION_RADIUS: float = 1\.85/);
  assert.match(round3, /LOGSPIRE_PICKUP_LOCK_MSEC: int = 900/);
  assert.match(round3, /replace_allowed=true/);
});
