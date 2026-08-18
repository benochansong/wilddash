import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(path, 'utf8');

const scene = read('godot/scenes/character_select.tscn');
const active = read('godot/scenes/character_select_crocodile.gd');
const base = read('godot/scenes/character_select.gd');
const manager = read('godot/scripts/game_manager.gd');

test('production character select really uses the crocodile adapter', () => {
  assert.match(scene, /character_select_crocodile\.gd/);
  assert.match(active, /extends "res:\/\/scenes\/character_select\.gd"/);
  assert.match(active, /crocodile_playable=true/);
});

test('active start button validates and loads only production Round 1', () => {
  assert.match(active, /func _start_run\(\) -> void:/);
  assert.match(active, /STARTING ROUND 1/);
  assert.match(active, /GameManager\.start_campaign\(\)/);
  assert.match(active, /func _verify_start_transition\(\) -> void:/);
  assert.match(active, /_force_checked_round1_load/);
  assert.match(active, /ResourceLoader\.exists\(ROUND1_SCENE_PATH\)/);
  assert.match(active, /ResourceLoader\.load\(ROUND1_SCENE_PATH\)/);
  assert.match(active, /change_scene_to_packed\(packed\)/);
  assert.doesNotMatch(active, /ROUND1_FALLBACK|_load_round1_fallback|grand_prix_start_fallback/);
});

test('start failure cannot remain silent and retry stays available', () => {
  assert.match(active, /func _start_failed\(message: String\) -> void:/);
  assert.match(active, /START ERROR/);
  assert.match(active, /_start_button\.disabled = false/);
  assert.match(active, /_start_button\.text = "RETRY START"/);
});

test('emergency fallback files are removed from the production branch', () => {
  assert.equal(fs.existsSync('godot/modes/grand_prix/grand_prix_start_fallback.tscn'), false);
  assert.equal(fs.existsSync('godot/modes/grand_prix/grand_prix_start_fallback.gd'), false);
});

test('base start wiring and canonical GameManager campaign path remain intact', () => {
  assert.match(base, /_start_button\.pressed\.connect\(_start_run\)/);
  assert.match(manager, /func start_campaign\(\) -> void:/);
  assert.match(manager, /call_deferred\("_load_current_round"\)/);
});
