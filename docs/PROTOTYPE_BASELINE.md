# WILD DASH 50 — Prototype Baseline

이 문서는 대규모 리팩터링 전에 현재 동작 상태를 보존하기 위한 기준 문서입니다.

## Baseline

- Source repository: `benochansong/wilddash`
- Source branch: `agent/import-wild-dash-project`
- Source commit: `fdeeaa6e07273fe1df0014810a55c6de6277cdeb`
- Stabilization branch: `stabilization/wilddash-prototype`
- Pull request: `#1 Import WILD DASH 50 project`
- PR state at baseline: Open / Draft / Not merged
- Target: Windows desktop, offline single-player game
- Runtime: React + TypeScript + Vite + Electron
- Rendering: Browser Canvas 2D with pseudo-3D projection for the main race

## Current project structure

### Core gameplay / UI

- `app/page.tsx` — top-level screen flow, profile/settings state, legacy race logic, game progression
- `app/Race3D.tsx` — current main Canvas pseudo-3D race, player + AI racers, obstacles, items, ranking
- `app/ArenaRound.tsx` — fruit, survival, final arena modes
- `app/Tutorial.tsx` — tutorial flow
- `app/globals.css` — current UI/game styling

### Runtime / desktop shell

- `src/main.tsx` — React application entry point
- `electron/main.cjs` — Electron Windows desktop shell
- `index.html` — Vite HTML entry
- `vite.config.ts` — Vite build configuration
- `package.json` / `package-lock.json` — dependencies, scripts, Electron builder configuration

### Assets / tests

- `public/` — application icons and current static assets
- `tests/desktop-build.test.mjs` — verifies offline desktop build shell artifacts

### Suspected template / legacy leftovers

These files are present in the baseline but should not be deleted until import/reference checks are completed:

- `worker/`
- `db/`
- `drizzle/`
- `drizzle.config.ts`
- `examples/d1/`
- `next.config.ts`
- `build/sites-vite-plugin.ts`

## Major current game features

### Core flow

- Lobby
- Tutorial
- Chimera lab / cosmetic part selection
- Base animal selection
- Countdown
- Main race
- Round break
- Fruit round
- Survival round
- Final push-out arena
- Result screen
- Return to lobby

### Playable animals

- Dog
- Rabbit
- Elephant
- Cat

Each animal currently has a distinct gameplay skill/cooldown concept.

### Round 1 — Wild World Grand Prix

- Canvas-based pseudo-3D course rendering
- Player-controlled racer
- Up to 49 AI racers in the current Race3D implementation
- Obstacles
- Item boxes
- Banana hazards
- Jumping
- Animal skills
- AI interference
- Position/rank calculation
- Multiple visual course sections
- Finish result

### Round 2 — Fruit Collection

- Fruit collection objective
- AI rivals
- Timed success/failure condition

### Round 3 — Floor Collapse Survival

- Collapsing tile logic
- Hearts/lives
- Timed survival objective

### Final — Push-Out Arena

- Push/shove interaction
- AI rivals
- Ring-out success/failure condition

### Progress / settings

- Fans
- Wins
- Best rank
- Local progression storage
- Tutorial completion storage
- Sound setting
- Haptics setting
- Reduced motion
- High contrast
- Large touch setting
- Windows installer configuration

## Known stabilization risks

### 1. Legacy/template code mixed with game code

Cloudflare/Drizzle/Next.js-related files exist beside the actual Vite/Electron game. These should be verified and removed only after dependency/import checks.

### 2. ESLint configuration mismatch

`eslint.config.mjs` imports `eslint-config-next`, while the package is not listed in the current dependencies. The project itself is Vite/React, not Next.js. This should be replaced by a React + TypeScript + Vite ESLint setup.

### 3. Input handling duplication

Keyboard listeners are registered in multiple game components. Centralizing input into a single InputManager is recommended to avoid duplicate Space/E/Q actions and make future gamepad support easier.

### 4. AudioContext lifecycle

Current effects can construct new `AudioContext` instances repeatedly. Audio should eventually be centralized behind one AudioManager.

### 5. Large mixed-responsibility components

`app/page.tsx` and `app/Race3D.tsx` contain configuration, gameplay, state, input, audio, AI and UI responsibilities. They should be split gradually, without changing gameplay behavior during stabilization.

### 6. Test coverage is currently shallow

Current automated testing mainly verifies built offline shell artifacts. Gameplay rule tests, save migration tests and CI checks are not yet present.

### 7. Product wording can overstate current implementation

The current product is local single-player with AI racers, not online 50-player multiplayer. The main race uses Canvas pseudo-3D rather than a dedicated 3D engine. UI terminology should later be aligned with the actual implementation.

## Files safe to inspect/change during stabilization

These are candidates for cleanup or configuration work, after confirming references:

- `.gitignore`
- `eslint.config.mjs`
- `tsconfig.json`
- `vite.config.ts`
- `package.json`
- `worker/`
- `db/`
- `drizzle/`
- `drizzle.config.ts`
- `examples/d1/`
- `next.config.ts`
- `build/sites-vite-plugin.ts`

These are candidates for later structural refactoring, but must preserve behavior:

- `app/page.tsx`
- `app/Race3D.tsx`
- `app/ArenaRound.tsx`
- `app/globals.css`

## Files that must be preserved during early stabilization

Do not delete or rewrite wholesale without an explicit migration/replacement plan:

- `app/page.tsx`
- `app/Race3D.tsx`
- `app/ArenaRound.tsx`
- `app/Tutorial.tsx`
- `app/globals.css`
- `src/main.tsx`
- `electron/main.cjs`
- `index.html`
- `vite.config.ts`
- `tsconfig.json`
- `package.json`
- `package-lock.json`
- `tests/desktop-build.test.mjs`
- `public/app-icon.png`

The gameplay behavior embedded in `page.tsx`, `Race3D.tsx` and `ArenaRound.tsx` should also be treated as a design reference even if the project later migrates to a dedicated 3D engine.

## Stabilization rules

1. Do not merge PR #1 into `main` during stabilization.
2. Perform cleanup/refactoring on `stabilization/wilddash-prototype` or a child branch.
3. Prefer small, reversible commits.
4. Preserve current playable flow before adding major features.
5. Before deleting suspected legacy files, verify imports/references.
6. After each code cleanup step, run build/test/lint when available.
7. Do not introduce a new game engine during the cleanup phase.
8. Keep this baseline commit available as the restoration point.

## Recommended next step

Verify whether the suspected template/legacy files are referenced anywhere in the actual Vite/Electron runtime. Remove only confirmed-unused Next.js / Cloudflare / Drizzle leftovers, then run build and tests. No gameplay feature work should be mixed into that cleanup commit.
