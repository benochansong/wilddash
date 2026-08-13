extends Node

const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_ACCELERATE: StringName = &"accelerate"
const ACTION_BRAKE: StringName = &"brake"
const ACTION_JUMP: StringName = &"jump"
const ACTION_SKILL: StringName = &"skill"
const ACTION_ITEM: StringName = &"item"
const ACTION_PAUSE: StringName = &"pause"

const GAME_ACTIONS: Array[StringName] = [
	ACTION_LEFT, ACTION_RIGHT, ACTION_ACCELERATE, ACTION_BRAKE,
	ACTION_JUMP, ACTION_SKILL, ACTION_ITEM, ACTION_PAUSE,
]

const DEFAULT_KEYS: Dictionary = {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"accelerate": [KEY_W, KEY_UP],
	"brake": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],
	"skill": [KEY_E],
	"item": [KEY_Q],
	"pause": [KEY_ESCAPE, KEY_P],
}

var _input_sequence := 0

func _ready() -> void:
	for action: StringName in GAME_ACTIONS:
		_ensure_action(action)
		_add_default_keyboard(action)
	_add_default_gamepad()
	# Saved single-key bindings from older builds can erase the default aliases.
	# Keep the canonical WASD/arrow driving controls available as safety aliases.
	_ensure_core_keyboard_safety_aliases()

func get_steer_axis() -> float:
	return Input.get_axis(ACTION_LEFT, ACTION_RIGHT)

func get_throttle_axis() -> float:
	var accelerate_strength := Input.get_action_strength(ACTION_ACCELERATE)
	var brake_strength := Input.get_action_strength(ACTION_BRAKE)
	# Physical-key fallback protects the core drive controls even if an old save
	# contains a stale/partial binding map. This is intentionally limited to
	# movement safety aliases; skill/item custom bindings remain user-controlled.
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		accelerate_strength = maxf(accelerate_strength, 1.0)
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		brake_strength = maxf(brake_strength, 1.0)
	return clampf(accelerate_strength - brake_strength, -1.0, 1.0)

func get_move_vector() -> Vector2:
	return Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_ACCELERATE, ACTION_BRAKE, 0.2)

func sample_racer_input_state() -> WildDashRacerInputState:
	_input_sequence += 1
	var state := WildDashRacerInputState.new()
	state.steer = get_steer_axis()
	state.throttle = get_throttle_axis()
	state.jump_pressed = consume_jump()
	state.skill_pressed = consume_skill()
	state.item_pressed = consume_item()
	state.sequence = _input_sequence
	return state

func get_input_debug_snapshot() -> Dictionary:
	return {
		"w_pressed": Input.is_physical_key_pressed(KEY_W),
		"up_pressed": Input.is_physical_key_pressed(KEY_UP),
		"accelerate_action": Input.get_action_strength(ACTION_ACCELERATE),
		"brake_action": Input.get_action_strength(ACTION_BRAKE),
		"throttle": get_throttle_axis(),
		"accelerate_binding": get_keyboard_binding_text(ACTION_ACCELERATE),
		"brake_binding": get_keyboard_binding_text(ACTION_BRAKE),
	}

func consume_jump() -> bool:
	return Input.is_action_just_pressed(ACTION_JUMP)

func consume_skill() -> bool:
	return Input.is_action_just_pressed(ACTION_SKILL)

func consume_item() -> bool:
	return Input.is_action_just_pressed(ACTION_ITEM)

func consume_pause() -> bool:
	return Input.is_action_just_pressed(ACTION_PAUSE)

func rebind_keyboard(action: StringName, physical_keycode: int) -> bool:
	if action not in GAME_ACTIONS or physical_keycode == int(KEY_NONE):
		return false
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	for event: InputEvent in events:
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var replacement := InputEventKey.new()
	replacement.physical_keycode = physical_keycode
	InputMap.action_add_event(action, replacement)
	_ensure_core_keyboard_safety_aliases()
	return true

func export_keyboard_bindings() -> Dictionary:
	var result: Dictionary = {}
	for action: StringName in GAME_ACTIONS:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key_event := event as InputEventKey
				result[String(action)] = int(key_event.physical_keycode)
				break
	return result

