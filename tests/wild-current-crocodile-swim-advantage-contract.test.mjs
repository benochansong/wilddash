import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const scene = readFileSync('godot/modes/wild_current/wild_current.tscn', 'utf8');
const helper = readFileSync('godot/modes/wild_current/wild_current_crocodile_swim_advantage.gd', 'utf8');
const swimmer = readFileSync('godot/modes/wild_current/wild_current_swimmer_phase2.gd', 'utf8');
const crocodile = readFileSync('godot/characters/definitions/crocodile.tres', 'utf8');
const crocodileVisual = readFileSync('godot/characters/crocodile_visual.gd', 'utf8');

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

test('crocodile gains a strong but bounded Round 5 tail sweep in water', () => {
  const range = Number(helper.match(/TAIL_SWEEP_RANGE: float = ([0-9.]+)/)?.[1]);
  const knockback = Number(helper.match(/TAIL_SWEEP_KNOCKBACK: float = ([0-9.]+)/)?.[1]);
  const diveScale = Number(helper.match(/TAIL_SWEEP_DIVE_POWER_SCALE: float = ([0-9.]+)/)?.[1]);
  const maxHits = Number(helper.match(/TAIL_SWEEP_MAX_HITS: int = ([0-9]+)/)?.[1]);

  assert.ok(range >= 4.5 && range <= 5.2, `expected readable close-range sweep, got ${range}`);
  assert.ok(knockback >= 8.0 && knockback <= 10.0, `expected meaningful water knockback, got ${knockback}`);
  assert.ok(diveScale >= 1.10 && diveScale <= 1.15, `expected modest submerged power edge, got ${diveScale}`);
  assert.ok(maxHits >= 1 && maxHits <= 3, `expected bounded multi-hit sweep, got ${maxHits}`);
  assert.match(helper, /race_combat_action_resolved/);
  assert.match(helper, /kind not in \[&"tap", &"hold"\]/);
  assert.match(helper, /source=%s diving=%s range=/);
  assert.match(helper, /r5_crocodile_tail_hit/);
  assert.match(helper, /r5_crocodile_tail_sweep/);
});

test('Round 5 swimmer owns persistent water-combat push instead of land knockback physics', () => {
  assert.match(swimmer, /WATER_COMBAT_PUSH_DECAY/);
  assert.match(swimmer, /_water_combat_push_velocity/);
  assert.match(swimmer, /func apply_water_combat_push\(/);
  assert.match(swimmer, /r5_water_combat_push/);
  assert.match(helper, /apply_water_combat_push\(planar, power, retention\)/);
  assert.doesNotMatch(helper, /reset_motion\(/);
  assert.doesNotMatch(helper, /global_position\s*=/);
});

test('tail sweep has crocodile-specific visual feedback and AI can use it without teleporting', () => {
  assert.match(crocodileVisual, /func play_tail_sweep\(/);
  assert.match(crocodileVisual, /TailA/);
  assert.match(crocodileVisual, /TailB/);
  assert.match(crocodileVisual, /TailTip/);
  assert.match(helper, /_update_ai_tail_attacks/);
  assert.match(helper, /AI_ATTACK_OPENING_GRACE/);
  assert.match(helper, /teleport=false/);
});

test('the aquatic bonus is crocodile-only and does not alter its land definition', () => {
  assert.match(helper, /animal_id != &"crocodile"/);
  assert.match(helper, /round5_only=true/);
  assert.match(helper, /r5_crocodile_water_advantage/);
  assert.match(crocodile, /role = "Water Bruiser"/);
  assert.match(crocodile, /max_speed = 13\.0/);
  assert.doesNotMatch(helper, /configure_animal\(/);
});