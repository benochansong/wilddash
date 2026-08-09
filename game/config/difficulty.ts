import type { DifficultyConfig, DifficultyKey } from "../types/game";

export const DIFFICULTIES: Record<DifficultyKey, DifficultyConfig> = {
  wild: { name: "야생", tag: "치열한 몸싸움", aiSpeed: 1, aggression: .72, collision: .85, count: 16 },
  chaos: { name: "난장판", tag: "추천 · 적극적인 방해", aiSpeed: 1.08, aggression: 1, collision: 1.05, count: 19 },
  nightmare: { name: "생존지옥", tag: "고수용 · 자비 없음", aiSpeed: 1.16, aggression: 1.28, collision: 1.25, count: 22 },
};
