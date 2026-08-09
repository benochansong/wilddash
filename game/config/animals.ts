import type { Animal, AnimalKey } from "../types/game";

export const ANIMALS: Record<AnimalKey, Animal> = {
  dog: { name: "멍대시", emoji: "🐶", label: "안정적인 러너", skill: "전력 질주", description: "2.5초 동안 속도 +18%", color: "#ff8a4c", cooldown: 10 },
  rabbit: { name: "깡총이", emoji: "🐰", label: "지형 돌파형", skill: "도약 추진", description: "높이 뛰며 앞으로 80m 도약", color: "#ff66ad", cooldown: 7 },
  elephant: { name: "코뿜이", emoji: "🐘", label: "탱커 · 방해형", skill: "코 휘두르기", description: "근접 경쟁자를 밀치고 1회 방어", color: "#6d7cff", cooldown: 9 },
  cat: { name: "냥쏘", emoji: "🐱", label: "교란 · 회피형", skill: "하악질", description: "2.2초 충돌 회피 + 주변 경직", color: "#b565f5", cooldown: 8 },
};

export const CHIMERA_HEADS = ["🐶", "🐰", "🐊", "🦊", "🐱", "🐘"] as const;
export const CHIMERA_BODIES = ["🟠", "🟣", "🟢", "🔵", "🟡", "🔴"] as const;
export const CHIMERA_TAILS = ["〰️", "⚡", "🌈", "🪶", "🍤", "🎀"] as const;
export const PART_UNLOCKS = [0, 0, 0, 300, 800, 1500] as const;

export const RACE3D_SKILLS: Record<AnimalKey, { name: string; cooldown: number }> = {
  dog: { name: "균형 질주 +10%", cooldown: 12 },
  rabbit: { name: "도약 추진", cooldown: 8 },
  elephant: { name: "코 방어", cooldown: 10 },
  cat: { name: "그림자 회피", cooldown: 9 },
};
