# WILD DASH 3D — Chimera System V1

## Goal

Chimera is a separate composition layer on top of the four base animals. The base animal system stays intact.

A chimera has three gameplay slots:

- **Head** — passive trait
- **Body** — movement, collision, durability and camera profile
- **Tail** — active skill

Cosmetic options are independent from gameplay:

- Palette: `classic`, `sunset`, `ocean`, `forest`
- Pattern: `stripe`, `spots`, `split`, `plain`

## Example

`Rabbit Head + Elephant Body + Cat Tail`

- Head passive: Rabbit `Long-Ear Sense` — Fruit Collection interaction radius +20%
- Body: Elephant movement, collision capsule, knockback decay and camera
- Tail: Cat `그림자 회피` active skill and 9 second cooldown

## Head passives

| Head | Passive | Effect |
|---|---|---|
| Dog | Trail Sense | Better speed retention after blocking collisions |
| Rabbit | Long-Ear Sense | Fruit/interaction radius +20% |
| Elephant | Thick Skull | Incoming knockback -25% |
| Cat | Quick Reflex | Turning response +12% |

## Body inheritance

The body reads the existing `WildDashAnimalDefinition` and supplies:

- max/cruise speed
- acceleration
- turn speed
- jump velocity and gravity
- arena movement
- knockback decay
- collision radius/height/center
- chase camera profile

This avoids duplicating balance data.

## Tail skill inheritance

The tail uses the selected animal's existing skill definition:

- Dog — 균형 질주
- Rabbit — 도약 추진
- Elephant — 코 방어
- Cat — 그림자 회피

The active skill cooldown and multipliers come directly from the tail animal definition.

## Runtime structure

```text
CharacterRoot
├─ CharacterController
├─ CollisionShape3D       <- Body definition
└─ VisualSlot
   └─ ChimeraVisual
      └─ ImportedModel
         ├─ Skeleton3D
         ├─ HeadSlot
         ├─ BodySlot
         ├─ TailSlot
         ├─ PatternSlot
         └─ AnimationPlayer
```

`CharacterController` receives a `WildDashChimeraLoadout`. It does not know individual mesh node paths.

Production GLB parts can later replace the generated low-poly placeholder parts without changing gameplay rules.

## Preview Lab

Open:

`res://chimera/chimera_preview.tscn`

Controls:

- `1 / 2` — previous/next Head
- `3 / 4` — previous/next Body
- `5 / 6` — previous/next Tail
- `C` — cycle palette
- `P` — cycle pattern
- `Enter` — save loadout and enable it for the next campaign in the current session

The preview loads the last saved chimera when opened.

## Save format

Godot Save System is now version 2 and adds:

```json
"chimera": {
  "head": "dog",
  "body": "rabbit",
  "tail": "elephant",
  "palette": "classic",
  "pattern": "stripe"
}
```

Older v1 saves migrate with a safe default chimera loadout.

## Current visual status

The visual system currently generates low-poly placeholder Head/Body/Tail parts. This validates composition, silhouette and gameplay wiring only.

The next art step is to author modular Blender/Maya parts with a shared attachment/skeleton contract, then replace only `ChimeraVisual`'s placeholder part construction.

## Test gate

`res://tests/chimera_system_smoke.tscn` validates:

- serialization round trip
- Head passive inheritance
- Body movement/collision inheritance
- Tail skill/cooldown inheritance
- modular visual slot existence
- Save v2 chimera payload
- GameManager chimera selection

The existing four-animal, 4-AI, 10-AI and 10/25/50 racer tests remain required.
