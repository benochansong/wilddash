import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const waterV15 = readFileSync(
  "godot/modes/logspire_leap/logspire_water_recovery_v15_vine_only.gd",
  "utf8",
);
const waterBase = readFileSync(
  "godot/modes/logspire_leap/logspire_water_recovery.gd",
  "utf8",
);

test("Round 3 V15 preserves an inherited checkpoint recovery instead of forcing the racer back into swimming", () => {
  assert.match(waterV15, /inherited_state == WaterState\.RECOVERY_EXIT/);
  assert.match(waterV15, /LOGSPIRE WATER CHECKPOINT PRESERVED/);

  const superIndex = waterV15.indexOf("super(racer, zone, water_y)");
  const preserveIndex = waterV15.indexOf("inherited_state == WaterState.RECOVERY_EXIT");
  const restoreIndex = waterV15.indexOf("racer.global_position = fall_position");

  assert.ok(superIndex >= 0, "V15 must still delegate water entry to the inherited recovery stack");
  assert.ok(preserveIndex > superIndex, "V15 must inspect the inherited recovery state after super()");
  assert.ok(restoreIndex > preserveIndex, "V15 must not restore the underwater fall position before preserving checkpoint fallback");
});

test("Round 3 cannot remain indefinitely in the river when no safe Vine target exists", () => {
  assert.match(waterV15, /if not direct_started:/);
  assert.match(waterV15, /_start_checkpoint_fallback\(racer, "vine_target_unavailable"\)/);
  assert.match(waterV15, /_start_checkpoint_fallback\(racer, "vine_retry_failed"\)/);
  assert.match(waterV15, /no_swim_stall=true/);
});

test("checkpoint fallback still delegates to the authoritative RecoverySystem", () => {
  assert.match(waterBase, /func _start_checkpoint_fallback\(racer: WildDashCharacterController, reason: String\)/);
  assert.match(waterBase, /_state_by_id\[racer_id\] = WaterState\.RECOVERY_EXIT/);
  assert.match(waterBase, /_recovery\.call\("force_checkpoint_recovery", racer, "water_%s" % reason\)/);
});
