export function calculateRank(playerProgress: number, rivals: readonly { s: number }[]): number {
  return 1 + rivals.filter((rival) => rival.s > playerProgress).length;
}
