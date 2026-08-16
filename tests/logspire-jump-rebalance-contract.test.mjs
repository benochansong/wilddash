import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const rebalance = readFileSync("godot/modes/logspire_leap/logspire_jump_rebalance.gd", "utf8");
const mobility = readFileSync("godot/modes/logspire_leap/logspire_mobility_assist.gd", "utf8");
const gameManager = readFileSync("godot/scripts/game_manager.gd", "utf8");

function extractRoundIds() {
  const block = gameManager.match(/const ROUND_IDS:[^=]*= \[(.*?)\]/s);
  assert.ok(block, "missing ROUND_IDS");
  return [...block[1].matchAll(/&"([^"]+)"/g)].map((match) => match[1]);
}

test("Logspire scene wires jump accessibility before the graph/controller setup", () => {
  assert.match(scene, /logspire_jump_rebalance\.gd/);
  assert.match(scene, /JumpRebalance/);
  assert.ok(scene.indexOf("JumpRebalance") < scene.indexOf("PlatformGraph"));
});

test("Safe Route gap, landing and moving-platform forgiveness targets stay explicit", () => {
  assert.match(rebalance, /EASY_GAP_REDUCTION: float = 0\.28/);
  assert.match(rebalance, /NORMAL_GAP_REDUCTION: float = 0\.22/);
  assert.match(rebalance, /DIFFICULT_GAP_REDUCTION: float = 0\.13/);
  assert.match(rebalance, /LANDING_COLLISION_MARGIN: float = 0\.45/);
  assert.match(rebalance, /MOVING_LOG_SPEED_SCALE: float = 0\.80/);
  assert.match(rebalance, /MOVING_LOG_SIZE_SCALE: float = 1\.10/);
  assert.match(rebalance, /safe_route=easier wild_route=mastery/);
});

test("Jump input forgiveness and adaptive assists remain within the intended range", () => {
  assert.match(mobility, /COYOTE_TIME_SECONDS: float = 0\.18/);
  assert.match(mobility, /JUMP_BUFFER_SECONDS: float = 0\.18/);
  assert.match(mobility, /LANDING_FLOOR_SNAP: float = 0\.72/);
  assert.match(rebalance, /FORWARD_ASSIST_BASE: float = 0\.07/);
  assert.match(rebalance, /FORWARD_ASSIST_MAX: float = 0\.10/);
  assert.match(rebalance, /LANDING_ASSIST_BASE_METERS: float = 0\.55/);
  assert.match(rebalance, /LANDING_ASSIST_MAX_METERS: float = 0\.78/);
});

test("Fall telemetry and adaptive repeated-failure support are present", () => {
  for (const marker of [
    "LOGSPIRE JUMP BALANCE",
    "LOGSPIRE FALL RECOVERY",
    "LOGSPIRE DIFFICULTY REPORT",
    "adaptive_failures=true",
  ]) {
    assert.ok(rebalance.includes(marker), `missing jump rebalance marker: ${marker}`);
  }
  assert.match(rebalance, /failures >= 2/);
});

test("campaign order remains Grand Prix, Fruit, Logspire, Rumble, Wild Tide", () => {
  assert.deepEqual(extractRoundIds(), [
    "grand_prix",
    "fruit_collection",
    "logspire_leap",
    "push_out",
    "neon_harbor_race",
  ]);
});
