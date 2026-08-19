import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const distribution = readFileSync("godot/modes/grand_prix/grand_prix_v5_item_chaos.gd", "utf8");
const fairness = readFileSync("godot/modes/grand_prix/grand_prix_v6_item_fairness.gd", "utf8");
const wildMoments = readFileSync("godot/modes/grand_prix/grand_prix_v7_wild_moments.gd", "utf8");
const scene = readFileSync("godot/modes/grand_prix/grand_prix.tscn", "utf8");
const gameManager = readFileSync("godot/scripts/game_manager.gd", "utf8");
const track = readFileSync("godot/tracks/grand_prix_track.gd", "utf8");

function floatArray(source, name) {
  const match = source.match(new RegExp(`const ${name}: Array\\[float\\] = \\[([\\s\\S]*?)\\]`));
  assert.ok(match, `missing ${name}`);
  return match[1]
    .split(",")
    .map((value) => Number(value.trim()))
    .filter((value) => Number.isFinite(value));
}

const stations = floatArray(distribution, "ITEM_STATION_PROGRESS");
const battleStations = floatArray(distribution, "WIDE_STATION_PROGRESS");
const normalLanes = floatArray(distribution, "DISTANCE_ITEM_BOX_LANE_OFFSETS");
const lanes10 = floatArray(distribution, "DENSITY_ITEM_BOX_LANES_10");
const lanes15 = floatArray(distribution, "DENSITY_ITEM_BOX_LANES_15");
const lanes18 = floatArray(distribution, "DENSITY_ITEM_BOX_LANES_18");

function boxCount(denseLaneCount) {
  return (stations.length - battleStations.length) * normalLanes.length + battleStations.length * denseLaneCount;
}

function densityGain(count) {
  return ((count / 36) - 1) * 100;
}

test("Round 1 expands progress-sampled item stations while keeping danger sections clear", () => {
  assert.equal(stations.length, 14);
  assert.equal(battleStations.length, 3);
  assert.equal(stations[0], 0.055);
  assert.equal(stations.at(-1), 0.975);

  const gaps = stations.slice(1).map((value, index) => value - stations[index]);
  assert.ok(Math.max(...gaps) <= 0.13, "item acquisition gap exceeded protected maximum");

  for (const progress of stations) {
    assert.ok(progress < 0.400 || progress > 0.475, `station ${progress} entered Long Downhill/River danger window`);
    assert.ok(progress < 0.862 || progress > 0.899, `station ${progress} entered Tunnel danger window`);
  }

  assert.match(track, /"Long Downhill", "River Approach", "River Bridge"/);
  assert.match(track, /"Tunnel", "Final S Curve", "Final Chicane", "Final Straight"/);
  assert.match(distribution, /DANGER_PROGRESS_WINDOWS/);
  assert.match(distribution, /danger_stations=%d/);
});

test("10, 15 and 18 racer fields receive roughly 40 to 60 percent more boxes", () => {
  assert.equal(normalLanes.length, 3);
  assert.equal(lanes10.length, 6);
  assert.equal(lanes15.length, 7);
  assert.equal(lanes18.length, 8);

  const counts = [boxCount(lanes10.length), boxCount(lanes15.length), boxCount(lanes18.length)];
  assert.deepEqual(counts, [51, 54, 57]);
  for (const count of counts) {
    const gain = densityGain(count);
    assert.ok(gain >= 40 && gain <= 60, `density gain ${gain.toFixed(1)}% is outside target band`);
  }

  assert.match(distribution, /if racer_count >= 18:/);
  assert.match(distribution, /if racer_count >= 15:/);
  assert.match(distribution, /if racer_count >= 10:/);
  assert.match(distribution, /density_gain=%.1f%%/);
});

test("start, Rally Straight and Final Straight use dense battle stations with staggered opening rows", () => {
  assert.deepEqual(battleStations, [0.055, 0.345, 0.975]);
  assert.match(distribution, /START_STAGGER_METERS: float = 1\.35/);
  assert.match(distribution, /_station_longitudinal_stagger/);
  assert.match(distribution, /lane_index % 2 == 0/);
  assert.match(track, /"Rally Straight"/);
  assert.match(track, /"Final Straight"/);
});

test("Round 1 keeps V6 anti-sweep, relay and racer-count respawn behavior", () => {
  assert.match(fairness, /FAIR_GLOBAL_LOCK_MSEC: int = 900/);
  assert.match(fairness, /FAIR_STATION_LOCK_MSEC: int = 6000/);
  assert.match(fairness, /FAIR_RELAY_WINDOW_MSEC: int = 2600/);
  assert.match(fairness, /configure_pickup_profile\(/);
  assert.match(fairness, /if RaceManager\.racers\.size\(\) >= 18:/);
  assert.match(fairness, /elif RaceManager\.racers\.size\(\) >= 15:/);
  assert.match(fairness, /leader_excluded=true trailing_shared=true/);
});

test("production Round 1 still uses the V7 to V6 to V5 chain and campaign order is unchanged", () => {
  assert.match(scene, /grand_prix_v7_wild_moments\.gd/);
  assert.match(wildMoments, /extends "res:\/\/modes\/grand_prix\/grand_prix_v6_item_fairness\.gd"/);
  assert.match(fairness, /extends "res:\/\/modes\/grand_prix\/grand_prix_v5_item_chaos\.gd"/);

  const r1 = gameManager.indexOf('&"grand_prix"');
  const r2 = gameManager.indexOf('&"fruit_collection"');
  const r3 = gameManager.indexOf('&"logspire_leap"');
  assert.ok(r1 >= 0 && r2 > r1 && r3 > r2);
  assert.match(gameManager, /ROUND_RECAP/);
});
