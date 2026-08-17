import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const phaseC = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v5_fun_pass.gd", "utf8");
const camera = readFileSync("godot/modes/logspire_leap/logspire_recovery_chase_camera.gd", "utf8");
const graph = readFileSync("godot/modes/logspire_leap/logspire_platform_graph.gd", "utf8");
const phaseA = readFileSync("godot/modes/logspire_leap/logspire_jump_gap_guard.gd", "utf8");
const phaseB = readFileSync("godot/modes/logspire_leap/logspire_platform_ai_v5_phase_b.gd", "utf8");

test("Phase C layers fun polish on top of Phase A and Phase B without replacing them", () => {
  assert.match(scene, /logspire_leap_v4_phase_b\.gd/);
  assert.match(scene, /logspire_jump_rebalance_v2_phase_b\.gd/);
  assert.match(scene, /logspire_jump_gap_guard\.gd/);
  assert.match(scene, /logspire_phase3_director_v5_fun_pass\.gd/);
  assert.match(phaseC, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v4_major_collision\.gd"/);
  assert.match(phaseB, /PHASE_B_FIVE_LANES: int = 5/);
});

test("Safe versus Wild identity keeps the shortcut valuable without increasing Safe gaps", () => {
  assert.match(graph, /clampf\(saving_meters \/ 11\.5 \+ 2\.6, 4\.0, 8\.0\)/);
  assert.match(phaseC, /safe=easy_stable wild=mushroom_vine_swing/);
  assert.match(phaseC, /gap_increase=false/);
  assert.match(phaseC, /platform_shrink=false/);
  assert.match(phaseC, /jump_power_nerf=false/);
  assert.match(phaseA, /ZONE1_MAX_SURFACE_GAP_M: float = 2\.25/);
  assert.match(phaseA, /ZONE3_MAX_SURFACE_GAP_M: float = 2\.35/);
});

test("Rolling Grove, Titan Tree and Finale receive readable guidance instead of harder jumps", () => {
  for (const marker of [
    "LOGSPIRE ROLLING GROVE FUN READY",
    "LOGSPIRE VISUAL GUIDANCE READY",
    "LOGSPIRE ROUTE CHOICE PLAYER",
    "LOGSPIRE FUN REPORT",
  ]) {
    assert.ok(phaseC.includes(marker), `missing Phase C telemetry: ${marker}`);
  }
  assert.match(phaseC, /ROLLING_GUIDE_IDS/);
  assert.match(phaseC, /TITAN_GUIDE_IDS/);
  assert.match(phaseC, /FINALE_GUIDE_IDS/);
  assert.match(phaseC, /SAFE · STEADY/);
  assert.match(phaseC, /WILD · 4-8s SHORTCUT/);
});

test("Round 3 camera can frame the next readable target without taking over recovery yaw", () => {
  assert.match(camera, /func set_race_focus\(/);
  assert.match(camera, /func clear_race_focus\(\)/);
  assert.match(camera, /RACE_FOCUS_MAX_BLEND: float = 0\.34/);
  assert.match(camera, /if not _recovery_mode:/);
  assert.match(camera, /_apply_race_focus\(\)/);
  assert.match(camera, /RECOVERY_MOUSE_YAW_SENSITIVITY/);
});

test("Final Jump assist only catches near-successes and never teleports or buffs jump power", () => {
  assert.match(phaseC, /FINAL_LANDING_EXTRA_METERS: float = 0\.75/);
  assert.match(phaseC, /FINAL_DESCENT_CAP: float = -1\.10/);
  assert.match(phaseC, /LOGSPIRE FINAL LANDING ASSIST/);
  assert.match(phaseC, /teleport=false jump_power_unchanged=true/);
  assert.doesNotMatch(phaseC, /reset_motion\(/);
});
