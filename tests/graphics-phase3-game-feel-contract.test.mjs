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
const racerScene = read('godot/characters/test_racer.tscn');
const recapScene = read('godot/scenes/round_recap.tscn');
const gameManager = read('godot/scripts/game_manager.gd');

const roundScenes = [
  read('godot/modes/grand_prix/grand_prix.tscn'),
  read('godot/modes/fruit_collection/fruit_collection.tscn'),
  read('godot/modes/logspire_leap/logspire_leap.tscn'),
  read('godot/modes/push_out/push_out.tscn'),
  read('godot/modes/neon_harbor_race/neon_harbor_race.tscn'),
];

test('Phase 3 source files stay preserved for later selective reuse', () => {
  assert.match(feedback, /FX_POOL_SIZE := 10/);
  assert.match(feedback, /PLAYER_STRENGTH := 1\.0/);
  assert.match(motion, /VisualSlot/);
  assert.match(cameraCue, /get_progress_percent/);
  assert.match(roundVfx, /WORLD_POOL_SIZE := 12/);
  assert.match(roundVfxSafeLoader, /ResourceLoader\.load\(DIRECTOR_PATH/);
});

test('shared racer keeps the same capsule while Phase 3 feedback nodes are disabled', () => {
  assert.match(racerScene, /radius = 0\.62/);
  assert.match(racerScene, /height = 1\.9/);
  assert.doesNotMatch(racerScene, /RacerFeedback/);
  assert.doesNotMatch(racerScene, /CharacterMotionPolish/);
  assert.doesNotMatch(racerScene, /PlayerCameraCue/);
});

test('production rounds do not load Phase 3 round VFX during visual baseline recovery', () => {
  for (const scene of roundScenes) {
    assert.doesNotMatch(scene, /GraphicsPhase3RoundVFX/);
    assert.doesNotMatch(scene, /round_vfx_safe_loader\.gd/);
  }
});

test('chase camera keeps obstruction safety without Phase 3 impulses or cinematic pullback', () => {
  assert.match(camera, /_resolve_obstructed_position/);
  assert.match(camera, /_resolve_forward_visibility/);
  assert.match(camera, /emergency_snap_when_occluded/);
  assert.doesNotMatch(camera, /add_game_feel_impulse/);
  assert.doesNotMatch(camera, /request_finish_pullback/);
  assert.doesNotMatch(camera, /request_target_focus/);
  assert.doesNotMatch(camera, /impulse_max_offset/);
});

test('round recap keeps transition safety while recap motion polish is disabled', () => {
  assert.match(recapScene, /process_mode = 3/);
  assert.match(recapScene, /round_recap\.gd/);
  assert.doesNotMatch(recapScene, /round_recap_motion_polish\.gd/);
  assert.doesNotMatch(recapScene, /GraphicsPhase3RecapMotion/);
});

test('campaign flow remains owned by GameManager', () => {
  assert.match(gameManager, /func start_campaign\(\) -> void:/);
  assert.match(gameManager, /func advance_from_round_recap\(\) -> void:/);
  assert.match(gameManager, /call_deferred\("_load_current_round"\)/);
});
