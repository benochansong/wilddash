export type PrototypeScreen =
  | "lobby"
  | "tutorial"
  | "pick"
  | "countdown"
  | "race"
  | "roundBreak"
  | "fruit"
  | "survival"
  | "final"
  | "result";

export type PrototypeArenaMode = "fruit" | "survival" | "final";

export type ArenaFlowOutcome = {
  screen: "roundBreak" | "result";
  roundCleared: 0 | 2 | 3 | 4;
  failureRank: number | null;
  champion: boolean;
};

export function entryScreen(tutorialCompleted: boolean): "tutorial" | "pick" {
  return tutorialCompleted ? "pick" : "tutorial";
}

export function screenAfterRace(rank: number): "roundBreak" | "result" {
  return rank <= 25 ? "roundBreak" : "result";
}

export function roundClearedAfterRace(rank: number): 0 | 1 {
  return rank <= 25 ? 1 : 0;
}

export function nextRoundAfterBreak(roundCleared: number): "fruit" | "survival" | "final" {
  if (roundCleared === 1) return "fruit";
  if (roundCleared === 2) return "survival";
  return "final";
}

export function arenaFlowOutcome(mode: PrototypeArenaMode, success: boolean): ArenaFlowOutcome {
  if (!success) {
    return {
      screen: "result",
      roundCleared: 0,
      failureRank: mode === "fruit" ? 26 : mode === "survival" ? 11 : 2,
      champion: false,
    };
  }

  if (mode === "fruit") {
    return { screen: "roundBreak", roundCleared: 2, failureRank: null, champion: false };
  }
  if (mode === "survival") {
    return { screen: "roundBreak", roundCleared: 3, failureRank: null, champion: false };
  }
  return { screen: "result", roundCleared: 4, failureRank: null, champion: true };
}
