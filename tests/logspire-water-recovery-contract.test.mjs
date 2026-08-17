import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const scene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const water = readFileSync("godot/modes/logspire_leap/logspire_water_recovery.gd", "utf8");
const waterV2 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v2.gd", "utf8");
const waterV3 = readFileSync("godot/modes/logspire_leap/logspire_water_recovery_v3_entry_guard.gd", "utf8");
const swim = readFileSync("godot/modes/logspire_leap/logspire_swim_controller.gd", "utf8");
const ladder = readFileSync("godot/modes/logspire_leap/logspire_ladder_system.gd", "utf8");
const waterAI = readFileSync("godot/modes/logspire_leap/logspire_water_ai.gd", "utf8");
const recovery = readFileSync("godot/modes/logspire_leap/logspire_recovery_system.gd", "utf8");
const graph = readFileSync("godot/modes/logspire_leap/logspire_platform_graph.gd", "utf8");
const character = readFileSync("godot/characters/character_controller.gd", "utf8");

test("Logspire scene wires guarded Canopy River and ladder recovery without replacing core systems", () => {
  assert.match(scene, /logspire_water_recovery_v3_entry_guard\.gd/);
  assert.match(scene, /logspire_ladder_system\.gd/);
  assert.match(scene, /WaterRecovery/);
  assert.match(scene, /LadderSystem/);
  assert.match(scene, /RecoverySystem/);
  assert.match(scene, /PlatformGameplay/);
  assert.match(scene, /Phase3Director/);
});

test("Canopy River uses six zones, water-first recovery and bounded fallback", () => {
  assert.equal((water.match(/\{"zone": [0-5], "center":/g) || []).length, 6);
  assert.match(water, /PLAYER_WATER_TIMEOUT: float = 13\.5/);
  assert.match(water, /AI_WATER_TIMEOUT: float = 10\.0/);
  assert.match(water, /LADDER_CLIMB_SECONDS: float = 2\.15/);
  assert.match(water, /LOGSPIRE WATER ENTRY/);
  assert.match(water, /LOGSPIRE WATER RECOVERY/);
  assert.match(water, /LOGSPIRE WATER FALLBACK/);
  assert.match(waterV2, /LOGSPIRE SWIM/);
  assert.match(recovery, /set_water_recovery/);
  assert.match(recovery, /force_checkpoint_recovery/);
  assert.match(recovery, /_water_should_handle/);
});

test("Start-grid racers cannot be mistaken for swimmers", () => {
  assert.match(waterV3, /if racer\.is_on_floor\(\):\n\t\treturn false/);
  assert.match(waterV3, /WATER_ENTRY_MIN_DOWN_SPEED: float = -0\.55/);
  assert.match(waterV3, /WATER_ENTRY_MAX_BODY_ABOVE_SURFACE: float = 1\.05/);
  assert.match(waterV3, /racer\.global_position\.y > water_y \+ WATER_ENTRY_MAX_BODY_ABOVE_SURFACE/);
  assert.match(waterV3, /LOGSPIRE WATER ENTRY REJECT/);
  assert.match(waterV3, /"water_y": -0\.15/);
});

test("Swimming stays a recovery route instead of a shortcut", () => {
  assert.match(swim, /SWIM_SPEED_RATIO: float = 0\.50/);
  assert.match(swim, /species_scale = 0\.92/);
  assert.match(swim, /racer\.animal_id == &"crocodile"/);
  assert.match(swim, /species_scale \*= 1\.10/);
  assert.match(swim, /SURFACE_BODY_OFFSET: float = 0\.52/);
});

test("Ladder network has 19 local exits with visible guidance and safe decks", () => {
  const entries = ladder.match(/\{"zone": \d, "platform": &"[^"]+"\}/g) || [];
  assert.equal(entries.length, 19);
  assert.match(ladder, /DECK_SIZE := Vector3\(6\.0, 0\.45, 6\.0\)/);
  assert.match(ladder, /MultiMesh\.TRANSFORM_3D/);
  assert.match(ladder, /CLIMB ↑/);
});

test("Ladder system calls the actual PlatformGraph landing-radius API", () => {
  assert.match(graph, /func get_landing_radius\(platform_id: StringName\) -> float:/);
  assert.match(ladder, /_graph\.call\("get_landing_radius", platform_id\)/);
  assert.doesNotMatch(ladder, /_graph\.call\("get_platform_landing_radius"/);
});

test("Water AI selects ladders by distance and route progress", () => {
  assert.match(waterAI, /planar_distance/);
  assert.match(waterAI, /route_index/);
  assert.match(waterAI, /checkpoint_progress/);
});

test("Global CharacterController remains untouched by the water implementation", () => {
  assert.doesNotMatch(character, /CANOPY RIVER|WATER_ENTRY|LADDER_CLIMB/);
});
