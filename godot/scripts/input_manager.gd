extends Node

signal race_combat_action_resolved(action: Dictionary)

const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_ACCELERATE: StringName = &"accelerate"
const ACTION_BRAKE: StringName = &"brake"
const ACTION_JUMP: StringName = &"jump"
const ACTION_SKILL: StringName = &"skill"
const ACTION_ITEM: StringName = &"item"
const ACTION_BUMP: StringName = &"race_bump"
const ACTION_PAUSE: StringName = &"pause"

const RACE_COMBAT_HOLD_THRESHOLD: float = 0.42
const RACE_COMBAT_DIRECTION_THRESHOLD: float = 0.35

const GAME_ACTIONS: Array[StringName] = [
	ACTION_LEFT, ACTION_RIGHT, ACTION_ACCELERATE, ACTION_BRAKE,
	ACTION_JUMP, ACTION_SKILL, ACTION_ITEM, ACTION_BUMP, ACTION_PAUSE,
]

const DEFAULT_KEYS: Dictionary = {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"accelerate": [KEY_W, KEY_UP],
	"brake": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE],
	"skill": [KEY_E],
	"item": [KEY_Q],
	"race_bump": [KEY_F],
	"pause": [KEY_ESCAPE, KEY_P],
}

var _input_sequence: int = 0
var _race_bump_physical_was_down: bool = false
var _boost_physical_was_down: bool = false
var _race_combat_down: bool = false
var _race_combat_hold_seconds: float = 0.0
var _race_combat_hold_emitted: bool = false
var _race_combat_press_direction: int = 0
var _race_combat_sequence: int = 0
var _last_race_combat_action: Dictionary = {}

func _ready() -> void:
	for action: StringName in GAME_ACTIONS:
		_ensure_action(action)
		_add_default_keyboard(action)
	_add_default_gamepad()
	# Saved single-key bindings from older builds can erase the default aliases.
	# Keep the canonical driving/body-check controls available as safety aliases.
	_ensure_core_keyboard_safety_aliases()

func _physics_process(delta: float) -> void:
	_update_race_combat_gesture(delta)

func get_steer_axis() -> float:
	return Input.get_axis(ACTION_LEFT, ACTION_RIGHT)

func get_throttle_axis() -> float:
	var accelerate_strength: float = Input.get_action_strength(ACTION_ACCELERATE)
	var brake_strength: float = Input.get_action_strength(ACTION_BRAKE)
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		accelerate_strength = maxf(accelerate_strength, 1.0)
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		brake_strength = maxf(brake_strength, 1.0)
	return clampf(accelerate_strength - brake_strength, -1.0, 1.0)

func get_move_vector() -> Vector2:
	return Input.get_vector(ACTION_LEFT, ACTION_RIGHT, ACTION_ACCELERATE, ACTION_BRAKE, 0.2)

func sample_racer_input_state() -> WildDashRacerInputState:
	_input_sequence += 1
	var state: WildDashRacerInputState = WildDashRacerInputState.new()
	state.steer = get_steer_axis()
	state.throttle = get_throttle_axis()
	state.jump_pressed = consume_jump()
	state.skill_pressed = consume_skill()
	state.item_pressed = consume_item()
	state.bump_pressed = consume_race_bump()
	state.sequence = _input_sequence
	return state

func get_input_debug_snapshot() -> Dictionary:
	return {
		"w_pressed": Input.is_physical_key_pressed(KEY_W),
		"up_pressed": Input.is_physical_key_pressed(KEY_UP),
		"f_pressed": Input.is_physical_key_pressed(KEY_F),
		"accelerate_action": Input.get_action_strength(ACTION_ACCELERATE),
		"brake_action": Input.get_action_strength(ACTION_BRAKE),
		"throttle": get_throttle_axis(),
		"combat_hold_seconds": _race_combat_hold_seconds,
		"combat_hold_emitted": _race_combat_hold_emitted,
		"combat_last": _last_race_combat_action.duplicate(true),
		"accelerate_binding": get_keyboard_binding_text(ACTION_ACCELERATE),
		"brake_binding": get_keyboard_binding_text(ACTION_BRAKE),
		"bump_binding": get_keyboard_binding_text(ACTION_BUMP),
	}

func consume_jump() -> bool:
	return Input.is_action_just_pressed(ACTION_JUMP)

func consume_skill() -> bool:
	return Input.is_action_just_pressed(ACTION_SKILL)

func consume_item() -> bool:
	return Input.is_action_just_pressed(ACTION_ITEM)

func consume_boost_press() -> bool:
	# Boost is an edge-triggered resource action. Do not infer the edge from the
	# throttle value: a held throttle and a newly pressed W must be distinguishable.
	# The physical-key edge is a safety fallback for stale saved InputMap bindings.
	var action_edge: bool = Input.is_action_just_pressed(ACTION_ACCELERATE)
	var physical_down: bool = Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)
	var physical_edge: bool = physical_down and not _boost_physical_was_down
	_boost_physical_was_down = physical_down
	return action_edge or physical_edge

func consume_race_bump() -> bool:
	# Compatibility path for RC9 controllers. Race Combat Core V2 separately
	# classifies the same F/Y gesture as Tap/Hold + direction without removing
	# the proven legacy body-check behaviour during the migration.
	var action_edge: bool = Input.is_action_just_pressed(ACTION_BUMP)
	var physical_down: bool = Input.is_physical_key_pressed(KEY_F)
	var physical_edge: bool = physical_down and not _race_bump_physical_was_down
	_race_bump_physical_was_down = physical_down
	return action_edge or physical_edge

func is_race_combat_pressed() -> bool:
	return Input.is_action_pressed(ACTION_BUMP) or Input.is_physical_key_pressed(KEY_F)

