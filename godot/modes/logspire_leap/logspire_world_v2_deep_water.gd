extends "res://modes/logspire_leap/logspire_world.gd"

## Deep-water geometry adapter for the Canopy River.
## The original recovery decks sat only about 1.25m below the water surface,
## which let CharacterBody racers touch the floor and look like they were walking.
## Lowering only the basin floor/recovery decks keeps the authored platform route
## unchanged while giving every water zone a true 3.2m+ swimming depth.

func _ready() -> void:
	super()
	_deepen_canopy_riverbed()

func _deepen_canopy_riverbed() -> void:
	_shift_node_y("FOREST_FLOOR", -3.30)
	_shift_recovery_pair("Recovery_Z2", -2.00)
	_shift_recovery_pair("Recovery_Z3", -2.00)
	_shift_recovery_pair("Recovery_Z4", -2.00)
	_shift_recovery_pair("Recovery_Z5", -2.00)
	_shift_recovery_pair("Recovery_Z6", -2.00)
	print("LOGSPIRE DEEP WATER READY min_depth=3.25m zone1_depth=3.45m recovery_areas_below_surface=true")

func _shift_recovery_pair(area_name: String, delta_y: float) -> void:
	_shift_node_y(area_name + "_Deck", delta_y)
	_shift_node_y(area_name, delta_y)

func _shift_node_y(node_name: String, delta_y: float) -> void:
	var node := get_node_or_null(node_name) as Node3D
	if node == null:
		push_warning("LOGSPIRE DEEP WATER missing node=%s" % node_name)
		return
	node.position.y += delta_y
