import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

const project = read('godot/project.godot');
const manager = read('godot/scripts/game_manager_rc9_round5_wild_current.gd');
const scene = read('godot/modes/wild_current/wild_current.tscn');
const mode = read('godot/modes/wild_current/wild_current_race.gd');
const phase2 = read('godot/modes/wild_current/wild_current_race_phase2.gd');
const phase3 = read('godot/modes/wild_current/wild_current_race_phase3_long_battle.gd');
const swimmer = read('godot/modes/wild_current/wild_current_swimmer.gd');
const current = read('godot/modes/wild_current/wild_current_volume.gd');
const whirlpool = read('godot/modes/wild_current/wild_whirlpool_volume.gd');

test('production campaign replaces legacy Round 5 with Wild Current only', () => {
  assert.match(project, /GameManager="\*res:\/\/scripts\/game_manager_rc9_round5_wild_current\.gd"/);
  assert.match(manager, /&"push_out",\s*&"wild_current"/s);
  assert.match(manager, /res:\/\/modes\/wild_current\/wild_current\.tscn/);
  assert.doesNotMatch(manager, /WILD_CURRENT_ROUND_SCENES[\s\S]*neon_harbor_race/);
  assert.match(manager, /r5_campaign_complete[\s\S]*final_round=wild_current/);
});

test('Round 5 production scene points at Phase 3 while preserving the swim-only foundation', () => {
  assert.match(scene, /res:\/\/modes\/wild_current\/wild_current_race_phase3_long_battle\.gd/);
  assert.match(phase3, /extends "res:\/\/modes\/wild_current\/wild_current_race_phase2\.gd"/);
  assert.match(phase2, /extends "res:\/\/modes\/wild_current\/wild_current_race\.gd"/);
  assert.match(mode, /&"wild_current"/);
  assert.match(mode, /WILD CURRENT: RIVER RUSH/);
  assert.match(mode, /ContinuousWaterSurface/);
  assert.match(mode, /land_requirement=false/);
});

test('shared racer land physics is replaced by Round 5 swim locomotion', () => {
  assert.match(swimmer, /racer\.set_physics_process\(false\)/);
  assert.match(swimmer, /SURFACE_Y/);
  assert.match(swimmer, /DIVE_Y/);
  assert.match(swimmer, /WATER_DRAG_RESPONSE/);
  assert.match(swimmer, /BUOYANCY_RESPONSE/);
  assert.match(swimmer, /r5_swim_burst/);
  assert.match(swimmer, /r5_dive_burst/);
  assert.doesNotMatch(swimmer, /jump_velocity\s*=/);
});

test('currents and whirlpools are reusable non-blocking water forces', () => {
  assert.match(current, /class_name WildCurrentVolume/);
  assert.match(current, /direction: Vector3/);
  assert.match(current, /strength: float/);
  assert.match(current, /width: float/);
  assert.match(current, /length: float/);
  assert.match(current, /current_type: StringName/);
  assert.match(current, /collision_layer = 0/);
  assert.match(whirlpool, /class_name WildWhirlpoolVolume/);
  assert.match(whirlpool, /sample_force/);
  assert.doesNotMatch(whirlpool, /reset_motion|record_finish|complete_round/);
});

test('Phase 1 six-checkpoint foundation remains authored beneath the longer Phase 3 course', () => {
  assert.match(mode, /func _build_checkpoint_positions\(\) -> Array\[Vector3\]/);
  const checkpointBlock = mode.match(/func _build_checkpoint_positions[\s\S]*?func _build_water_world/)[0];
  assert.equal((checkpointBlock.match(/Vector3\(/g) || []).length, 6);
  assert.match(phase3, /LONG_FINISH_Z/);
  assert.match(phase3, /target_track=1\.3km/);
  assert.match(mode, /RaceManager\.can_finish\(racer\)/);
  assert.match(mode, /r5_finish_enter/);
  assert.match(mode, /r5_finish_clear/);
  assert.match(mode, /r5_recovery[\s\S]*dive_false_positive=false/);
});

test('vertical slice contains the original six swimming zones and hazards', () => {
  for (const zone of [
    'BLUE LAGOON',
    'CURRENT CROSSING',
    'FLOATING FOREST',
    'WHIRLPOOL CANYON',
    'RAPIDS RUN',
    'OPEN WATER SPRINT',
  ]) assert.match(mode, new RegExp(zone));
  assert.match(mode, /FloatingLogA/);
  assert.match(mode, /RiverRockA/);
  assert.match(mode, /ReedsWest/);
  assert.match(mode, /WhirlpoolWest/);
});

test('AI uses the same swim driver and can burst/dive without teleport progression', () => {
  assert.match(mode, /_attach_swimmer\(racer, false, lane\)/);
  assert.match(swimmer, /_process_ai_swim/);
  assert.match(swimmer, /_try_swim_burst\(\)/);
  assert.match(swimmer, /should_ai_dive/);
  assert.doesNotMatch(swimmer, /RaceManager\.record_checkpoint/);
  assert.doesNotMatch(swimmer, /RaceManager\.record_finish/);
});

test('direct Round 5 finish is testable and ends at Final Result', () => {
  assert.match(mode, /_promote_direct_round5_to_campaign_final/);
  assert.match(mode, /GameManager\.current_round_index = DIRECT_ROUND5_INDEX/);
  assert.match(manager, /get_tree\(\)\.change_scene_to_file\("res:\/\/scenes\/result\.tscn"\)/);
});
