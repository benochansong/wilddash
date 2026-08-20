# RC9 Graphics Phase 3 — Game Feel and Cinematic Feedback

## Goal

Graphics Phase 3 does not add character polygons or redesign gameplay. It makes existing movement and actions answer the player immediately through reusable VFX, additive visual animation, restrained camera cues, UI motion and pooled audio feedback.

Graphics Phase 1 lighting, material and color rules remain authoritative. Graphics Phase 2 premium character art and four-depth environment art remain installed and unchanged in purpose.

## Safety contract

This phase does not change:

- Character movement physics
- Collision capsule dimensions
- Global jump power
- AI balance
- Platform layout or gaps
- Round difficulty
- Recovery ownership or recovery route rules
- Combat power or knockback balance

The common feedback layer reads racer state. It does not write racer velocity or speed.

## Racer feedback

`effects/racer_feedback_controller.gd` is attached to the shared racer scene.

It provides:

- Surface-aware run puffs and footstep audio hooks for grass, dirt, wood, sand, water and metal
- Jump takeoff accent
- Landing puff and ring with stronger response only for hard landings
- Boost foot trails, glow and signature audio accent
- Hit impact pulse and camera request
- Item pickup glow and HUD pop
- Golden item color and sound variant
- Water entry splash, foam-like ring and swim wake
- Stronger Crocodile wake
- Recovery exit accent
- Finish pulse and finish camera request
- Rank-change HUD request for the local player

Effects use ten recycled mesh slots per racer. No temporary particle node is created for each footstep.

## VFX distance LOD

The feedback strength contract is:

- Local player: 1.00
- Nearby rival: 0.68
- Far racer: 0.28

Surface sampling is throttled, and far AI keeps the lowest visual budget.

## Character motion polish

`characters/character_motion_polish.gd` animates only `VisualSlot` and `PremiumCharacterArt`.

It adds:

- Species-weighted run bounce
- Forward body lean
- Jump takeoff stretch
- Midair stretch
- Landing squash
- Hit compression
- Victory bounce

Rabbit and Monkey are springier. Elephant, Bear and Boar are heavier. Crocodile stays low and restrained. Fox, Cat and Deer feel lighter and quicker.

The CharacterBody transform and collision capsule are never scaled or rotated by this layer.

## Camera

The existing ChaseCamera remains authoritative for obstruction and forward visibility.

Graphics Phase 3 adds:

- Maximum 0.24 m positional impulse
- Fast exponential impulse decay
- Small jump lift request
- Landing impulse
- Body-check directional impulse
- Final-approach target focus after roughly 94 percent race progress
- Finish pullback up to 3.8 m

No rotational shake is added, reducing motion-sickness risk. Existing speed-based FOV and speed lines remain owned by `RacingFeelController`.

## HUD

`ModeHUD` now uses rounded dark glass-like panels with cyan and amber accent borders while preserving readable metrics.

Motion feedback includes:

- Rank-change pop, with stronger treatment for overtakes
- Item pickup icon pop
- Ready-state boost accent
- Reused Tween instances rather than per-frame node creation

## Round start presentation

Each Graphics Phase 3 round director creates a 1.45 second non-blocking establishing card during the existing pre-race presentation window.

The card shows:

- Round name
- Round visual theme and landmark cue
- Player racer when available
- Quick 3 2 1 GO language

It does not lock input or add a new gameplay countdown.

## Round-specific VFX identity

### Round 1 — Wild World Grand Prix

Warm dust, leaf-colored action accents and water-blue splash response support the Sunny Safari direction.

### Round 2 — Fruit Frenzy

Coral fruit burst, green juice-like accents and gold item flashes reinforce the Tropical Festival.

### Round 3 — Logspire Leap

Leaf green, mushroom and moss tones combine with water splash and wake feedback. The existing swim helper sends a visual-only heartbeat to the common feedback system; Crocodile keeps its full-speed water gameplay identity.

### Round 4 — Wild Rumble

Warm orange impact rings and champion-gold accents reinforce body checks, hits and arena spectacle.

### Round 5 — Neon Harbor

Cyan and magenta boost and electric accents culminate in a short Final Festival presentation with pooled fireworks, confetti and winner banner after the local player finishes.

## Round recap

The existing recap timing, score count-up, highlights and navigation remain owned by `round_recap.gd`.

`round_recap_motion_polish.gd` adds a broadcast-style layer:

- Panel entrance transition
- Theme-colored pooled confetti
- Existing score count-up preserved
- Preview racer victory animation
- Premium victory facial expression
- Existing background motion preserved

## Audio

All new feedback stays in the existing shared `AudioManager` and its eight-player SFX pool.

Added procedural placeholders:

- Six surface footsteps
- Landing
- Boost
- Golden item
- Recovery

Only the local racer requests repeated footstep audio, preventing a crowded race from becoming noisy.

## Performance intent

- Ten pooled local mesh effect slots per racer
- Twelve pooled round-global effect slots
- Player, near and far strength tiers
- Surface ray sampling is throttled
- No per-frame HUD node allocation
- No new gameplay collision
- R5 fireworks run only for a short finale window
- Phase 2 MultiMesh and visibility-range environment structure remains intact

## Manual Godot 4.7.1 validation

Static CI cannot prove visual quality or GDScript runtime behavior. Before PR readiness, manually verify:

1. All new scripts parse in Godot 4.7.1.
2. 15 to 18 racers remain readable and stable.
3. Surface puffs do not obscure feet or track edges.
4. Landing impulse is comfortable after repeated jumps.
5. Boost trails stay behind the racer and do not cover the camera.
6. Rank and item pop animations do not cover critical route information.
7. Round start overlay does not delay control.
8. Logspire splash and Crocodile wake are visually correct.
9. Wild Rumble impact feedback remains readable during dense combat.
10. Neon Harbor finale fireworks do not overwhelm the finish line.
11. Recap transitions and confetti remain smooth.
12. Compare FPS before and after Phase 3 in dense race and arena scenes.
