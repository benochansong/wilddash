extends Node

const GRAND_PRIX: PackedScene = preload("res://modes/grand_prix/grand_prix.tscn")
const NEON_HARBOR: PackedScene = preload("res://modes/neon_harbor_race/neon_harbor_race.tscn")
const BOMB_SCRIPT: Script = preload("res://items/acorn_bomb.gd")
const R1_ITEM_LAYER: Script = preload("res://items/item_combat_expansion_v3_long_bomb.gd")
const R3_ITEM_LAYER: Script = preload("res://items/item_combat_expansion_long_bomb.gd")

func _ready() -> void:
	var failures: Array[String] = []
	if GRAND_PRIX == null:
		failures.append("Grand Prix failed to preload")
	if NEON_HARBOR == null:
		failures.append("Neon Harbor failed to preload")
	if BOMB_SCRIPT == null or R1_ITEM_LAYER == null or R3_ITEM_LAYER == null:
		failures.append("Long bomb scripts failed to preload")
	if WildDashLongBombItemSupport.TARGET_DISTANCE < 80.0:
		failures.append("Long bomb target distance must stay catch-up capable")
	if WildDashLongBombItemSupport.BACK_THIRD_INJECT_CHANCE < 0.20:
		failures.append("Back-third yellow-box catch-up chance is too low")
	if failures.is_empty():
		print("LONG BOMB CATCHUP SMOKE PASS r1=true r3=true target_range=%.0f back_third_chance=%.2f" % [
			WildDashLongBombItemSupport.TARGET_DISTANCE,
			WildDashLongBombItemSupport.BACK_THIRD_INJECT_CHANCE,
		])
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("LONG BOMB CATCHUP SMOKE FAIL: %s" % failure)
	get_tree().quit(1)
