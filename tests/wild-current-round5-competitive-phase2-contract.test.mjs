import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

const scene = read('godot/modes/wild_current/wild_current.tscn');
const phase1 = read('godot/modes/wild_current/wild_current_race.gd');
const phase2 = read('godot/modes/wild_current/wild_current_race_phase2.gd');
const swimmer2 = read('godot/modes/wild_current/wild_current_swimmer_phase2.gd');
const manager = read('godot/scripts/game_manager_rc9_round5_wild_current.gd');

test('production Round 5 now layers competitive Phase 2 over the Phase 1 swim foundation', () => {
  assert.match(scene, /res:\/\/modes\/wild_current\/wild_current_race_phase2\.gd/);
  assert.match(phase2, /extends "res:\/\/modes\/wild_current\/wild_current_race\.gd"/);
  assert.match(swimmer2, /extends "res:\/\/modes\/wild_current\/wild_current_swimmer\.gd"/);
  assert.match(phase1, /ContinuousWaterSurface/);
  assert.match(phase1, /racer\.set_physics_process\(false\)/);
});

test('15-racer target is split into lead, mid and back packs without teleport or raw pack speed cheats', () => {
  assert.match(phase2, /_pack_role_for_ai_slot/);
  assert.match(phase2, /_pack_counts_for_ai_total/);
  assert.match(phase2, /r5_ai_lead_pack/);
  assert.match(phase2, /r5_ai_mid_pack/);
  assert.match(phase2, /r5_ai_back_pack/);
  assert.match(phase2, /speed_cheat=false teleport=false/);
  assert.match(phase2, /for racers_count in \[10, 15, 18\]/);
  assert.doesNotMatch(swimmer2, /pack_role[\s\S]{0,120}max_swim_speed\s*\*=/);
  assert.doesNotMatch(swimmer2, /RaceManager\.record_checkpoint|RaceManager\.record_finish/);
});

test('AI skill is multidimensional rather than a single speed multiplier', () => {
  for (const field of [
    'steering_accuracy',
    'current_selection',
    'burst_timing',
    'dive_timing',
    'obstacle_avoidance',
    'whirlpool_avoidance',
    'racing_line_quality',
  ]) assert.match(swimmer2, new RegExp(field));
  assert.match(phase2, /should_ai_burst_phase2/);
  assert.match(phase2, /should_ai_dive_for_profile/);
  assert.match(swimmer2, /r5_ai_route_reacquire[\s\S]*teleport=false/);
});

test('wake drafting is a short shared player-and-AI physics benefit', () => {
  assert.match(phase2, /func sample_wake_draft/);
  assert.match(phase2, /DRAFT_MIN_GAP: float = 1\.6/);
  assert.match(phase2, /DRAFT_MAX_GAP: float = 9\.5/);
  assert.match(phase2, /DRAFT_MAX_LATERAL: float = 3\.1/);
  assert.match(swimmer2, /sample_wake_draft/);
  assert.match(swimmer2, /r5_draft_enter/);
  assert.match(swimmer2, /r5_draft_exit/);
  assert.match(swimmer2, /MAX_DRAFT_SPEED_BONUS: float = 0\.62/);
});

test('every water section exposes strategic SAFE, FAST or RISK line logic', () => {
  assert.match(phase2, /safe_fast_risk=true/);
  assert.match(phase2, /&"SAFE"/);
  assert.match(phase2, /&"FAST"/);
  assert.match(phase2, /&"RISK"/);
  for (const current of [
    'LagoonFastRight',
    'CrossingSafeRight',
    'ForestSafeLeft',
    'WhirlpoolOuterWest',
    'WhirlpoolOuterEast',
    'RapidsSafeLeft',
    'FinalFastCenter',
  ]) assert.match(phase2, new RegExp(current));
  assert.match(swimmer2, /r5_ai_current_choice/);
});

test('Floating Forest uses moving simple-box logs with a dive-under route and no climb dependency', () => {
  assert.match(phase2, /AnimatableBody3D\.new\(\)/);
  assert.match(phase2, /BoxMesh\.new\(\)/);
  assert.match(phase2, /BoxShape3D\.new\(\)/);
  assert.match(phase2, /moving_logs=.*dive_under=true climb_required=false/);
  assert.match(phase2, /ForestDebrisA/);
  const logBlock = phase2.match(/func _add_floating_log[\s\S]*?func _build_finish_gate/)[0];
  assert.doesNotMatch(logBlock, /CylinderShape3D|CylinderMesh|CSGCylinder3D/);
});

test('Whirlpool Canyon is a recoverable risk-reward line used according to AI skill', () => {
  assert.match(phase2, /WhirlpoolOuterWest/);
  assert.match(phase2, /WhirlpoolOuterEast/);
  assert.match(phase2, /r5_ai_whirlpool_avoid/);
  assert.match(phase2, /edge_reward=/);
  assert.match(swimmer2, /r5_whirlpool_enter/);
  assert.match(swimmer2, /r5_whirlpool_escape/);
});

test('animal swim personalities stay small and do not create a universal optimal animal', () => {
  assert.match(swimmer2, /&"bear"[\s\S]*_momentum_scale = 1\.06[\s\S]*_turn_personality_scale = 0\.94/);
  assert.match(swimmer2, /&"rabbit"[\s\S]*_momentum_scale = 0\.97[\s\S]*_turn_personality_scale = 1\.06/);
  assert.match(swimmer2, /&"elephant"[\s\S]*_lateral_current_scale = 0\.94/);
  assert.match(swimmer2, /&"monkey"[\s\S]*_dive_recharge_scale = 0\.94/);
  assert.match(swimmer2, /&"cat"[\s\S]*_turn_personality_scale = 1\.07/);
});

test('final sprint is readable and decided by burst, draft, current and steering', () => {
  assert.match(phase2, /FINAL_SPRINT_Z/);
  assert.match(phase2, /FinalSightBeacon/);
  assert.match(phase2, /sight_seconds=8_12/);
  assert.match(phase2, /FINAL CURRENT · BURST \+ DRAFT \+ STEERING/);
  assert.match(phase2, /r5_final_sprint_enter/);
  assert.match(phase2, /r5_finish_pack_count/);
});

test('Round 5 game feel and audio reuse shared systems with no new audio context', () => {
  assert.match(phase2, /WakeTrail/);
  assert.match(phase2, /SurfaceSplash/);
  assert.match(phase2, /GPUParticles3D\.new\(\)/);
  assert.match(phase2, /_update_round5_camera/);
  assert.match(phase2, /get_node_or_null\("\/root\/AudioManager"\)/);
  assert.match(phase2, /play_sfx_id/);
  for (const hook of ['swim_stroke', 'swim_burst', 'dive', 'splash', 'current_fast', 'whirlpool', 'checkpoint', 'final_sprint', 'finish']) {
    assert.match(phase2 + swimmer2, new RegExp(hook));
  }
  assert.doesNotMatch(phase2 + swimmer2, /AudioContext/);
});

test('Phase 2 keeps safe water recovery authority in Phase 1 and preserves campaign Final Result', () => {
  assert.doesNotMatch(swimmer2, /force_water_reset\(|global_position\s*=/);
  assert.match(phase1, /_recover_to_safe_water/);
  assert.match(phase1, /dive_false_positive=false/);
  assert.match(phase2, /round5_rebuild": "wild_current_phase2"/);
  assert.match(phase2, /competitive_swimming/);
  assert.match(manager, /r5_campaign_complete/);
  assert.match(manager, /change_scene_to_file\("res:\/\/scenes\/result\.tscn"\)/);
});
