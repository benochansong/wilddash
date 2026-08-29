import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';

const recoveryPath = new URL('../godot/modes/logspire_leap/logspire_recovery_system.gd', import.meta.url);
const waterPath = new URL('../godot/modes/logspire_leap/logspire_water_recovery_v13_integrated_qa.gd', import.meta.url);

test('Round 3 checkpoint recovery respawns with runway and suppresses automatic forward drift', async () => {
  const source = await readFile(recoveryPath, 'utf8');

  assert.match(source, /RECOVERY_RETRY_GRACE_SECONDS:\s*float\s*=\s*1\.25/);
  assert.match(source, /safe_spawn:\s*Vector3\s*=\s*target_position\s*-\s*forward\s*\*\s*runway_backoff/);
  assert.match(source, /racer\.reset_motion\(safe_spawn\)/);
  assert.match(source, /racer\.current_speed\s*=\s*0\.0/);
  assert.match(source, /begin_retry_grace\(racer,\s*"checkpoint_recovery"\)/);
  assert.match(source, /func _enforce_retry_grace\(racer: WildDashCharacterController\)/);
});

test('Round 3 assisted water exits receive the same retry grace', async () => {
  const source = await readFile(waterPath, 'utf8');

  assert.match(source, /_request_retry_grace\(racer,\s*"assisted_recovery_exit"\)/);
  assert.match(source, /_request_retry_grace\(racer,\s*"water_recovery_exit"\)/);
  assert.match(source, /recovery_system\.call\("begin_retry_grace",\s*racer,\s*source\)/);
});
