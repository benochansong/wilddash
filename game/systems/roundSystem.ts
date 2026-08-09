export type RoundMode = "fruit" | "survival" | "final";

export function isFruitRoundSuccess(score: number): boolean {
  return score >= 8;
}

export function isSurvivalRoundFailure(hearts: number): boolean {
  return hearts <= 0;
}

export function isFinalPlayerEliminated(playerRadius: number): boolean {
  return playerRadius > 48;
}

export function isFinalRoundSuccess(rivalsRemaining: number): boolean {
  return rivalsRemaining <= 0;
}

export function resolveRoundTimeout(
  mode: RoundMode,
  score: number,
  hearts: number,
  rivalsRemaining: number,
): { success: boolean; score: number } {
  return {
    success: mode === "survival" || (mode === "final" && isFinalRoundSuccess(rivalsRemaining)),
    score: mode === "fruit" ? score : hearts,
  };
}
