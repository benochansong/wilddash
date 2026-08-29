class_name WildDashAnimalSelectionPresentation
extends RefCounted

## Character-select presentation adapter for the canonical six-stat profile.
## UI values now come from the same source that terrain/combat adapters consume.

const STAT_ORDER: Array[StringName] = [
	&"swim", &"climb", &"agility", &"power", &"rough", &"defense",
]

const STAT_LABELS: Dictionary = {
	&"swim": "수영",
	&"climb": "등반",
	&"agility": "민첩",
	&"power": "파워",
	&"rough": "험로",
	&"defense": "방어",
}

const STAT_COLORS: Dictionary = {
	&"swim": Color(0.22, 0.67, 1.0),
	&"climb": Color(0.35, 0.82, 0.46),
	&"agility": Color(0.96, 0.78, 0.26),
	&"power": Color(1.0, 0.39, 0.31),
	&"rough": Color(0.89, 0.57, 0.24),
	&"defense": Color(0.60, 0.50, 1.0),
}

static func get_profile(animal_id: StringName) -> Dictionary:
	return WildDashAnimalAbilityProfile.get_profile(animal_id)

static func get_identity(animal_id: StringName) -> String:
	return WildDashAnimalAbilityProfile.get_identity(animal_id)

static func get_stat_label(stat_id: StringName) -> String:
	return String(STAT_LABELS.get(stat_id, String(stat_id).capitalize()))

static func get_stat_color(stat_id: StringName) -> Color:
	var color: Color = STAT_COLORS.get(stat_id, Color(0.45, 0.78, 1.0))
	return color

static func get_strengths(animal_id: StringName, count: int = 2) -> Array[StringName]:
	return _ranked_stats(get_profile(animal_id), count, true)

static func get_weaknesses(animal_id: StringName, count: int = 2) -> Array[StringName]:
	return _ranked_stats(get_profile(animal_id), count, false)

static func format_tags(stats: Array[StringName]) -> String:
	var labels: PackedStringArray = []
	for stat_id: StringName in stats:
		labels.append(get_stat_label(stat_id))
	return " · ".join(labels)

static func get_recommended_style(animal_id: StringName) -> String:
	return WildDashAnimalAbilityProfile.get_playstyle(animal_id)

static func has_complete_profile(animal_id: StringName) -> bool:
	return WildDashAnimalAbilityProfile.has_complete_profile(animal_id)

static func _ranked_stats(profile: Dictionary, count: int, descending: bool) -> Array[StringName]:
	var remaining: Array[StringName] = STAT_ORDER.duplicate()
	var result: Array[StringName] = []
	var wanted: int = mini(maxi(count, 0), remaining.size())
	while result.size() < wanted and not remaining.is_empty():
		var chosen_index: int = 0
		var chosen_value: float = float(profile.get(String(remaining[0]), 5.0))
		for index: int in range(1, remaining.size()):
			var value: float = float(profile.get(String(remaining[index]), 5.0))
			if (descending and value > chosen_value) or (not descending and value < chosen_value):
				chosen_index = index
				chosen_value = value
		result.append(remaining[chosen_index])
		remaining.remove_at(chosen_index)
	return result
