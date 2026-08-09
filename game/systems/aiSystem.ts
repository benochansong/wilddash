import { DIFFICULTIES } from "../config/difficulty";
import { AI_EMOJIS, LANES, RACE3D_AI_EMOJIS } from "../config/race";
import type { DifficultyKey } from "../types/game";

export function seeded(index: number, seed: number): number {
  const x = Math.sin(index * 9283.31 + seed * 77.1) * 43758.5453;
  return x - Math.floor(x);
}

export function createLegacyRaceAi(difficulty: DifficultyKey) {
  const config = DIFFICULTIES[difficulty];
  return Array.from({ length: config.count }, (_, i) => ({
    x: ((i % 7) - 3) * 34 - Math.floor(i / 7) * 46,
    y: LANES[i % 3],
    targetY: LANES[i % 3],
    pace: 3.15 + (i % 6) * .22,
    aggression: .55 + (i % 5) * .11,
    shoveCd: .8 + i * .1,
    itemCd: 2.8 + (i % 6) * .75,
    stun: 0,
    attacking: false,
    emoji: AI_EMOJIS[i % AI_EMOJIS.length],
  }));
}

export function createRace3DAi(seed: number) {
  return Array.from({ length: 49 }, (_, i) => ({
    s: ((i % 10) - 5) * 34 - Math.floor(i / 10) * 24,
    lateral: ((i % 7) - 3) * 86,
    speed: 1490 + seeded(i, seed) * 90,
    stun: 0,
    phase: seeded(i + 80, seed) * 6.28,
    itemCd: 6 + seeded(i + 110, seed) * 7,
    crossed: new Set<number>(),
    emoji: RACE3D_AI_EMOJIS[i % RACE3D_AI_EMOJIS.length],
  }));
}
