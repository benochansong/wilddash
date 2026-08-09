# WILD DASH 3D — Racer Scaling Benchmark

Date: 2026-08-10 (KST)
Branch: `godot/wilddash-next`
Benchmark implementation commit: `2a59f23d89ee14850a96825e6774e2de4fd6b87d`
Godot: 4.7.1 stable

## Goal

Grand Prix racer scale is tested in stages rather than enabling 50 racers immediately:

```text
10 racers
→ 25 racers
→ 50 racers
```

The dedicated benchmark uses AI-controlled racers for every slot. This is intentionally a conservative CPU stress case: the eventual 50-racer game target is 1 player + 49 AI, so AI brain cost should not be higher than this 50-AI benchmark.

The normal four-round campaign remains capped at 10 AI until rendered Windows validation is complete. The 25/50 stages currently live in `res://benchmark/race_benchmark.tscn` so performance work cannot destabilize Fruit Collection, Floor Collapse, or Push-Out.

## What is measured

Godot `Performance` monitors and custom AI timing record:

- FPS
- process time
- physics process time
- engine CPU 60 Hz frame-budget percentage
- AI update cost
- AI brain update count
- obstacle raycast count
- physics collision pairs
- draw calls
- rendered primitives/objects
- Godot static memory
- render video memory

Godot's built-in runtime monitors do not expose Windows Task Manager-style process CPU percentage or per-process GPU utilization. `scripts/benchmark-windows.ps1` therefore samples those externally on Windows and merges them with the `PERF_RESULT` line.

## Benchmark protocol

Each profile/racer-count combination uses:

- same code revision
- same test track
- same deterministic racer families/speeds
- 2 second warm-up
- 8 second measurement window
- 60 Hz physics

Profiles:

- `baseline`: original full-frequency AI path
- `optimized`: distance-based AI LOD + update-frequency reduction + animation LOD + simplified far collision handling

## GitHub Actions headless results

The GitHub hosted Ubuntu runner is useful for repeatable CPU/physics/AI comparisons, but **is not a GPU benchmark**. Headless rendering reports draw calls and video memory as zero, so those fields must be measured on a real rendered Windows run.

### Baseline

| Racers | FPS | Engine CPU budget | Physics ms | AI ms / physics tick* | AI raycasts | Memory peak |
|---:|---:|---:|---:|---:|---:|---:|
| 10 | 145.00 | 7.31% | 1.179 | 0.873 | 4,800 | 26.53 MB |
| 25 | 145.00 | 13.87% | 2.263 | 1.629 | 12,000 | 27.12 MB |
| 50 | 144.99 | 17.17% | 2.811 | 1.825 | 24,000 | 27.76 MB |

### Optimized

| Racers | FPS | Engine CPU budget | Physics ms | AI ms / physics tick* | AI raycasts | Memory peak |
|---:|---:|---:|---:|---:|---:|---:|
| 10 | 145.00 | 7.36% | 1.180 | 0.641 | 4,582 | 26.52 MB |
| 25 | 144.88 | 13.23% | 2.164 | 1.538 | 10,588 | 27.15 MB |
| 50 | 145.00 | 14.88% | 2.432 | 1.673 | 10,938 | 27.78 MB |

`* AI ms / physics tick` is derived from measured AI microseconds per call × racer count. It represents the aggregate AI controller cost of one 60 Hz physics step more clearly than render-frame sampling on a headless runner.

## Before / after comparison

| Racers | Physics | Engine CPU budget | AI cost | Brain updates | Raycasts | Memory |
|---:|---:|---:|---:|---:|---:|---:|
| 10 | +0.1% | +0.7% | **-26.6%** | -4.1% | -4.5% | ~0% |
| 25 | **-4.4%** | **-4.6%** | **-5.6%** | -10.3% | -11.8% | ~0% |
| 50 | **-13.5%** | **-13.3%** | **-8.3%** | **-41.8%** | **-54.4%** | ~0% |

The important trend is that LOD becomes more useful as crowd size grows. At 10 racers almost everyone is near the focus racer, so there is little opportunity to lower fidelity. At 50 racers, many racers enter mid/far LOD and expensive brain/raycast work drops substantially.

