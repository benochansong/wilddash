class_name WildDashItemDefinition
extends Resource

@export var item_id: StringName = &""
@export var display_name := "ITEM"
@export var role: StringName = &"utility"
@export var icon_text := "?"
@export var status_label := "ITEM"
@export var front_weight := 10.0
@export var mid_weight := 10.0
@export var back_weight := 10.0
@export var duration := 0.0
@export var strength := 1.0
@export var secondary_strength := 1.0

func configure(
	id: StringName,
	name: String,
	item_role: StringName,
	icon: String,
	status: String,
	front: float,
	mid: float,
	back: float,
	item_duration := 0.0,
	primary_strength := 1.0,
	secondary := 1.0,
) -> WildDashItemDefinition:
	item_id = id
	display_name = name
	role = item_role
	icon_text = icon
	status_label = status
	front_weight = front
	mid_weight = mid
	back_weight = back
	duration = item_duration
	strength = primary_strength
	secondary_strength = secondary
	return self

func weight_for_band(band: StringName) -> float:
	match band:
		&"front":
			return front_weight
		&"back":
			return back_weight
		_:
			return mid_weight
