import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const racerScene = readFileSync("godot/characters/test_racer.tscn", "utf8");
const characterArt = readFileSync("godot/characters/premium_character_art.gd", "utf8");
const worldArt = readFileSync("godot/tracks/graphics_phase2_world_art.gd", "utf8");
const catalog = readFileSync("godot/characters/animal_catalog.gd", "utf8");
const roundScenes = [
  readFileSync("godot/modes/grand_prix/grand_prix.tscn", "utf8"),
  readFileSync("godot/modes/fruit_collection/fruit_collection.tscn", "utf8"),
  readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8"),
  readFileSync("godot/modes/push_out/push_out.tscn", "utf8"),
  readFileSync("godot/modes/neon_harbor_race/neon_harbor_race.tscn", "utf8"),
];

test("Phase 2 premium character source is preserved but disabled in the shared production racer", () => {
  assert.doesNotMatch(racerScene, /premium_character_art\.gd/);
  assert.doesNotMatch(racerScene, /PremiumCharacterArt/);
  assert.match(racerScene, /VisualSlot/);
  assert.match(characterArt, /Graphics Phase 2 visual-only character layer/);
  assert.doesNotMatch(characterArt, /CollisionShape3D|StaticBody3D|Area3D/);
  assert.doesNotMatch(characterArt, /jump_velocity\s*=|max_speed\s*=|cruise_speed\s*=|collision_radius\s*=/);
});

test("active RC9 roster remains twelve racers including Crocodile", () => {
  const playableBlock = catalog.match(/const PLAYABLE_IDS:[\s\S]*?\]\n/);
  assert.ok(playableBlock);
  const ids = playableBlock[0].match(/&"[a-z_]+"/g) || [];
  assert.equal(ids.length, 12);
});

test("Phase 2 world art is preserved in source but disabled in every production round", () => {
  for (const scene of roundScenes) {
    assert.doesNotMatch(scene, /graphics_phase2_world_art\.gd/);
    assert.doesNotMatch(scene, /GraphicsPhase2WorldArt/);
  }
  assert.match(worldArt, /ForegroundDetail/);
  assert.match(worldArt, /GameplayArtLayer/);
  assert.match(worldArt, /BackgroundDetail/);
  assert.match(worldArt, /FarBackgroundSilhouette/);
});

test("preserved Phase 2 world art still uses instancing and no gameplay collision", () => {
  assert.match(worldArt, /MultiMesh\.new\(\)/);
  assert.match(worldArt, /MultiMesh\.TRANSFORM_3D/);
  assert.match(worldArt, /visibility_range_end/);
  assert.match(worldArt, /collision_added=false/);
  assert.doesNotMatch(worldArt, /StaticBody3D|CollisionShape3D|CharacterBody3D|NavigationObstacle3D/);
});

test("preserved landmark and Logspire decor sources remain available for later selective reuse", () => {
  for (const landmark of [
    "Landmark_SafariBaobab",
    "Landmark_FruitMarketPavilion",
    "Landmark_TitanRootCathedral",
    "Landmark_TitanGate",
    "Landmark_FinalFestival",
    "VisualRootSleeve",
    "MooncapMushrooms",
    "ForestFireflies",
  ]) {
    assert.match(worldArt, new RegExp(landmark));
  }
});
