import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const policy = readFileSync("godot/modes/logspire_leap/logspire_player_manual_throttle.gd", "utf8");
const controller = readFileSync("godot/characters/character_controller.gd", "utf8");

test("Round 3 wires a player-only manual throttle policy", () => {
  assert.match(scene, /logspire_player_manual_throttle\.gd/);
  assert.match(scene, /\[node name="PlayerManualThrottle" type="Node" parent="\."\]/);
  assert.match(policy, /MODE_ID: StringName = &"logspire_leap"/);
  assert.match(policy, /DisplayServer\.get_name\(\) == "headless"/);
  assert.match(policy, /not racer\.is_player/);
});

test("Neutral input removes Round 3 self-propelled cruise without changing shared controller defaults", () => {
  assert.match(controller, /var target_speed := cruise_speed/);
  assert.match(policy, /racer\.cruise_speed = 0\.0/);
  assert.match(policy, /InputManager\.get_throttle_axis\(\)/);
  assert.match(policy, /NEUTRAL_THROTTLE_DEADZONE: float = 0\.05/);
  assert.match(policy, /racer\.current_speed = 0\.0/);
});

test("External hit and skill motion are preserved while neutral self-propulsion is stopped", () => {
  assert.match(policy, /racer\.get_knockback_velocity\(\)/);
  assert.match(policy, /_skill_impulse_velocity/);
  assert.match(policy, /knockback\.length_squared\(\) > 0\.0025/);
  assert.match(policy, /skill_impulse\.length_squared\(\) > 0\.0025/);
});
