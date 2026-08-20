import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";
import test from "node:test";

const gameManager = readFileSync("godot/scripts/game_manager.gd", "utf8");
const logspireScene = readFileSync("godot/modes/logspire_leap/logspire_leap.tscn", "utf8");
const phase3 = readFileSync("godot/modes/logspire_leap/logspire_phase3_director.gd", "utf8");
const phase3Perf = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v2_performance.gd", "utf8");
const phase3Water = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v3_water_priority.gd", "utf8");
const phase3Collision = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v4_major_collision.gd", "utf8");
const phase3Clearance = readFileSync("godot/modes/logspire_leap/logspire_phase3_director_v5_route_clearance.gd", "utf8");
const graph = readFileSync("godot/modes/logspire_leap/logspire_platform_graph.gd", "utf8");
const ai = readFileSync("godot/modes/logspire_leap/logspire_platform_ai.gd", "utf8");
const neonScene = readFileSync("godot/modes/neon_harbor_race/neon_harbor_race.tscn", "utf8");
const neonRound5 = readFileSync("godot/modes/neon_harbor_race/neon_harbor_race_v8_round5_campaign.gd", "utf8");
const audio = readFileSync("godot/scripts/audio_manager.gd", "utf8");

function extractStringNames(blockName) {
  const block = gameManager.match(new RegExp(`const ${blockName}:[^=]*= \\[(.*?)\\]`, "s"));
  assert.ok(block, `missing ${blockName}`);
  return [...block[1].matchAll(/&"([^"]+)"/g)].map((match) => match[1]);
}

function extractScenePaths() {
  const block = gameManager.match(/const ROUND_SCENES:[^=]*= \[(.*?)\]/s);
  assert.ok(block, "missing ROUND_SCENES");
  return [...block[1].matchAll(/"(res:\/\/modes\/[^"]+\.tscn)"/g)].map((match) => match[1]);
}

test("production campaign is Grand Prix -> Fruit -> Logspire -> Rumble -> Wild Tide", () => {
  assert.deepEqual(extractStringNames("ROUND_IDS"), [
    "grand_prix",
    "fruit_collection",
    "logspire_leap",
    "push_out",
    "neon_harbor_race",
  ]);
  assert.deepEqual(extractScenePaths(), [
    "res://modes/grand_prix/grand_prix.tscn",
    "res://modes/fruit_collection/fruit_collection.tscn",
    "res://modes/logspire_leap/logspire_leap.tscn",
    "res://modes/push_out/push_out.tscn",
    "res://modes/neon_harbor_race/neon_harbor_race.tscn",
  ]);
  assert.match(gameManager, /CAMPAIGN ROUND 3 LOGSPIRE/);
  assert.match(gameManager, /CAMPAIGN ROUND 5 NEON HARBOR/);
  assert.match(gameManager, /final_round=neon_harbor_race/);
});

test("Logspire scene wires production spectacle through performance, water-priority, major-collision and route-clearance adapters", () => {
  assert.match(logspireScene, /logspire_phase3_director_v5_route_clearance\.gd/);
  assert.match(phase3Clearance, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v4_major_collision\.gd"/);
  assert.match(phase3Collision, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v3_water_priority\.gd"/);
  assert.match(phase3Water, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director_v2_performance\.gd"/);
  assert.match(phase3Perf, /extends "res:\/\/modes\/logspire_leap\/logspire_phase3_director\.gd"/);
  assert.match(logspireScene, /Phase3Director/);
  for (const marker of [
    "LOGSPIRE LIVING TREE EVENT START",
    "LOGSPIRE LIVING TREE STATE B",
    "LOGSPIRE WOODPECKER",
    "LOGSPIRE SQUIRREL STAMPEDE",
    "LOGSPIRE FINAL TREE FALL START",
    "LOGSPIRE FINAL JUMP",
  ]) {
    assert.ok(phase3.includes(marker), `missing Phase 3 telemetry: ${marker}`);
  }
  assert.match(phase3Water, /FINAL RECOVERY CANCELLED BY WATER/);
  assert.match(phase3Collision, /LOGSPIRE MAJOR WORLD COLLISION READY/);
  assert.match(phase3Clearance, /LOGSPIRE ROUTE GEOMETRY CLEARANCE READY/);
  assert.match(phase3Clearance, /_sync_visible_geometry_to_collision/);
  assert.match(phase3Clearance, /_eject_racers_from_major_geometry/);
  assert.match(graph, /set_world_state/);
  assert.match(graph, /cached_routes_valid=true/);
  assert.match(ai, /notify_phase3_state/);
  assert.match(ai, /FINAL_BRIDGE_JUMP_TRIGGER/);
});

test("Wild Tide remains intact but is presented as Round 5", () => {
  assert.match(neonScene, /neon_harbor_race_v8_round5_campaign\.gd/);
  assert.match(neonRound5, /extends "res:\/\/modes\/neon_harbor_race\/neon_harbor_race_v7_party_items\.gd"/);
  assert.match(neonRound5, /ROUND 5 — WILD TIDE: JUNGLE HARBOR/);
  assert.match(neonRound5, /wild_tide_v7_preserved=true/);
});

test("Tidal Clash is preserved outside the base five-round campaign", () => {
  const tidalFiles = [
    "godot/modes/tidal_clash/tidal_clash.gd",
    "godot/modes/tidal_clash/tidal_clash.tscn",
    "godot/modes/tidal_clash/tidal_clash_track.gd",
    "godot/modes/tidal_clash/tidal_clash_hazard_controller.gd",
    "godot/modes/tidal_clash/tidal_clash_ai_water_strategy.gd",
    "godot/modes/tidal_clash/tidal_clash_world_controller.gd",
  ];
  for (const path of tidalFiles) {
    assert.ok(existsSync(path), `Tidal Clash preservation failure: ${path}`);
  }
  assert.doesNotMatch(gameManager.match(/const ROUND_IDS:[^=]*= \[(.*?)\]/s)[1], /tidal_clash/);
});

test("Logspire audio hooks cover forest, titan, finale and hazards", () => {
  for (const id of [
    "race_logspire",
    "race_logspire_titan",
    "race_logspire_finale",
    "wood_land",
    "wood_crack",
    "wood_break",
    "log_roll",
    "log_swing",
    "mushroom_bounce",
    "vine_swing",
    "woodpecker",
    "squirrel_rush",
    "tree_creak",
    "tree_fall",
    "wild_finish",
  ]) {
    assert.ok(audio.includes(`\"${id}\"`), `missing AudioManager hook: ${id}`);
  }
});
