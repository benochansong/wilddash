import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(new URL(`../${path}`, import.meta.url), 'utf8');

const manager = read('godot/scripts/game_manager_rc9_round5_wild_current.gd');
const introScene = read('godot/scenes/campaign_intro.tscn');
const intro = read('godot/scenes/campaign_intro.gd');

test('manual campaign start routes through a dedicated sandbox intro and automated gates can bypass it', () => {
  assert.match(manager, /CAMPAIGN_INTRO_SCENE := "res:\/\/scenes\/campaign_intro\.tscn"/);
  assert.match(manager, /func start_campaign\(\) -> void:/);
  assert.match(manager, /WILDDASH_AUTOTEST/);
  assert.match(manager, /WILDDASH_SKIP_CAMPAIGN_INTRO/);
  assert.match(manager, /continue_campaign_after_intro/);
  assert.match(manager, /super\.start_campaign\(\)/);
});

test('intro scene is a self-contained simulation and never loads production round scenes', () => {
  assert.match(introScene, /res:\/\/scenes\/campaign_intro\.gd/);
  assert.match(intro, /sandbox=true result_writes=false/);
  assert.match(intro, /RACER_SCENE: PackedScene = preload\("res:\/\/characters\/test_racer\.tscn"\)/);
  assert.doesNotMatch(intro, /change_scene_to_file\("res:\/\/modes\//);
  assert.doesNotMatch(intro, /ResultManager\.(record|reset|award|finalize)/);
  assert.doesNotMatch(intro, /complete_round|record_checkpoint|record_finish/);
});

test('montage previews all five production concepts in short 1-2 second beats', () => {
  assert.match(intro, /const ROUND_SECONDS := 1\.48/);
  assert.match(intro, /for index in range\(5\)/);
  for (const mode of ['grand_prix', 'fruit_collection', 'logspire_leap', 'push_out', 'wild_current']) {
    assert.match(intro, new RegExp(`return "${mode}"`));
  }
  for (const builder of ['_build_grand_prix', '_build_fruit_collection', '_build_logspire', '_build_rumble', '_build_wild_current']) {
    assert.match(intro, new RegExp(`func ${builder.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\(\\) -> void:`));
  }
});

test('intro uses real racer visuals, supports skip, and keeps three lobby languages', () => {
  assert.match(intro, /WildDashCharacterController/);
  assert.match(intro, /racer\.set_physics_process\(false\)/);
  assert.match(intro, /collision_layer = 0/);
  assert.match(intro, /event\.is_action_pressed\("ui_accept"\)/);
  assert.match(intro, /KEY_SPACE/);
  assert.match(intro, /&"en"/);
  assert.match(intro, /&"ko"/);
  assert.match(intro, /&"es"/);
});

test('the five previews visibly demonstrate their distinct mechanics', () => {
  assert.match(intro, /_animate_grand_prix/);
  assert.match(intro, /Fruit_\%02d/);
  assert.match(intro, /TitanTrunk/);
  assert.match(intro, /RumbleArena/);
  assert.match(intro, /LeaderHunterPreview/);
  assert.match(intro, /_animate_wild_current/);
});
