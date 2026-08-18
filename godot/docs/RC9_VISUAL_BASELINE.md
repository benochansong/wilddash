# RC9 VISUAL BASELINE

This commit defines the stable visual recovery point for the RC9 campaign.

## Purpose

Return production rounds to the pre-Graphics-Phase-2/3 environment presentation while preserving current gameplay fixes and campaign flow.

Reference visual code state: `5d750dc05b25f5525041ab8acf3f1d1ed8a7e633`.

The branch is NOT reset to that commit. Only visual attachments introduced afterward are disabled or restored selectively.

## Production visual state

- Graphics Phase 2 procedural world art: OFF in R1-R5 production scenes.
- Graphics Phase 3 round VFX: OFF in R1-R5 production scenes.
- Graphics Phase 3 racer feedback, motion polish and player camera cue: OFF in the shared racer scene.
- Graphics Phase 3 camera impulse, target focus and finish pullback: OFF.
- Graphics Phase 3 recap motion polish: OFF.
- Existing track environment, lighting, materials, road/world dressing and camera obstruction safety: preserved.
- Premium Phase 2 character art remains enabled for comparison. It can be disabled separately after visual review if required.

## Start flow

The emergency Grand Prix fallback scene has been removed.

Character Select now loads only the production Round 1 scene. If production Round 1 cannot load, Character Select remains visible with a retryable START ERROR instead of entering a stripped fallback world.

## Gameplay systems preserved

- R2 to Round Recap to R3 transition safety
- Round Recap process-always pause guard
- Wild Moments result data and recap flow
- ResultManager campaign score authority
- Round 3 Phase A/B accessibility
- Round 3 stable Water Recovery V10
- Ladder V5 traversal paths
- Round 3 AI and collision safety
- Round 4 combat/result behavior
- Round 5 campaign flow
- racer stats, collision, AI balance and difficulty

## Manual Godot 4.7.1 validation

1. Sync this branch and restart Godot.
2. Confirm Round 1 opens the full production Grand Prix, never a fallback scene.
3. Capture one screenshot for each production round at 1600x900.
4. Confirm R2 completes, Recap advances, and R3 loads.
5. Confirm R3 water recovery and ladder traversal still work.
6. Compare desktop screenshots with the known-good laptop presentation.
7. If the same commit renders differently, compare renderer, import cache, local uncommitted assets and project settings before changing art code.

## Future visual workflow

From this baseline, improve one round and one visual category at a time. Keep a before/after screenshot and commit each accepted change independently. Do not re-enable the full Phase 2/3 stack in one step.
