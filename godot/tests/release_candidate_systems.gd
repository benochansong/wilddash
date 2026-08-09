extends Node

func _ready() -> void:
	await get_tree().process_frame
	_assert(int(SaveManager.current_data.get("version", 0)) == SaveManager.SAVE_VERSION, "save version")
	_assert(InputMap.has_action(&"jump"), "jump action")
	_assert(InputMap.has_action(&"pause"), "pause action")
	_assert(_has_gamepad_event(&"jump"), "jump gamepad mapping")
	_assert(_has_gamepad_event(&"pause"), "pause gamepad mapping")
	_assert(AudioServer.get_bus_index("Music") >= 0, "music audio bus")
	_assert(AudioServer.get_bus_index("SFX") >= 0, "sfx audio bus")

	var original_jump := InputManager.get_keyboard_binding_text(&"jump")
	_assert(SettingsManager.rebind_keyboard(&"jump", KEY_J), "keyboard remap")
	_assert(InputManager.get_keyboard_binding_text(&"jump") == "J", "keyboard remap applied")
	_assert(SettingsManager.rebind_keyboard(&"jump", KEY_SPACE), "keyboard restore")
	_assert(InputManager.get_keyboard_binding_text(&"jump") != original_jump or original_jump == "Space", "keyboard restore applied")

	SettingsManager.set_reduced_motion(true)
	SettingsManager.set_high_contrast(true)
	SettingsManager.set_fps_limit(30)
	_assert(SettingsManager.is_reduced_motion(), "reduced motion")
	_assert(SettingsManager.is_high_contrast(), "high contrast")
	_assert(Engine.max_fps == 30, "fps setting")
	SettingsManager.set_reduced_motion(false)
	SettingsManager.set_high_contrast(false)
	SettingsManager.set_fps_limit(60)

	GameManager.set_state(GameManager.GameState.RACE)
	PauseManager.pause_game()
	_assert(get_tree().paused, "pause enabled")
	PauseManager.resume_game()
	_assert(not get_tree().paused, "pause disabled")
	GameManager.set_state(GameManager.GameState.LOBBY)

	_assert(SaveManager.save_current(), "save write")
	print("RC_SYSTEMS PASS")
	get_tree().quit(0)

func _has_gamepad_event(action: StringName) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton or event is InputEventJoypadMotion:
			return true
	return false

func _assert(condition: bool, label: String) -> void:
	if condition:
		return
	push_error("RC_SYSTEMS FAIL: " + label)
	get_tree().quit(2)
