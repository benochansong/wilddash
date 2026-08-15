# Animal Ability Profile Integration

Canonical six-stat source: `WildDashAnimalAbilityProfile`.

- Terrain adapter reads Swim / Climb / Agility / Power / Rough from the canonical profile.
- Combat adapter reads Power as base attack identity and Defense from the same canonical profile.
- Character Select presentation reads all six values from the canonical profile.
- Base movement (`max_speed`, `acceleration`, `turn_speed`, `jump_velocity`, `arena_move_speed`) remains independently tuned.
