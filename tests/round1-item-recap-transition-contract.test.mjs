import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const source = fs.readFileSync('godot/systems/item_system_rc9_round1_impact.gd', 'utf8');

test('Round 1 impact state shuts down as soon as GameManager marks the round inactive', () => {
  assert.match(
    source,
    /return GameManager\.round_active and RaceManager\.active and GameManager\.get_current_round_id\(\) == &"grand_prix"/
  );
});

test('Round 1 chain telemetry does not retain racer Nodes across recap scene teardown', () => {
  assert.match(source, /"target_label": _label\(target\)/);
  assert.doesNotMatch(source, /"target": target/);
  assert.doesNotMatch(source, /data\.get\("target"\) as Node/);
});

test('Round 1 shockwave validates racer variants before typed casts', () => {
  const guard = source.indexOf('if value == null or not is_instance_valid(value):');
  const cast = source.indexOf('var target: WildDashCharacterController = value as WildDashCharacterController');
  assert.ok(guard >= 0, 'expected stale racer guard');
  assert.ok(cast > guard, 'stale racer guard must run before the typed cast');
});
