extends "res://modes/logspire_leap/logspire_ladder_system.gd"

## Adds a near-start recovery ladder so early falls do not create a 40m+ swim.
## The rest of the authored ladder network remains unchanged.

func _ladder_layout() -> Array:
	return [
		{"zone": 0, "platform": &"START"},
		{"zone": 0, "platform": &"Z1_04"},
		{"zone": 0, "platform": &"Z1_07"},
		{"zone": 1, "platform": &"Z2_03"},
		{"zone": 1, "platform": &"Z2_06"},
		{"zone": 1, "platform": &"Z2_08"},
		{"zone": 2, "platform": &"Z3_02"},
		{"zone": 2, "platform": &"Z3_05"},
		{"zone": 2, "platform": &"Z3_08"},
		{"zone": 3, "platform": &"Z4_SAFE_03"},
		{"zone": 3, "platform": &"Z4_SAFE_06"},
		{"zone": 3, "platform": &"Z4_WILD_05"},
		{"zone": 3, "platform": &"Z4_MERGE"},
		{"zone": 4, "platform": &"Z5_APPROACH_01"},
		{"zone": 4, "platform": &"Z5_SPIRAL_03"},
		{"zone": 4, "platform": &"Z5_SPIRAL_06"},
		{"zone": 4, "platform": &"Z5_SPIRAL_09"},
		{"zone": 5, "platform": &"Z6_START"},
		{"zone": 5, "platform": &"Z6_04"},
		{"zone": 5, "platform": &"Z6_07"},
	]
