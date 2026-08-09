import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const page = readFileSync("app/page.tsx", "utf8");
const race = readFileSync("app/Race3D.tsx", "utf8");
const tutorial = readFileSync("app/Tutorial.tsx", "utf8");

test("UI copy describes the current local AI race accurately", () => {
  for (const outdated of [
    "50-PLAYER PARTY ROYALE",
    "3D GRAND PRIX",
    "3D 그랑프리 출전!",
    "쇼츠로 뽐내기",
    "효과음과 간단한 배경 리듬",
    "모바일 진동",
    "큰 터치 버튼",
  ]) {
    assert.equal(page.includes(outdated), false, `outdated UI copy remains: ${outdated}`);
  }

  assert.equal(page.includes("50-RACER LOCAL AI RACE"), true);
  assert.equal(page.includes("WILD GRAND PRIX"), true);
  assert.equal(page.includes("결과 공유하기"), true);
  assert.equal(page.includes("점프·충돌·스킬 효과음"), true);
});

test("pseudo-3D and Windows tutorial copy avoid misleading platform claims", () => {
  assert.equal(race.includes('aria-label="위에서 내려다보는 3D 파티 동물 레이싱 경기장"'), false);
  assert.equal(race.includes("원근 연출 파티 동물 레이싱 경기장"), true);
  assert.equal(tutorial.includes("모바일은"), false);
  assert.equal(tutorial.includes("W/S 또는 방향키로 이동해요."), true);
});
