import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const racerScene = readFileSync("godot/characters/test_racer.tscn", "utf8");
const characterArt = readFileSync("godot/characters/premium_character_art.gd", "utf8");
const worldArt = readFileSync("godot/tracks/graphics_phase2_world_art.gd", "utf8");
const grandPrix = readFileSync("godot/modes/grand_prix/grand_prix.tscn", "utf8");
const fruit = readFileSync("godot/modes/fruit_collection/fruit_collection.tscn", "utf8");
const logspire = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const rumble = readFileSync("godot/modes/push_out/push_out.tscn", "utf8");
const neon = readFileSync("godot/modes/neon_harbor_race/neon_harbor_race.tscn", "utf8");
const catalog = readFileSync("godot/characters/animal_catalog.gd", "utf8");

test("Graphics Phase 2 installs a visual-only premium layer on every shared racer", () => {
  assert.match(racerScene, /premium_character_art\.gd/);
  assert.match(racerScene, /PremiumCharacterArt/);
  assert.match(characterArt, /Graphics Phase 2 visual-only character layer/);
  assert.doesNotMatch(characterArt, /CollisionShape3D|StaticBody3D|Area3D/);
  assert.doesNotMatch(characterArt, /jump_velocity\s*=|max_speed\s*=|cruise_speed\s*=|collision_radius\s*=/);
});

test("active RC9 roster remains twelve racers including Crocodile", () => {
  const playableBlock = catalog.match(/const PLAYABLE_IDS:[\s\S]*?\]\n/);
  assert.ok(playableBlock);
  const ids = playableBlock[0].match(/&"[a-z_]+"/g) || [];
  assert.equal(ids.length, 12);
  for (const id of ["dog", "wolf", "boar", "rabbit", "deer", "monkey", "elephant", "bear", "crocodile", "cat", "fox", "raccoon"]) {
    assert.match(characterArt, new RegExp(`&"${id}"`));
  }
});

test("expression rig prepares all requested face states and blinking", () => {
  for (const state of ["neutral", "happy", "jump", "surprised", "hit", "angry", "boost", "falling", "victory"]) {
    assert.match(characterArt, new RegExp(`&"${state}"`));
  }
  assert.match(characterArt, /func set_expression/);
  assert.match(characterArt, /func notify_visual_action/);
  assert.match(characterArt, /_update_blink/);
  assert.match(characterArt, /LidL/);
  assert.match(characterArt, /BrowL/);
  assert.match(characterArt, /MouthL/);
});

test("premium racers use sculpted fur and lightweight secondary motion", () => {
  assert.match(characterArt, /_add_fur_cluster/);
  assert.match(characterArt, /SculptedFurTuft/);
  for (const role of ["ear", "tail", "head_tuft", "chest_tuft", "belly"]) {
    assert.match(characterArt, new RegExp(`&"${role}"`));
  }
  assert.match(characterArt, /_update_secondary_motion/);
  assert.doesNotMatch(characterArt, /RigidBody3D|PhysicalBone|SoftBody3D/);
});

test("Phase 2 world art remains available while Logspire uses campaign-safe visual rollback", () => {
  for (const [scene, profile] of [
    [grandPrix, "grand_prix"],
    [fruit, "fruit_frenzy"],
    [rumble, "wild_rumble"],
    [neon, "neon_harbor"],
  ]) {
    assert.match(scene, /graphics_phase2_world_art\.gd/);
    assert.match(scene, new RegExp(`round_profile = "${profile}"`));
  }
  assert.doesNotMatch(logspire, /graphics_phase2_world_art\.gd/);
  assert.match(logspire, /P0 CAMPAIGN-SAFE ROUND 3/);
  assert.match(worldArt, /&"logspire"|"logspire"/);
});

test("world art uses four depth layers and instancing without gameplay collision", () => {
  for (const layer of ["ForegroundDetail", "GameplayArtLayer", "BackgroundDetail", "FarBackgroundSilhouette"]) {
    assert.match(worldArt, new RegExp(layer));
  }
  assert.match(worldArt, /MultiMesh\.new\(\)/);
  assert.match(worldArt, /MultiMesh\.TRANSFORM_3D/);
  assert.match(worldArt, /visibility_range_end/);
  assert.match(worldArt, /collision_added=false/);
  assert.doesNotMatch(worldArt, /StaticBody3D|CollisionShape3D|CharacterBody3D|NavigationObstacle3D/);
});

test("each round owns at least three named visual landmarks", () => {
  const groups = {
    safari: ["Landmark_SafariBaobab", "Landmark_SunstoneRaceArch", "Landmark_AdventureBalloon"],
    fruit: ["Landmark_FruitMarketPavilion", "Landmark_GoldenFruitShrine", "Landmark_JuiceFestivalTower"],
    forest: ["Landmark_TitanRootCathedral", "Landmark_MooncapGrove", "Landmark_AncientFireflyGate"],
    rumble: ["Landmark_TitanGate", "Landmark_ChampionTotems", "Landmark_ChampionDais"],
    neon: ["Landmark_HoloHarborTower", "Landmark_FestivalCrane", "Landmark_FinalFestival"],
  };
  for (const landmarks of Object.values(groups)) {
    for (const landmark of landmarks) assert.match(worldArt, new RegExp(landmark));
  }
});

test("Logspire decor source remains available without editing route or recovery data", () => {
  assert.match(worldArt, /get_main_route_points/);
  assert.match(worldArt, /VisualRootSleeve/);
  assert.match(worldArt, /MossHighlight/);
  assert.match(worldArt, /MassiveRoot/);
  assert.match(worldArt, /MooncapMushrooms/);
  assert.match(worldArt, /ForestFireflies/);
  assert.doesNotMatch(worldArt, /Platform Gap|checkpoint_restart|LADDER_|RECOVERY_|jump_velocity/);
});

test("visual performance rules remain explicit", () => {
  assert.match(worldArt, /_multimesh_instances/);
  assert.match(worldArt, /DisplayServer\.get_name\(\) == "headless"/);
  assert.match(characterArt, /DisplayServer\.get_name\(\) == "headless"/);
  assert.match(worldArt, /TRANSPARENCY_ALPHA/);
  assert.equal((worldArt.match(/_transparent_emissive\(/g) || []).length, 2, "transparent helper should be used only for the limited forest shaft pass");
});