func apply_keyboard_bindings(bindings: Dictionary) -> void:
	for action_text: Variant in bindings.keys():
		if typeof(action_text) != TYPE_STRING:
			continue
		var action := StringName(String(action_text))
		if action not in GAME_ACTIONS:
			continue
		var raw_key: Variant = bindings[action_text]
		if typeof(raw_key) != TYPE_INT and typeof(raw_key) != TYPE_FLOAT:
			continue
		var keycode: int = int(raw_key)
		if keycode != int(KEY_NONE):
			rebind_keyboard(action, keycode)
	_ensure_core_keyboard_safety_aliases()

func get_keyboard_binding_text(action: StringName) -> String:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			return OS.get_keycode_string(key_event.physical_keycode)
	return "Unbound"

func get_gamepad_hint(action: StringName) -> String:
	match action:
		ACTION_JUMP: return "A"
		ACTION_SKILL: return "X"
		ACTION_ITEM: return "B"
		ACTION_PAUSE: return "Start"
		ACTION_LEFT, ACTION_RIGHT, ACTION_ACCELERATE, ACTION_BRAKE: return "Left Stick / D-Pad"
		_: return ""

func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	else:
		InputMap.action_set_deadzone(action, 0.2)

func _add_default_keyboard(action: StringName) -> void:
	var has_keyboard := false
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventKey:
			has_keyboard = true
			break
	if has_keyboard:
		return
	var codes: Array = DEFAULT_KEYS.get(String(action), [])
	for code: Variant in codes:
		var event := InputEventKey.new()
		event.physical_keycode = int(code)
		InputMap.action_add_event(action, event)

func _ensure_core_keyboard_safety_aliases() -> void:
	_ensure_key_event(ACTION_LEFT, KEY_A)
	_ensure_key_event(ACTION_LEFT, KEY_LEFT)
	_ensure_key_event(ACTION_RIGHT, KEY_D)
	_ensure_key_event(ACTION_RIGHT, KEY_RIGHT)
	_ensure_key_event(ACTION_ACCELERATE, KEY_W)
	_ensure_key_event(ACTION_ACCELERATE, KEY_UP)
	_ensure_key_event(ACTION_BRAKE, KEY_S)
	_ensure_key_event(ACTION_BRAKE, KEY_DOWN)

func _ensure_key_event(action: StringName, keycode: Key) -> void:
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventKey:
			var key_event := existing as InputEventKey
			if key_event.physical_keycode == keycode or key_event.keycode == keycode:
				return
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	InputMap.action_add_event(action, event)

func _add_default_gamepad() -> void:
	_add_joy_axis(ACTION_LEFT, JOY_AXIS_LEFT_X, -1.0)
	_add_joy_axis(ACTION_RIGHT, JOY_AXIS_LEFT_X, 1.0)
	_add_joy_axis(ACTION_ACCELERATE, JOY_AXIS_LEFT_Y, -1.0)
	_add_joy_axis(ACTION_BRAKE, JOY_AXIS_LEFT_Y, 1.0)
	_add_joy_button(ACTION_LEFT, JOY_BUTTON_DPAD_LEFT)
	_add_joy_button(ACTION_RIGHT, JOY_BUTTON_DPAD_RIGHT)
	_add_joy_button(ACTION_ACCELERATE, JOY_BUTTON_DPAD_UP)
	_add_joy_button(ACTION_BRAKE, JOY_BUTTON_DPAD_DOWN)
	_add_joy_button(ACTION_JUMP, JOY_BUTTON_A)
	_add_joy_button(ACTION_SKILL, JOY_BUTTON_X)
	_add_joy_button(ACTION_ITEM, JOY_BUTTON_B)
	_add_joy_button(ACTION_PAUSE, JOY_BUTTON_START)

func _add_joy_button(action: StringName, button_index: JoyButton) -> void:
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and (existing as InputEventJoypadButton).button_index == button_index:
			return
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action, event)

func _add_joy_axis(action: StringName, axis: JoyAxis, axis_value: float) -> void:
	for existing: InputEvent in InputMap.action_get_events(action):
		if existing is InputEventJoypadMotion:
			var motion := existing as InputEventJoypadMotion
			if motion.axis == axis and is_equal_approx(signf(motion.axis_value), signf(axis_value)):
				return
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	InputMap.action_add_event(action, event)
