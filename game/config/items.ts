import type { ItemId } from "../types/game";

export const ITEM_INFO: Record<ItemId, { emoji: string; name: string; level: string; description: string }> = {
  banana: { emoji: "🍌", name: "바나나", level: "방해 Lv.1", description: "뒤에 설치 · 짧은 미끄러짐" },
  shield: { emoji: "🐢", name: "등껍질", level: "방어 Lv.2", description: "3.5초 동안 공격 1회 방어" },
  ink: { emoji: "🦑", name: "먹물", level: "교란 Lv.2", description: "앞선 경쟁자를 1.2초 경직" },
  magnet: { emoji: "🧲", name: "자석", level: "역전 Lv.3", description: "앞으로 130m 안전 견인" },
};

export const RACE3D_ITEM_EMOJIS: Record<ItemId, string> = {
  banana: "🍌",
  shield: "🐢",
  magnet: "🧲",
  ink: "🦑",
};
