class_name WildDashAnimalSelectionPresentation
extends RefCounted

## Presentation adapter for the character-select A-layout.
## Terrain values come from RaceTerrainProfile and Defense comes from
## RaceCombatProfile so the lobby always reflects real gameplay tuning.

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
	var terrain: Dictionary = WildDashRaceTerrainProfile.get_profile(animal_id)
	return {
		"swim": float(terrain.get("swim", 5.0)),
		"climb": float(terrain.get("climb", 5.0)),
		"agility": float(terrain.get("agility", 5.0)),
		"power": float(terrain.get("power", 5.0)),
		"rough": float(terrain.get("rough", 5.0)),
		"defense": WildDashRaceCombatProfile.get_defense(animal_id),
	}

static func get_stat_label(stat_id: StringName) -> String:
	return String(STAT_LABELS.get(stat_id, String(stat_id).capitalize()))

static func get_stat_color(stat_id: StringName) -> Color:
	return STAT_COLORS.get(stat_id, Color(0.45, 0.78, 1.0)) as Color

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
	var profile: Dictionary = get_profile(animal_id)
	var swim: float = float(profile["swim"])
	var climb: float = float(profile["climb"])
	var agility: float = float(profile["agility"])
	var power: float = float(profile["power"])
	var defense: float = float(profile["defense"])
	var rough: float = float(profile["rough"])

	if power >= 9.0 and defense >= 8.0:
		if swim >= 8.0:
			return "몸싸움으로 길을 열고 강·험로에서 역전하는 헤비 돌파형"
		return "강한 충돌과 장애물 돌파로 순위를 빼앗는 파워형"
	if agility >= 9.5 and climb >= 9.0:
		return "산악 지름길과 장애물 사이를 빠르게 파고드는 테크니컬형"
	if swim >= 8.0:
		return "강과 수영 지름길을 적극 활용하는 워터 루트 공략형"
	if climb >= 8.5:
		return "오르막과 산악 구간에서 페이스를 유지하는 클라이머형"
	if agility >= 8.5:
		return "좁은 길·점프·장애물 회피로 시간을 줄이는 민첩형"
	if rough >= 8.5:
		return "진흙·자갈·험로에서 속도 손실을 줄이는 안정형"
	return "특정 지형에 치우치지 않고 모든 구간을 운영하는 밸런스형"

static func has_complete_profile(animal_id: StringName) -> bool:
	var profile: Dictionary = get_profile(animal_id)
	for stat_id: StringName in STAT_ORDER:
		if not profile.has(String(stat_id)):
			return false
	return true

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
