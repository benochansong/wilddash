# RC8 — 12 Playable Racers Balance Pass

RC8 turns the complete twelve-species race roster into a player-selectable roster while keeping the existing four proven skill engines. The goal is not twelve unrelated systems; it is twelve readable playstyles that stay inside one shared balance envelope across the five-round campaign.

## Core rule

- All 12 animals are selectable in Basic Racer mode.
- Chimera remains limited to Dog / Rabbit / Elephant / Cat for this milestone.
- The four runtime skill IDs remain `rally_dash`, `spring_leap`, `stampede`, and `shadow_step`.
- Each animal gets its own movement profile, collision profile, arena profile, skill name, cooldown and skill multipliers.
- No character should be best at race speed, handling, arena mobility and knockback at the same time.

## Target roster

| Animal | Role | Max | Accel | Handling | Jump | Arena | Radius | Skill variant |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| Dog | Balanced Runner | 14.5 | 24.0 | 2.15 | 7.5 | 9.5 | 0.62 | Rally Dash |
| Wolf | Speed Hunter | 14.8 | 23.0 | 2.02 | 7.3 | 9.3 | 0.60 | Hunting Rush |
| Boar | Tough Sprinter | 14.1 | 22.5 | 1.95 | 6.9 | 9.1 | 0.70 | Tusk Charge |
| Rabbit | Jump Specialist | 13.9 | 25.5 | 2.40 | 9.3 | 10.0 | 0.52 | Spring Leap |
| Deer | Graceful Racer | 14.4 | 24.2 | 2.48 | 8.6 | 9.8 | 0.55 | Bounding Stride |
| Monkey | Agile Collector | 13.8 | 27.2 | 2.55 | 8.4 | 10.6 | 0.50 | Vine Vault |
| Elephant | Heavy Tank | 13.2 | 20.0 | 1.72 | 6.2 | 8.4 | 0.80 | Stampede |
| Bear | Heavy All-Rounder | 13.6 | 21.5 | 1.80 | 6.5 | 8.8 | 0.77 | Bear Rush |
| Panda | Stable Heavy | 13.4 | 23.0 | 1.95 | 6.7 | 9.0 | 0.75 | Bamboo Bump |
| Cat | Precision Racer | 14.0 | 26.0 | 2.65 | 7.7 | 10.1 | 0.50 | Shadow Step |
| Fox | Burst Racer | 14.6 | 24.5 | 2.35 | 7.6 | 9.8 | 0.53 | Fox Feint |
| Raccoon | Agile Utility | 13.9 | 27.5 | 2.58 | 8.0 | 10.5 | 0.49 | Scamper Step |

## Intended strengths by mode

- Grand Prix: Wolf / Dog / Fox have strong straight-line or balanced pressure.
- Fruit Collection: Monkey / Raccoon / Cat gain value from arena acceleration and handling.
- Neon Harbor: Cat / Deer / Fox favor precision and burst through technical sections.
- Push Out: Elephant / Bear / Boar gain value from body size, knockback recovery and collision retention.
- Snowpeak: Dog / Panda / Deer are intended as forgiving stable choices rather than raw specialists.

These are design targets, not guaranteed tier placements. Manual five-round playtests are required.

## Validation gates before RC8 can replace RC7

1. All 12 buttons fit at 1600×900 and each preview loads correctly.
2. Each animal can start all five rounds without fallback to Dog.
3. Last-selected animal persists after restarting the game.
4. Run at least three campaign samples per animal on Chaos difficulty.
5. No animal should exceed the field-average campaign score by more than ~8% over repeated clean runs.
6. Cat/Fox/Raccoon must not dominate both racing and arena rounds.
7. Elephant/Bear/Panda must remain viable in races while retaining clear Push-Out value.
8. Tunnel containment must be retested with the smallest (Raccoon) and largest (Elephant) collision radii.

RC8 remains experimental until these gates pass.
