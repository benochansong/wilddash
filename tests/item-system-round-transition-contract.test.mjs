import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const partyTurbo = fs.readFileSync('godot/systems/item_system_rc9_party_turbo.gd', 'utf8');
const recap = fs.readFileSync('godot/scenes/round_recap.gd', 'utf8');

function bodyBetween(source, start, end) {
  const startIndex = source.indexOf(start);
  assert.notEqual(startIndex, -1, `missing ${start}`);
  const endIndex = source.indexOf(end, startIndex + start.length);
  assert.notEqual(endIndex, -1, `missing ${end}`);
  return source.slice(startIndex, endIndex);
}

test('Wild Turbo update validates stale scene instances before typed casts', () => {
  const body = bodyBetween(partyTurbo, 'func _update_wild_turbo', 'func _cleanup_wild_turbo');
  const validityCheck = body.indexOf('not is_instance_valid(racer_value)');
  const typedCast = body.indexOf('racer_value as WildDashCharacterController');
  assert.ok(validityCheck >= 0);
  assert.ok(typedCast > validityCheck, 'typed racer cast must happen only after instance validity check');
});

test('Wild Turbo cleanup validates racer camera and vfx objects before casting them', () => {
  const body = bodyBetween(partyTurbo, 'func _cleanup_wild_turbo', 'func _canonical_max');
  assert.match(body, /racer_value != null and is_instance_valid\(racer_value\)/);
  assert.match(body, /camera_value != null and is_instance_valid\(camera_value\)/);
  assert.match(body, /vfx_value != null and is_instance_valid\(vfx_value\)/);
});

test('Round recap still advances automatically into the next round', () => {
  assert.match(recap, /RECAP_TOTAL_SECONDS: float = 9\.0/);
  assert.match(recap, /if _elapsed >= RECAP_TOTAL_SECONDS:/);
  assert.match(recap, /GameManager\.advance_from_round_recap\(\)/);
});
