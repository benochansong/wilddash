import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const lobby = readFileSync("godot/scenes/lobby.gd", "utf8");
const settings = readFileSync("godot/scripts/settings_manager.gd", "utf8");

test("lobby exposes English Korean and Spanish selectors", () => {
  for (const code of ["en", "ko", "es"]) {
    assert.match(lobby, new RegExp(`\\{\\"code\\": &\\"${code}\\"`));
  }
  assert.match(lobby, /"label": "English"/);
  assert.match(lobby, /"label": "한국어"/);
  assert.match(lobby, /"label": "Español"/);
});

test("all lobby-facing copy is expanded for the three languages", () => {
  for (const marker of [
    "SINGLE PLAYER",
    "싱글 플레이",
    "UN JUGADOR",
    "MULTIPLAYER · LAN PROTOTYPE",
    "멀티플레이 · LAN 프로토타입",
    "MULTIJUGADOR · PROTOTIPO LAN",
    "SETTINGS",
    "설정",
    "AJUSTES",
    "QUIT",
    "게임 종료",
    "SALIR",
  ]) {
    assert.ok(lobby.includes(marker), `missing localized lobby copy: ${marker}`);
  }
  assert.match(lobby, /RC_LOBBY_LANGUAGE_REFRESH/);
});

test("selected lobby language persists and feeds Godot locale", () => {
  assert.match(settings, /SUPPORTED_LANGUAGES: Array\[StringName\] = \[&"en", &"ko", &"es"\]/);
  assert.match(settings, /records\["language"\] = String\(language\)/);
  assert.match(settings, /SaveManager\.save_current\(\)/);
  assert.match(settings, /TranslationServer\.set_locale\(String\(language\)\)/);
  assert.match(lobby, /SettingsManager\.set_language\(code\)/);
  assert.match(lobby, /_refresh_ui\(\)/);
});
