export type MovingObstacle = {
  lateral: number;
  type: string;
  id: number;
};

export function obstacleLateral(obstacle: MovingObstacle, time: number): number {
  if (obstacle.type === "ball") return obstacle.lateral + Math.sin(time * 2.6 + obstacle.id) * 145;
  if (obstacle.type === "spinner") return obstacle.lateral + Math.sin(time * 1.5 + obstacle.id) * 35;
  return obstacle.lateral;
}

export function isRaceCollision(
  playerProgress: number,
  obstacleProgress: number,
  playerLateral: number,
  obstaclePosition: number,
  progressTolerance = 90,
  lateralTolerance = 52,
): boolean {
  return Math.abs(playerProgress - obstacleProgress) < progressTolerance
    && Math.abs(playerLateral - obstaclePosition) < lateralTolerance;
}

export function isArenaContact(
  playerX: number,
  playerY: number,
  rivalX: number,
  rivalY: number,
  threshold = 8,
): boolean {
  return Math.hypot(rivalX - playerX, rivalY - playerY) < threshold;
}
