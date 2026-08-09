# WILD DASH 3D — Vertical Slice 01 Analysis

This file is generated as a design/verification target for the first four-racer gameplay slice.

## Success gate

The slice is considered structurally ready when:

- Godot 4.7.1 imports all GDScript/scene resources without error.
- Main scene boots with exactly four racers: Dog + Rabbit + Elephant + Cat.
- Race start is gated until the countdown delay completes.
- Player and AI use CharacterBody3D collision.
- FinishLine Area3D records finish order exactly once per racer.
- Player rank updates from live track progress and locks after finish.
- Headless 60 Hz simulation reports both PLAYER FINISH and RACE COMPLETE.

## What CI can prove

- script/resource validity
- scene wiring
- 4-racer simulation completes
- finish trigger/ranking lifecycle works
- AI can traverse the temporary obstacle course without permanently stalling in the tested deterministic run

## What CI cannot prove

- subjective control feel
- camera comfort / motion sickness
- rendered Windows GPU FPS
- whether obstacle spacing is fun
- whether AI contact feels fair

These require manual Windows playtests before expanding the scope.
