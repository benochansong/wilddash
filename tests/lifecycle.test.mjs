import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import test from "node:test";

const page = readFileSync("app/page.tsx", "utf8");
const race = readFileSync("app/Race3D.tsx", "utf8");
const arena = readFileSync("app/ArenaRound.tsx", "utf8");
const tutorial = readFileSync("app/Tutorial.tsx", "utf8");
const reactSources = [page, race, arena, tutorial];

test("animation frames and timers have lifecycle cleanup", () => {
  assert.match(race, /cancelAnimationFrame\(frame\)/);
  assert.match(arena, /cancelAnimationFrame\(frame\)/);
  assert.match(page, /clearTimeout\(t\)/);
  assert.match(tutorial, /clearTimeout/);

  for (const source of reactSources) {
    assert.doesNotMatch(source, /setInterval\s*\(/, "Prototype V1 should not leave interval loops running");
  }
});

test("React screens delegate global keyboard listeners to InputManager", () => {
  for (const source of reactSources) {
    assert.doesNotMatch(source, /addEventListener\s*\(\s*["']key(?:down|up)["']/);
    assert.doesNotMatch(source, /removeEventListener\s*\(\s*["']key(?:down|up)["']/);
  }
});
