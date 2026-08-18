extends "res://modes/grand_prix/grand_prix_mode.gd"

## P0 boot-safe Grand Prix fallback.
## Used only when the full production Round 1 scene cannot be loaded from
## Character Select. Core race setup remains owned by grand_prix_mode.gd.

func _ready() -> void:
	await super()
	if player == null or not is_instance_valid(player):
		push_error("P0 GRAND PRIX FALLBACK player missing after base setup")
		return

	if GameManager.chimera_enabled:
		player.configure_chimera(GameManager.get_chimera_loadout())
	else:
		player.configure_animal(GameManager.selected_animal)

	print("P0 GRAND PRIX FALLBACK READY animal=%s chimera=%s ai=%d core_only=true" % [
		String(GameManager.selected_animal),
		str(GameManager.chimera_enabled),
		GameManager.ai_count,
	])
