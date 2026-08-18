import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(path, 'utf8');

const feedback = read('godot/effects/racer_feedback_controller.gd');
const motion = read('godot/characters/character_motion_polish.gd');
const camera = read('godot/camera/chase_camera.gd');
const cameraCue = read('godot/camera/player_camera_cue.gd');
const roundVfx = read('godot/effects/round_vfx_director.gd');
const roundVfxSafeLoader = read('godot/effects/round_vfx_safe_loader.gd');
const hud = read('godot/ui/mode_hud.gd');
const recap = read('godot/ui/round_recap_motion_polish.gd');
const audio = read('godot/scripts/audio_manager.gd');
const racerScene = read('godot/characters/test_racer.tscn');
const gameManager = read('godot/scripts/game_manager.gd');

const roundScenes = {
  grand_prix: read('godot/modes/grand_prix/grand_prix.tscn'),
  fruit_frenzy: read('godot/modes/fruit_collection/fruit_collection.tscn'),
  logspire: read('godot/modes/logspire_leap/logspire_leap.tscn'),
  wild_rumble: read('godot/modes/push_out/push_out.tscn'),
  neon_harbor: read('godot/modes/neon_harbor_race/neon_harbor_race.tscn'),
};

test('racer feedback uses fixed pool and distance VFX LOD', () => {
  assert.match(feedback, /FX_POOL_SIZE := 10/);
  assert.match(feedback, /PLAYER_STRENGTH := 1\.0/);
  assert.match(feedback, /NEAR_RIVAL_STRENGTH := 0\.68/);
  assert.match(feedback, /FAR_RIVAL_STRENGTH := 0\.28/);
  assert.match(feedback, /notify_swimming/);
  assert.match(feedback, /notify_item_pickup/);
  assert.match(feedback, /notify_body_check/);
  assert.match(feedback, /_boost_trails/);
  assert.doesNotMatch(feedback, /StaticBody3D\.new/);
  assert.doesNotMatch(feedback, /CollisionShape3D\.new/);
});

test('visual motion polish never writes racer gameplay movement', () => {
  assert.match(motion, /VisualSlot/);
  assert.match(motion, /PremiumCharacterArt/);
  assert.match(motion, /_species_motion_profile/);
  assert.match(motion, /_landing_pulse/);
  assert.match(motion, /_takeoff_pulse/);
  assert.doesNotMatch(motion, /_racer\.velocity\s*=/);
  assert.doesNotMatch(motion, /_racer\.current_speed\s*=/);
  assert.doesNotMatch(motion, /jump_velocity\s*=/);
  assert.doesNotMatch(motion, /move_and_slide\(/);
  assert.doesNotMatch(motion, /move_and_collide\(/);
});

test('camera game feel is restrained and existing obstruction system remains', () => {
  assert.match(camera, /impulse_max_offset := 0\.24/);
  assert.match(camera, /add_game_feel_impulse/);
  assert.match(camera, /request_finish_pullback/);
  assert.match(camera, /request_target_focus/);
  assert.match(camera, /_resolve_obstructed_position/);
  assert.match(camera, /_resolve_forward_visibility/);
  assert.match(cameraCue, /get_progress_percent/);
  assert.match(cameraCue, /94\.0/);
  assert.doesNotMatch(cameraCue, /velocity\s*=/);
});

test('HUD is styled and reuses nodes while rank and item feedback animate', () => {
  assert.match(hud, /StyleBoxFlat\.new/);
  assert.match(hud, /corner_radius_top_left = 20/);
  assert.match(hud, /show_rank_change/);
  assert.match(hud, /play_item_pop/);
  assert.match(hud, /create_tween/);
  const processBody = hud.split('func _process')[1]?.split('func configure')[0] ?? '';
  assert.doesNotMatch(processBody, /\.new\(\)/, 'HUD process must not allocate UI nodes every frame');
});

test('Phase 3 safe loader remains on production rounds except campaign-safe Logspire', () => {
  for (const [profile, scene] of Object.entries(roundScenes)) {
    if (profile === 'logspire') continue;
    assert.match(scene, /GraphicsPhase2WorldArt/);
    assert.match(scene, /GraphicsPhase3RoundVFX/);
    assert.match(scene, /round_vfx_safe_loader\.gd/);
    assert.doesNotMatch(scene, /ext_resource[^\n]*round_vfx_director\.gd/);
    assert.ok(scene.includes(`round_profile = "${profile}"`), `${profile} profile missing`);
  }
  assert.doesNotMatch(roundScenes.logspire, /GraphicsPhase3RoundVFX/);
  assert.match(roundScenes.logspire, /P0 CAMPAIGN-SAFE ROUND 3/);
  assert.match(roundVfxSafeLoader, /call_deferred\("_attach_optional_director"\)/);
  assert.match(roundVfxSafeLoader, /ResourceLoader\.load\(DIRECTOR_PATH/);
  assert.match(roundVfxSafeLoader, /gameplay_continues=true/);
  assert.match(roundVfx, /START_PRESENTATION_SECONDS := 1\.45/);
  assert.match(roundVfx, /WORLD_POOL_SIZE := 12/);
  assert.match(roundVfx, /FINAL FESTIVAL/);
  assert.match(roundVfx, /firework/);
  assert.match(roundVfx, /confetti/);
  assert.doesNotMatch(roundVfx, /StaticBody3D\.new/);
  assert.doesNotMatch(roundVfx, /CollisionShape3D\.new/);
});

test('character select campaign start recovers stale run state and loads Round 1 deferred', () => {
  assert.match(gameManager, /if campaign_running:/);
  assert.match(gameManager, /state != GameState\.CHARACTER_SELECT/);
  assert.match(gameManager, /CAMPAIGN START RECOVERY stale_campaign=true/);
  assert.match(gameManager, /current_round_index = 0/);
  assert.match(gameManager, /call_deferred\("_load_current_round"\)/);
  assert.match(gameManager, /change_scene_to_file\(scene_path\)/);
});

test('common racer scene attaches only visual feedback layers around unchanged capsule', () => {
  assert.match(racerScene, /RacerFeedback/);
  assert.match(racerScene, /CharacterMotionPolish/);
  assert.match(racerScene, /PlayerCameraCue/);
  assert.match(racerScene, /radius = 0\.62/);
  assert.match(racerScene, /height = 1\.9/);
});

test('surface and signature action SFX remain inside shared AudioManager pool', () => {
  for (const id of ['foot_grass', 'foot_dirt', 'foot_wood', 'foot_sand', 'foot_water', 'foot_metal', 'landing', 'boost', 'item_gold', 'recovery']) {
    assert.ok(audio.includes(`_sfx_library["${id}"]`), `missing ${id}`);
  }
  assert.match(audio, /SFX_POOL_SIZE := 8/);
});

test('round recap adds pooled broadcast motion without replacing recap scoring flow', () => {
  assert.match(recap, /CONFETTI_COUNT := 18/);
  assert.match(recap, /play_result\(true\)/);
  assert.match(recap, /EXPRESSION_VICTORY/);
  assert.match(recap, /PanelContainer/);
  assert.doesNotMatch(recap, /advance_from_round_recap/);
});
