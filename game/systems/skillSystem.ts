export function tickCooldown(cooldown: number, deltaSeconds: number): number {
  if (!Number.isFinite(cooldown) || cooldown <= 0) return 0;
  if (!Number.isFinite(deltaSeconds) || deltaSeconds <= 0) return cooldown;
  return Math.max(0, cooldown - deltaSeconds);
}

export function canUseSkill(cooldown: number): boolean {
  return Number.isFinite(cooldown) && cooldown <= 0;
}

export function startCooldown(seconds: number): number {
  return Number.isFinite(seconds) && seconds > 0 ? seconds : 0;
}
