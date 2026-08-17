import { readFileSync } from 'node:fs';
import { describe, expect, it } from 'vitest';

const gapGuard = readFileSync('godot/modes/logspire_leap/logspire_jump_gap_guard.gd', 'utf8');
const scene = readFileSync('godot/modes/logspire_leap/logspire_leap.tscn', 'utf8');

function expectToken(token: string) {
  expect(gapGuard.includes(token), `missing ${token}`).toBe(true);
}

describe('Logspire Phase A safe-route accessibility', () => {
  it('keeps the Phase A guard wired before graph/gameplay initialization', () => {
    expect(scene).toContain('logspire_jump_gap_guard.gd');
    expect(scene.indexOf('[node name="JumpGapGuard"')).toBeLessThan(scene.indexOf('[node name="PlatformGraph"'));
    expect(scene.indexOf('[node name="JumpGapGuard"')).toBeLessThan(scene.indexOf('[node name="PlatformGameplay"'));
  });

  it('caps every Safe Route zone below the challenge threshold', () => {
    expectToken('ZONE1_MAX_GAP: float = 2.25');
    expectToken('ZONE2_MAX_GAP: float = 2.80');
    expectToken('ZONE3_MAX_GAP: float = 2.35');
    expectToken('ZONE4_SAFE_MAX_GAP: float = 3.00');
    expectToken('TITAN_MAX_GAP: float = 3.25');
    expectToken('FINALE_MAX_GAP: float = 3.55');
    expectToken('FINAL_JUMP_MAX_GAP: float = 4.25');
  });

  it('creates broad landing plazas and running connectors', () => {
    expectToken('PLAZA_MIN_WIDTH: float = 16.0');
    expectToken('PLAZA_MIN_LENGTH: float = 15.0');
    expectToken('LANDING_PLAZA_IDS');
    expect((gapGuard.match(/_build_flow_bridge\(/g) ?? []).length).toBeGreaterThanOrEqual(9);
    expectToken('SafeFlowBridge_');
  });

  it('keeps Wild-exclusive geometry separate from Safe Route resizing', () => {
    expectToken('_reanchor_wild_exclusive_route');
    expectToken('if _safe_ids.has(platform_id)');
    expectToken('wild_exclusive_preserved=true');
  });

  it('reports average and max surface gaps by zone', () => {
    expectToken('LOGSPIRE PHASE A GAP REPORT');
    expectToken('average=%.2fm');
    expectToken('max=%.2fm');
  });
});
