import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

const read = (path) => fs.readFileSync(path, 'utf8');

const scene = read('godot/scenes/character_select.tscn');
const active = read('godot/scenes/character_select_crocodile.gd');
const base = read('godot/scenes/character_select.gd');
const manager = read('godot/scripts/game_manager.gd');
const fallbackScene = read('godot/modes/grand_prix/grand_prix_start_fallback.tscn');
const fallbackScript = read('godot/modes/grand_prix/grand_prix_start_fallback.gd');

test('production character select really uses the crocodile adapter', () => {
  assert.match(scene, /character_select_crocodile\.gd/);
  assert.match(active, /extends "res:\/\/scenes\/character_select\.gd"/);
  assert.match(active, /crocodile_playable=true/);
});

test('active start button has a P0 transition verifier and checked scene load', () => {
  assert.match(active, /func _start_run\(\) -> void:/);
  assert.match(active, /STARTING ROUND 1/);
  assert.match(active, /GameManager\.start_campaign\(\)/);
  assert.match(active, /func _verify_start_transition\(\) -> void:/);
  assert.match(active, /await get_tree\(\)\.process_frame/);
  assert.match(active, /_force_checked_round1_load/);
  assert.match(active, /ResourceLoader\.exists\(ROUND1_SCENE_PATH\)/);
  assert.match(active, /ResourceLoader\.load\(ROUND1_SCENE_PATH\)/);
  assert.match(active, /change_scene_to_packed\(packed\)/);
});

test('start failure cannot remain silent and retry stays available', () => {
  assert.match(active, /func _start_failed\(message: String\) -> void:/);
  assert.match(active, /START ERROR/);
  assert.match(active, /_start_button\.disabled = false/);
  assert.match(active, /_start_button\.text = "RETRY START"/);
});

test('production load failure has a minimal core Grand Prix fallback', () => {
  assert.match(active, /grand_prix_start_fallback\.tscn/);
  assert.match(active, /_load_round1_fallback/);
  assert.match(fallbackScene, /grand_prix_start_fallback\.gd/);
  assert.match(fallbackScript, /extends "res:\/\/modes\/grand_prix\/grand_prix_mode\.gd"/);
  assert.match(fallbackScript, /configure_animal\(GameManager\.selected_animal\)/);
  assert.match(fallbackScript, /configure_chimera\(GameManager\.get_chimera_loadout\(\)\)/);
});

test('base start wiring and canonical GameManager campaign path remain intact', () => {
  assert.match(base, /_start_button\.pressed\.connect\(_start_run\)/);
  assert.match(manager, /func start_campaign\(\) -> void:/);
  assert.match(manager, /call_deferred\("_load_current_round"\)/);
});
