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