## What the optimization currently does

### AI LOD

Distance from the focus racer chooses three levels:

- Near: full 60 Hz brain decisions, obstacle raycast, racer crowd collision
- Mid: 30 Hz brain decisions, obstacle raycast, reduced animation update rate
- Far: 15 Hz brain decisions, no obstacle raycast, reduced animation update rate, world-only collision mask

Movement/physics integration is still performed every physics tick so racers do not teleport or desynchronize from the track.

### Update frequency

The expensive decision layer is decoupled from movement. Far AI keeps moving every physics step but recomputes steering/stuck/avoidance decisions less often.

### Animation LOD

Visual locomotion state synchronization is reduced to every 3 updates at mid LOD and every 8 updates at far LOD. This becomes more valuable after real animated GLB characters replace the current simple capsule test visual.

### Physics layer / collision simplification

Optimized racers use a dedicated racer layer. Mid/far racers do not require full racer-to-racer collision checks and keep world/track collision.

Current collision-pair monitor results are not yet consistently lower: 25 and 50 racer runs showed higher average pair counts despite lower physics time. Therefore collision filtering is considered **partially implemented and still requires profiling**, not a completed optimization win.

## Candidates intentionally not forced yet

### Object pooling

Not yet applied to racers. Grand Prix racers are created once per race rather than continuously spawned/despawned, so pooling would add complexity before demonstrating a meaningful benefit. Pooling is more appropriate first for reusable items, effects, hazards, and particles.

### Mesh LOD

Not meaningful with the current capsule test mesh. Implement after production animal GLB assets exist, with measured triangle/draw-call targets for LOD0/LOD1/LOD2.

### Visibility culling

Godot already performs frustum culling for GeometryInstance3D. Explicit distance visibility ranges/occlusion should be tuned after the production race course and camera are stable.

## Windows rendered benchmark

Run from PowerShell with a Godot 4.7.1 Windows executable:

```powershell
.\scripts\benchmark-windows.ps1 -GodotPath "C:\Godot\Godot_v4.7.1-stable_win64.exe"
```

The script runs baseline and optimized profiles at 10, 25, and 50 racers and writes:

`godot/benchmark/windows-benchmark.csv`

Additional Windows-only columns include:

- `os_cpu_pct_avg`: process CPU percentage normalized across logical processors
- `gpu_3d_pct_avg`: PID-specific Windows GPU Engine 3D utilization when supported by the installed driver
- `working_set_mb_peak`: OS process working set

The Godot result supplies rendered draw calls, primitives, render objects, and video memory when the game is run with a real renderer rather than `--headless`.

## Current decision gate

### Passed

- 10 racer benchmark completes baseline + optimized
- 25 racer benchmark completes baseline + optimized
- 50 racer benchmark completes baseline + optimized
- 50 racer CPU/physics headless load remains well below the 16.67 ms 60 Hz physics budget on the CI runner
- existing 4 AI and 10 AI four-round campaign regression tests still pass

### Not yet claimed

We do **not** claim that a generic Windows PC is already proven stable at 50 racers. The CI runner is headless, so GPU utilization, real draw calls, shadows, animated production meshes, and driver behavior are not represented.

The production promotion gate is:

```text
10 rendered Windows racers
→ 25 rendered Windows racers
→ 50 rendered Windows racers
→ confirm FPS / CPU / GPU / physics / AI / draw calls / memory
→ only then make 50-racer Grand Prix a normal gameplay configuration
```

## Next optimization priorities

1. Run `benchmark-windows.ps1` on the target Windows PC and save the CSV.
2. Add real animal GLB models and repeat to expose animation/GPU/draw-call cost.
3. Tune collision layers again because collision-pair count did not improve consistently.
4. Add Mesh LOD and explicit visibility ranges once production meshes exist.
5. Profile shadows and material count; these are likely to dominate GPU cost before AI does.
6. Only after the 50-racer rendered test is stable, promote the campaign race cap from the current 10-AI safety limit.
