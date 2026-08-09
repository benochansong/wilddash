extends Node

signal settings_changed(settings: Dictionary)

const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
]
const FPS_OPTIONS: Array[int] = [30, 60, 120, 0]

var settings: Dictionary = {}

func _ready() -> void:
	settings = SaveManager.get_settings()
	var controls: Dictionary = settings.get("controls", {})
	var keyboard: Dictionary = controls.get("keyboard", {})
	InputManager.apply_keyboard_bindings(keyboard)
	apply_graphics()

func get_audio_settings() -> Dictionary:
	return (settings.get("audio", {}) as Dictionary).duplicate(true)

func get_graphics_settings() -> Dictionary:
	return (settings.get("graphics", {}) as Dictionary).duplicate(true)

func is_reduced_motion() -> bool:
	var accessibility: Dictionary = settings.get("accessibility", {})
	return bool(accessibility.get("reduced_motion", false))

func is_high_contrast() -> bool:
	var accessibility: Dictionary = settings.get("accessibility", {})
	return bool(accessibility.get("high_contrast", false))

func set_master_volume(value: float) -> void:
	_set_audio_value("master_volume", clampf(value, 0.0, 1.0))

func set_music_volume(value: float) -> void:
	_set_audio_value("music_volume", clampf(value, 0.0, 1.0))

func set_sfx_volume(value: float) -> void:
	_set_audio_value("sfx_volume", clampf(value, 0.0, 1.0))

func set_muted(value: bool) -> void:
	_set_audio_value("muted", value)

func set_resolution(size: Vector2i) -> void:
	var graphics: Dictionary = settings.get("graphics", {})
	graphics["width"] = clampi(size.x, 1024, 7680)
	graphics["height"] = clampi(size.y, 700, 4320)
	settings["graphics"] = graphics
	_commit(true)

func set_fullscreen(value: bool) -> void:
	var graphics: Dictionary = settings.get("graphics", {})
	graphics["fullscreen"] = value
	settings["graphics"] = graphics
	_commit(true)

func set_fps_limit(value: int) -> void:
	var graphics: Dictionary = settings.get("graphics", {})
	graphics["fps_limit"] = value if value in FPS_OPTIONS else 60
	settings["graphics"] = graphics
	_commit(true)

func set_reduced_motion(value: bool) -> void:
	_set_accessibility_value("reduced_motion", value)

func set_high_contrast(value: bool) -> void:
	_set_accessibility_value("high_contrast", value)

func rebind_keyboard(action: StringName, keycode: int) -> bool:
	if not InputManager.rebind_keyboard(action, keycode):
		return false
	var controls: Dictionary = settings.get("controls", {})
	controls["keyboard"] = InputManager.export_keyboard_bindings()
	settings["controls"] = controls
	_commit(false)
	return true

func apply_graphics() -> void:
	var graphics: Dictionary = settings.get("graphics", {})
	var fps_limit := int(graphics.get("fps_limit", 60))
	Engine.max_fps = fps_limit
	if DisplayServer.get_name() == "headless":
		return
	var fullscreen := bool(graphics.get("fullscreen", false))
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	if not fullscreen:
		var width := int(graphics.get("width", 1600))
		var height := int(graphics.get("height", 900))
		DisplayServer.window_set_size(Vector2i(width, height))

func get_background_color() -> Color:
	return Color(0.0, 0.0, 0.0, 1.0) if is_high_contrast() else Color(0.04, 0.06, 0.1, 1.0)

func get_accent_color() -> Color:
	return Color(1.0, 1.0, 0.0, 1.0) if is_high_contrast() else Color(0.22, 0.86, 0.62, 1.0)

func _set_audio_value(key: String, value: Variant) -> void:
	var audio: Dictionary = settings.get("audio", {})
	audio[key] = value
	settings["audio"] = audio
	_commit(false)
	var audio_manager := get_node_or_null("/root/AudioManager")
	if audio_manager != null:
		audio_manager.call("apply_settings", audio)

func _set_accessibility_value(key: String, value: bool) -> void:
	var accessibility: Dictionary = settings.get("accessibility", {})
	accessibility[key] = value
	settings["accessibility"] = accessibility
	_commit(false)

func _commit(apply_graphics_now: bool) -> void:
	SaveManager.update_settings(settings)
	if apply_graphics_now:
		apply_graphics()
	settings_changed.emit(settings.duplicate(true))
