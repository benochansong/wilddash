import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";

const localization = fs.readFileSync("godot/ui/character_select_localization.gd", "utf8");
const adapter = fs.readFileSync("godot/scenes/character_select_crocodile.gd", "utf8");
const panel = fs.readFileSync("godot/ui/animal_stats_panel_localized.gd", "utf8");
const scene = fs.readFileSync("godot/scenes/character_select.tscn", "utf8");

const activeRacers = [
  "dog", "wolf", "boar", "rabbit", "deer", "monkey",
  "elephant", "bear", "crocodile", "cat", "fox", "raccoon",
];

test("production character select follows the lobby en ko es locale", () => {
  assert.match(scene, /character_select_crocodile\.gd/);
  assert.match(adapter, /character_select_localization\.gd/);
  assert.match(adapter, /animal_stats_panel_localized\.gd/);
  assert.match(adapter, /_localize_static_ui\(\)/);
  assert.match(adapter, /_localize_dynamic_ui\(\)/);
  assert.match(adapter, /LOCALIZATION\.text\("difficulty_wild"\)/);
  assert.match(adapter, /LOCALIZATION\.animal_name/);

  for (const locale of ['&"en"', '&"ko"', '&"es"']) {
    assert.ok(localization.includes(locale), `missing locale ${locale}`);
  }

  assert.ok(localization.includes('WILD DASH — CHOOSE YOUR RACER'));
  assert.ok(localization.includes('WILD DASH — 레이서 선택'));
  assert.ok(localization.includes('WILD DASH — ELIGE TU CORREDOR'));
  assert.ok(localization.includes('"context_normal": "ABILITY + COMBAT PROFILE"'));
  assert.ok(localization.includes('"context_normal": "능력 + 전투 프로필"'));
  assert.ok(localization.includes('"context_normal": "PERFIL DE HABILIDAD + COMBATE"'));
});

test("all 12 production racers have localized presentation entries", () => {
  for (const animalId of activeRacers) {
    assert.ok(localization.includes(`&"${animalId}": {`), `missing localized racer ${animalId}`);
  }
  assert.ok(localization.includes('"name": "Elephant"'));
  assert.ok(localization.includes('"name": "코끼리"'));
  assert.ok(localization.includes('"name": "Elefante"'));
});

test("right-hand stat card localizes labels descriptions and playstyle while retaining canonical numeric stats", () => {
  assert.match(panel, /extends "res:\/\/ui\/animal_stats_panel\.gd"/);
  assert.match(panel, /LOCALIZATION\.stat_label/);
  assert.match(panel, /LOCALIZATION\.skill_description/);
  assert.match(panel, /LOCALIZATION\.playstyle/);
  assert.match(panel, /WildDashAnimalSelectionPresentation\.get_strengths/);
  assert.match(panel, /WildDashAnimalSelectionPresentation\.get_weaknesses/);
});
