extends Node

const SAVE_VERSION := 2
const SAVE_PATH := "user://wild_dash_save.json"

func default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"profile": {"fans": 0, "wins": 0, "best": 50},
		"settings": {"sound": true, "reduced_motion": false, "high_contrast": false},
		"tutorial_completed": false,
		"unlocks": {"characters": []},
		"records": {},
		"chimera": WildDashChimeraSystem.default_loadout().to_dictionary(),
	}

func load_data() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return default_data()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return default_data()
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return default_data()
	return _validate_and_migrate(parsed)

func save_data(data: Dictionary) -> bool:
	var normalized := _validate_and_migrate(data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("WILD DASH: save file could not be opened for writing.")
		return false
	file.store_string(JSON.stringify(normalized, "\t"))
	return true

func save_chimera(loadout: WildDashChimeraLoadout) -> bool:
	var data := load_data()
	data.chimera = (loadout if loadout != null else WildDashChimeraSystem.default_loadout()).to_dictionary()
	return save_data(data)

func load_chimera() -> WildDashChimeraLoadout:
	return WildDashChimeraLoadout.from_dictionary(load_data().get("chimera", {}))

func reset_to_defaults() -> Dictionary:
	var data := default_data()
	save_data(data)
	return data

func _validate_and_migrate(raw: Dictionary) -> Dictionary:
	var version := _safe_int(raw.get("version", 0), 0, 0)
	if version > SAVE_VERSION:
		push_warning("WILD DASH: newer save version detected; using safe defaults in this build.")
		return default_data()

	var result := default_data()
	var profile = raw.get("profile", {})
	if typeof(profile) == TYPE_DICTIONARY:
		result.profile.fans = _safe_int(profile.get("fans", 0), 0, 0)
		result.profile.wins = _safe_int(profile.get("wins", 0), 0, 0)
		result.profile.best = _safe_int(profile.get("best", 50), 50, 1, 50)

	var settings = raw.get("settings", {})
	if typeof(settings) == TYPE_DICTIONARY:
		result.settings.sound = _safe_bool(settings.get("sound", true), true)
		result.settings.reduced_motion = _safe_bool(settings.get("reduced_motion", false), false)
		result.settings.high_contrast = _safe_bool(settings.get("high_contrast", false), false)

	result.tutorial_completed = _safe_bool(raw.get("tutorial_completed", false), false)

	var unlocks = raw.get("unlocks", {})
	if typeof(unlocks) == TYPE_DICTIONARY and typeof(unlocks.get("characters", [])) == TYPE_ARRAY:
		result.unlocks.characters = unlocks.get("characters", []).duplicate()

	var records = raw.get("records", {})
	if typeof(records) == TYPE_DICTIONARY:
		result.records = records.duplicate(true)

	var chimera = raw.get("chimera", {})
	if typeof(chimera) == TYPE_DICTIONARY:
		result.chimera = WildDashChimeraLoadout.from_dictionary(chimera).to_dictionary()

	result.version = SAVE_VERSION
	return result

func _safe_int(value, fallback: int, minimum: int, maximum := 2147483647) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	return clampi(int(value), minimum, maximum)

func _safe_bool(value, fallback: bool) -> bool:
	return value if typeof(value) == TYPE_BOOL else fallback
