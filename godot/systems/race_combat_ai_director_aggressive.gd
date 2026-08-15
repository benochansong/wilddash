class_name WildDashRaceCombatAIDirectorAggressive
extends "res://systems/race_combat_ai_director_safe.gd"

## RC9 party-racing aggression pass.
## Keeps the safe scalar Pack Buster cache and all anti-gang-up reservations, but
## shortens item hesitation and raises species combat willingness so Round 1/3
## show more AI-vs-AI item/body-check exchanges without replacing route driving.

func _global_offense_gap() -> float:
	match StringName(GameManager.difficulty):
		&"easy": return 1.90
		&"hard": return 1.28
		&"nightmare": return 1.15
		_: return 1.55

func _minimum_item_hold() -> float:
	match StringName(GameManager.difficulty):
		&"easy": return 0.78
		&"hard", &"nightmare": return 0.44
		_: return 0.58

func _combat_aggression(racer: WildDashCharacterController) -> float:
	if racer == null:
		return 0.50
	var base: float = super._combat_aggression(racer)
	var bonus: float = 0.08
	if racer.animal_id in [&"wolf", &"boar", &"bear", &"elephant"]:
		bonus = 0.10
	elif racer.animal_id == &"raccoon":
		bonus = 0.07
	elif racer.animal_id in [&"rabbit", &"deer"]:
		bonus = 0.04
	return clampf(base + bonus, 0.20, 0.98)

func _item_bias_for(racer: WildDashCharacterController) -> float:
	if racer == null:
		return 1.0
	var bias: float = super._item_bias_for(racer) * 1.12
	if racer.animal_id == &"raccoon":
		bias *= 1.08
	elif racer.animal_id == &"fox":
		bias *= 1.05
	return clampf(bias, 0.85, 1.48)

func _body_check_cooldown(animal_id: StringName) -> float:
	match animal_id:
		&"wolf", &"boar": return 1.18
		&"bear", &"elephant": return 1.34
		&"crocodile": return 1.38
		&"dog", &"monkey": return 1.52
		&"raccoon", &"fox": return 1.62
		&"cat", &"deer": return 1.78
		&"rabbit": return 1.92
		_: return 1.58
