import { DIFFICULTIES } from "../config/difficulty";
import {
  BOXES,
  OBSTACLES,
  RACE3D_CRUISE_SPEED,
  RACE3D_SECTIONS,
} from "../config/race";
import type { DifficultyKey, ItemKey } from "../types/game";
import { createLegacyRaceAi, createRace3DAi, seeded } from "./aiSystem";

export function createRace(difficulty: DifficultyKey) {
  const config = DIFFICULTIES[difficulty];
  const variant = Math.floor(Math.random() * 3);

  return {
    x: 0,
    y: 176,
    z: 0,
    vz: 0,
    speed: 0,
    time: 0,
    item: null as ItemKey,
    cooldown: 0,
    boost: 0,
    boostPower: 0,
    shield: 0,
    hit: 0,
    confused: 0,
    collisionLock: 0,
    variant,
    flash: "",
    crossed: new Set<number>(),
    bumps: 0,
    bananas: [] as { x: number; y: number; owner: "ai" | "player"; life: number }[],
    course: OBSTACLES.map((obstacle, index) => ({
      ...obstacle,
      x: obstacle.x + (variant - 1) * (index % 3) * 42,
      lane: (obstacle.lane + variant + (index % 2)) % 3,
    })),
    boxes: BOXES.map((x, index) => x + (variant - 1) * (45 + index * 12)),
    ai: createLegacyRaceAi(difficulty),
    config,
  };
}

export function createRace3DState(seed: number) {
  return {
    s: 0,
    lateral: 0,
    speed: RACE3D_CRUISE_SPEED,
    jump: 0,
    vJump: 0,
    time: 0,
    skillCd: 5,
    boost: 0,
    shield: 0,
    phase: 0,
    hit: 0,
    bumps: 0,
    item: null as ItemKey,
    flash: "출발 보호 · 스킬 5초 잠금",
    finished: false,
    crossed: new Set<number>(),
    ai: createRace3DAi(seed),
    obstacles: Array.from({ length: 116 }, (_, i) => ({
      id: i,
      s: 900 + Math.floor(i / 4) * 790 + seeded(i, seed) * 120,
      lateral: ((i * 3 + Math.floor(seeded(i + 30, seed) * 3)) % 7 - 3) * 90,
      type: ["log", "spinner", "mud", "ball", "ramp"][Math.floor(seeded(i + 90, seed) * 5)],
    })),
    boxes: Array.from({ length: 30 }, (_, i) => ({
      id: i,
      s: 1050 + Math.floor(i / 3) * 2300 + seeded(i + 4, seed) * 150,
      lateral: ((i * 2) % 7 - 3) * 90,
      taken: false,
    })),
    bananas: [] as { s: number; lateral: number; life: number; owner: "player" | "ai" }[],
  };
}

export function trackCenter(progress: number): number {
  return Math.sin(progress / 1600) * 175
    + Math.sin(progress / 4100) * 250
    + (progress > 13600 ? Math.sin((progress - 13600) / 700) * 70 : 0);
}

export function trackElevation(progress: number): number {
  return Math.sin(progress / 1950) * 42
    + (progress > 4900 && progress < 8700 ? Math.sin((progress - 4900) / 3800 * Math.PI) * 150 : 0)
    + (progress > 9950 && progress < 13400 ? Math.sin((progress - 9950) / 3450 * Math.PI) * -90 : 0)
    + (progress > 16100 && progress < 19600 ? Math.sin((progress - 16100) / 3500 * Math.PI) * 110 : 0);
}

export function sectionFor(progress: number) {
  return [...RACE3D_SECTIONS].reverse().find((section) => progress >= section.at) ?? RACE3D_SECTIONS[0];
}
