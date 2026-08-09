extends Node

const SAVE_VERSION := 2
const SAVE_PATH := "user://wild_dash_save.json"

var current_data: Dictionary = {}
var _future_version_detected := false

func _ready() -> void:
	current_data = load_data()
	if _future_version_detected:
		return
	var profile: Dictionary = current_data.get("profile", {})
	profile["launches"] = _safe_int(profile.get("launches", 0), 0, 0) + 1
	current_data["profile"] = profile
	save_current()
	print("SAVE LOADED version=%d launches=%d campaigns=%d last_character=%s" % [
		int(current_data.get("version", SAVE_VERSION)),
		int(profile.get("launches", 0)),
		int(profile.get("campaigns", 0)),
		String(profile.get("last_character", "dog")),
	])

func default_settings() -> Dictionary:
	return {
		"audio": {
			"muted": false,
			"master_volume": 0.85,
			"music_volume": 0.62,
			"sfx_volume": 0.82,
		},
		"graphics": {
			"width": 1600,
			"height": 900,
			"fullscreen": false,
			"fps_limit": 60,
		},
		"accessibility": {
			"reduced_motion": false,
			"high_contrast": false,
		},
		"controls": {
			"keyboard": {},
		},
	}

func default_data() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"profile": {
			"fans": 0,
			"wins": 0,
			"best": 50,
			"launches": 0,
			"campaigns": 0,
			"last_character": "dog",
		},
		"settings": default_settings(),
		"tutorial_completed": false,
		"unlocks": {"characters": []},
		"records": {},
	}

func load_data() -> Dictionary:
	_future_version_detected = false
	if not FileAccess.file_exists(SAVE_PATH):
		return default_data()
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return default_data()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("WILD DASH: corrupt save JSON; using defaults.")
		return default_data()
	var raw := parsed as Dictionary
	var raw_version := _safe_int(raw.get("version", 0), 0, 0)
	if raw_version > SAVE_VERSION:
		_future_version_detected = true
		push_warning("WILD DASH: newer save version detected; this build will not overwrite it.")
		return default_data()
	return _validate_and_migrate(raw)

func save_data(data: Dictionary) -> bool:
	if _future_version_detected:
		push_warning("WILD DASH: save write skipped to protect a newer save version.")
		return false
	var normalized := _validate_and_migrate(data)
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("WILD DASH: save file could not be opened for writing.")
		return false
	file.store_string(JSON.stringify(normalized, "\t"))
	current_data = normalized
	return true

func save_current() -> bool:
	return save_data(current_data)

func get_settings() -> Dictionary:
	if current_data.is_empty():
		current_data = load_data()
	var settings: Dictionary = current_data.get("settings", default_settings())
	return settings.duplicate(true)

func update_settings(settings: Dictionary) -> bool:
	if current_data.is_empty():
		current_data = load_data()
	current_data["settings"] = settings.duplicate(true)
	return save_current()

func get_last_character() -> StringName:
	if current_data.is_empty():
		current_data = load_data()
	var profile: Dictionary = current_data.get("profile", {})
	var value := String(profile.get("last_character", "dog"))
	if value not in ["dog", "rabbit", "elephant", "cat"]:
		value = "dog"
	return StringName(value)

func set_last_character(animal: StringName) -> void:
	if current_data.is_empty():
		current_data = load_data()
	var profile: Dictionary = current_data.get("profile", {})
	profile["last_character"] = String(animal)
	current_data["profile"] = profile
	save_current()

func record_campaign_result(round_results: Array, selected_animal: StringName) -> bool:
	if current_data.is_empty():
		current_data = load_data()
	var profile: Dictionary = current_data.get("profile", {})
	profile["campaigns"] = _safe_int(profile.get("campaigns", 0), 0, 0) + 1
	profile["last_character"] = String(selected_animal)
	var clears := 0
	var grand_prix_rank := 50
	for result: Variant in round_results:
		if typeof(result) != TYPE_DICTIONARY:
			continue
		var entry := result as Dictionary
		if bool(entry.get("success", false)):
			clears += 1
		if String(entry.get("mode_id", "")) == "grand_prix":
			grand_prix_rank = _safe_int(entry.get("score", 50), 50, 1, 50)
	if clears >= 4:
		profile["wins"] = _safe_int(profile.get("wins", 0), 0, 0) + 1
	profile["fans"] = _safe_int(profile.get("fans", 0), 0, 0) + clears * 100
	profile["best"] = mini(_safe_int(profile.get("best", 50), 50, 1, 50), grand_prix_rank)
	current_data["profile"] = profile
	var records: Dictionary = current_data.get("records", {})
	records["last_campaign_clears"] = clears
	records["last_grand_prix_rank"] = grand_prix_rank
	current_data["records"] = records
	var ok := save_current()
	print("SAVE CAMPAIGN clears=%d campaigns=%d best=%d ok=%s" % [
		clears, int(profile.get("campaigns", 0)), int(profile.get("best", 50)), str(ok),
	])
	return ok

func reset_to_defaults() -> Dictionary:
	_future_version_detected = false
	current_data = default_data()
	save_current()
	return current_data.duplicate(true)