func get_race_combat_hold_threshold() -> float:
	return RACE_COMBAT_HOLD_THRESHOLD

func get_last_race_combat_action() -> Dictionary:
	return _last_race_combat_action.duplicate(true)

func classify_race_combat_direction(steer: float) -> int:
	if steer <= -RACE_COMBAT_DIRECTION_THRESHOLD:
		return -1
	if steer >= RACE_COMBAT_DIRECTION_THRESHOLD:
		return 1
	return 0

func get_race_combat_direction_name(direction: int) -> StringName:
	if direction < 0:
		return &"left"
	if direction > 0:
		return &"right"
	return &"neutral"

func consume_pause() -> bool:
	return Input.is_action_just_pressed(ACTION_PAUSE)

func rebind_keyboard(action: StringName, physical_keycode: int) -> bool:
	if action not in GAME_ACTIONS or physical_keycode == int(KEY_NONE):
		return false
	var events: Array[InputEvent] = InputMap.action_get_events(action)
	for event: InputEvent in events:
		if event is InputEventKey:
			InputMap.action_erase_event(action, event)
	var replacement: InputEventKey = InputEventKey.new()
	replacement.physical_keycode = physical_keycode
	InputMap.action_add_event(action, replacement)
	_ensure_core_keyboard_safety_aliases()
	return true

func export_keyboard_bindings() -> Dictionary:
	var result: Dictionary = {}
	for action: StringName in GAME_ACTIONS:
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				var key_event := event as InputEventKey
				result[String(action)] = int(key_event.physical_keycode)
				break
	return result

func apply_keyboard_bindings(bindings: Dictionary) -> void:
	for action_text in bindings.keys():
		if typeof(action_text) != TYPE_STRING:
			continue
		var action := StringName(String(action_text))
		if action not in GAME_ACTIONS:
			continue
		var raw_key: Variant = bindings[action_text]
		if typeof(raw_key) != TYPE_INT and typeof(raw_key) != TYPE_FLOAT:
			continue
		var keycode := int(raw_key)
		if keycode != int(KEY_NONE):
			rebind_keyboard(action, keycode)
	_ensure_core_keyboard_safety_aliases()

func get_keyboard_binding_text(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			return OS.get_keycode_string(key_event.physical_keycode)
	return "Unbound"

func get_gamepad_hint(action: StringName) -> String:
	match action:
		ACTION_JUMP: return "A"
		ACTION_SKILL: return "X"
		ACTION_ITEM: return "B"
		ACTION_BUMP: return "Y"
		ACTION_PAUSE: return "Start"
		ACTION_LEFT, ACTION_RIGHT, ACTION_ACCELERATE, ACTION_BRAKE: return "Left Stick / D-Pad"
		_: return ""

func _update_race_combat_gesture(delta: float) -> void:
	var down: bool = is_race_combat_pressed()
	if down and not _race_combat_down:
		_race_combat_down = true
		_race_combat_hold_seconds = 0.0
		_race_combat_hold_emitted = false
		_race_combat_press_direction = classify_race_combat_direction(get_steer_axis())
		return

	if down and _race_combat_down:
		_race_combat_hold_seconds += delta
		if not _race_combat_hold_emitted and _race_combat_hold_seconds >= RACE_COMBAT_HOLD_THRESHOLD:
			_race_combat_hold_emitted = true
			var direction: int = classify_race_combat_direction(get_steer_axis())
			if direction == 0:
				direction = _race_combat_press_direction
			_emit_race_combat_action(&"hold", direction, _race_combat_hold_seconds)
		return

	if not down and _race_combat_down:
		if not _race_combat_hold_emitted:
			var direction: int = classify_race_combat_direction(get_steer_axis())
			if direction == 0:
				direction = _race_combat_press_direction
			_emit_race_combat_action(&"tap", direction, _race_combat_hold_seconds)
		_race_combat_down = false
		_race_combat_hold_seconds = 0.0
		_race_combat_hold_emitted = false
		_race_combat_press_direction = 0

func _emit_race_combat_action(kind: StringName, direction: int, held_seconds: float) -> void:
	_race_combat_sequence += 1
	_last_race_combat_action = {
		"sequence": _race_combat_sequence,
		"kind": kind,
		"direction": direction,
		"direction_name": get_race_combat_direction_name(direction),
		"held_seconds": held_seconds,
		"steer": get_steer_axis(),
	}
	race_combat_action_resolved.emit(_last_race_combat_action.duplicate(true))

func _ensure_action(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	else:
		InputMap.action_set_deadzone(action, 0.2)

func _add_default_keyboard(action: StringName) -> void:
	var has_keyboard: bool = false
	for existing in InputMap.action_get_events(action):
		if existing is InputEventKey:
			has_keyboard = true
			break
	if has_keyboard:
		return
	var codes: Array = DEFAULT_KEYS.get(String(action), [])
	for code in codes:
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
	_ensure_key_event(ACTION_BUMP, KEY_F)

func _ensure_key_event(action: StringName, keycode: Key) -> void:
	for existing in InputMap.action_get_events(action):
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
	_add_joy_button(ACTION_BUMP, JOY_BUTTON_Y)
	_add_joy_button(ACTION_PAUSE, JOY_BUTTON_START)

func _add_joy_button(action: StringName, button_index: JoyButton) -> void:
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadButton and (existing as InputEventJoypadButton).button_index == button_index:
			return
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action, event)

func _add_joy_axis(action: StringName, axis: JoyAxis, axis_value: float) -> void:
	for existing in InputMap.action_get_events(action):
		if existing is InputEventJoypadMotion:
			var motion := existing as InputEventJoypadMotion
			if motion.axis == axis and is_equal_approx(signf(motion.axis_value), signf(axis_value)):
				return
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	InputMap.action_add_event(action, event)
