import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const scene = readFileSync('godot/modes/wild_current/wild_current.tscn', 'utf8');
const helper = readFileSync('godot/modes/wild_current/wild_current_crocodile_swim_advantage.gd', 'utf8');
const crocodile = readFileSync('godot/characters/definitions/crocodile.tres', 'utf8');

test('Round 5 production scene wires the crocodile aquatic specialization', () => {
  assert.match(scene, /wild_current_crocodile_swim_advantage\.gd/);
  assert.match(scene, /CrocodileSwimAdvantage/);
  assert.match(scene, /wild_current_race_phase2\.gd/);
});

test('crocodile has a clearly superior Round 5 water speed profile', () => {
  const max = Number(helper.match(/CROCODILE_MAX_SWIM_SPEED: float = ([0-9.]+)/)?.[1]);
  const cruise = Number(helper.match(/CROCODILE_CRUISE_SWIM_SPEED: float = ([0-9.]+)/)?.[1]);
  const response = Number(helper.match(/CROCODILE_MOMENTUM_RESPONSE_SCALE: float = ([0-9.]+)/)?.[1]);
  const lateral = Number(helper.match(/CROCODILE_LATERAL_CURRENT_SCALE: float = ([0-9.]+)/)?.[1]);
  const dive = Number(helper.match(/CROCODILE_DIVE_RECHARGE_SCALE: float = ([0-9.]+)/)?.[1]);

  assert.ok(max >= 14.0, `expected crocodile max swim speed >= 14.0, got ${max}`);
  assert.ok(cruise >= 10.0, `expected crocodile cruise swim speed >= 10.0, got ${cruise}`);
  assert.ok(response <= 0.93, `expected stronger propulsion response, got ${response}`);
  assert.ok(lateral <= 0.92, `expected reduced lateral current displacement, got ${lateral}`);
  assert.ok(dive <= 0.90, `expected faster dive recharge, got ${dive}`);
});

test('the aquatic bonus is crocodile-only and does not alter its land definition', () => {
  assert.match(helper, /animal_id != &"crocodile"/);
  assert.match(helper, /round5_only=true/);
  assert.match(helper, /r5_crocodile_water_advantage/);
  assert.match(crocodile, /role = "Water Bruiser"/);
  assert.match(crocodile, /max_speed = 13\.0/);
  assert.doesNotMatch(helper, /configure_animal\(/);
});
