export type Screen =
  | "lobby"
  | "tutorial"
  | "lab"
  | "pick"
  | "countdown"
  | "race"
  | "roundBreak"
  | "fruit"
  | "survival"
  | "final"
  | "result";

export type AnimalKey = "dog" | "rabbit" | "elephant" | "cat";
export type ItemId = "banana" | "shield" | "magnet" | "ink";
export type ItemKey = ItemId | null;
export type DifficultyKey = "wild" | "chaos" | "nightmare";

export type Animal = {
  name: string;
  emoji: string;
  label: string;
  skill: string;
  description: string;
  color: string;
  cooldown: number;
};

export type DifficultyConfig = {
  name: string;
  tag: string;
  aiSpeed: number;
  aggression: number;
  collision: number;
  count: number;
};

export type GameProfile = {
  fans: number;
  wins: number;
  best: number;
};

export type GameSettings = {
  sound: boolean;
  haptics: boolean;
  reducedMotion: boolean;
  highContrast: boolean;
  largeTouch: boolean;
};

export type RaceSnapshot = {
  x: number;
  y: number;
  z: number;
  speed: number;
  rank: number;
  time: number;
  item: ItemKey;
  cooldown: number;
  boost: number;
  shield: number;
  hit: number;
  confused: number;
  danger: number;
  bumps: number;
  flash: string;
};

export type RaceResult = {
  rank: number;
  time: number;
  bumps: number;
};