func _validate_and_migrate(raw: Dictionary) -> Dictionary:
	var result := default_data()
	var raw_version := _safe_int(raw.get("version", 0), 0, 0)

	var profile_value: Variant = raw.get("profile", {})
	if typeof(profile_value) == TYPE_DICTIONARY:
		var profile := profile_value as Dictionary
		var out_profile: Dictionary = result["profile"]
		out_profile["fans"] = _safe_int(profile.get("fans", 0), 0, 0)
		out_profile["wins"] = _safe_int(profile.get("wins", 0), 0, 0)
		out_profile["best"] = _safe_int(profile.get("best", 50), 50, 1, 50)
		out_profile["launches"] = _safe_int(profile.get("launches", 0), 0, 0)
		out_profile["campaigns"] = _safe_int(profile.get("campaigns", 0), 0, 0)
		var character := String(profile.get("last_character", "dog"))
		out_profile["last_character"] = character if character in ["dog", "rabbit", "elephant", "cat"] else "dog"
		result["profile"] = out_profile

	var settings_value: Variant = raw.get("settings", {})
	if typeof(settings_value) == TYPE_DICTIONARY:
		var settings := settings_value as Dictionary
		if raw_version <= 1:
			_migrate_v1_settings(settings, result)
		else:
			result["settings"] = _validate_v2_settings(settings)

	result["tutorial_completed"] = _safe_bool(raw.get("tutorial_completed", false), false)
	var unlocks_value: Variant = raw.get("unlocks", {})
	if typeof(unlocks_value) == TYPE_DICTIONARY:
		var unlocks := unlocks_value as Dictionary
		var characters_value: Variant = unlocks.get("characters", [])
		if typeof(characters_value) == TYPE_ARRAY:
			result["unlocks"] = {"characters": (characters_value as Array).duplicate()}
	var records_value: Variant = raw.get("records", {})
	if typeof(records_value) == TYPE_DICTIONARY:
		result["records"] = (records_value as Dictionary).duplicate(true)
	result["version"] = SAVE_VERSION
	return result

func _migrate_v1_settings(legacy: Dictionary, result: Dictionary) -> void:
	var settings := default_settings()
	var audio: Dictionary = settings["audio"]
	audio["muted"] = not _safe_bool(legacy.get("sound", true), true)
	settings["audio"] = audio
	var accessibility: Dictionary = settings["accessibility"]
	accessibility["reduced_motion"] = _safe_bool(legacy.get("reduced_motion", false), false)
	accessibility["high_contrast"] = _safe_bool(legacy.get("high_contrast", false), false)
	settings["accessibility"] = accessibility
	result["settings"] = settings

func _validate_v2_settings(raw: Dictionary) -> Dictionary:
	var result := default_settings()
	var audio_value: Variant = raw.get("audio", {})
	if typeof(audio_value) == TYPE_DICTIONARY:
		var audio := audio_value as Dictionary
		var out_audio: Dictionary = result["audio"]
		out_audio["muted"] = _safe_bool(audio.get("muted", false), false)
		out_audio["master_volume"] = _safe_float(audio.get("master_volume", 0.85), 0.85, 0.0, 1.0)
		out_audio["music_volume"] = _safe_float(audio.get("music_volume", 0.62), 0.62, 0.0, 1.0)
		out_audio["sfx_volume"] = _safe_float(audio.get("sfx_volume", 0.82), 0.82, 0.0, 1.0)
		result["audio"] = out_audio
	var graphics_value: Variant = raw.get("graphics", {})
	if typeof(graphics_value) == TYPE_DICTIONARY:
		var graphics := graphics_value as Dictionary
		var out_graphics: Dictionary = result["graphics"]
		out_graphics["width"] = _safe_int(graphics.get("width", 1600), 1600, 1024, 7680)
		out_graphics["height"] = _safe_int(graphics.get("height", 900), 900, 700, 4320)
		out_graphics["fullscreen"] = _safe_bool(graphics.get("fullscreen", false), false)
		var fps := _safe_int(graphics.get("fps_limit", 60), 60, 0, 240)
		out_graphics["fps_limit"] = fps if fps in [0, 30, 60, 120, 144, 165, 240] else 60
		result["graphics"] = out_graphics
	var access_value: Variant = raw.get("accessibility", {})
	if typeof(access_value) == TYPE_DICTIONARY:
		var access := access_value as Dictionary
		var out_access: Dictionary = result["accessibility"]
		out_access["reduced_motion"] = _safe_bool(access.get("reduced_motion", false), false)
		out_access["high_contrast"] = _safe_bool(access.get("high_contrast", false), false)
		result["accessibility"] = out_access
	var controls_value: Variant = raw.get("controls", {})
	if typeof(controls_value) == TYPE_DICTIONARY:
		var controls := controls_value as Dictionary
		var keyboard_value: Variant = controls.get("keyboard", {})
		if typeof(keyboard_value) == TYPE_DICTIONARY:
			var clean_keyboard: Dictionary = {}
			for action: Variant in (keyboard_value as Dictionary).keys():
				var value: Variant = (keyboard_value as Dictionary)[action]
				if typeof(action) == TYPE_STRING and (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT):
					clean_keyboard[String(action)] = int(value)
			result["controls"] = {"keyboard": clean_keyboard}
	return result

func _safe_int(value: Variant, fallback: int, minimum: int, maximum := 2147483647) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	return clampi(int(value), minimum, maximum)

func _safe_float(value: Variant, fallback: float, minimum: float, maximum: float) -> float:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	return clampf(float(value), minimum, maximum)

func _safe_bool(value: Variant, fallback: bool) -> bool:
	return value if typeof(value) == TYPE_BOOL else fallback
