import type { ItemKey } from "../types/game";

const COMEBACK_POOL = ["shield", "magnet", "ink", "magnet"] as const;
const STANDARD_POOL = ["banana", "shield", "ink", "magnet"] as const;

export function selectRace3DItem(rivalsAhead: number, boxIndex: number): Exclude<ItemKey, null> {
  const pool = rivalsAhead > 30 ? COMEBACK_POOL : STANDARD_POOL;
  const index = Math.abs(Math.trunc(boxIndex)) % pool.length;
  return pool[index];
}

export function consumeItem(item: ItemKey): Exclude<ItemKey, null> | null {
  return item ?? null;
}
