extends Node

const ACTION_LEFT: StringName = &"move_left"
const ACTION_RIGHT: StringName = &"move_right"
const ACTION_ACCELERATE: StringName = &"accelerate"
const ACTION_BRAKE: StringName = &"brake"
const ACTION_JUMP: StringName = &"jump"
const ACTION_SKILL: StringName = &"skill"
const ACTION_ITEM: StringName = &"item"

func _ready() -> void:
	_ensure_action(ACTION_LEFT, [KEY_A, KEY_LEFT])
	_ensure_action(ACTION_RIGHT, [KEY_D, KEY_RIGHT])
	_ensure_action(ACTION_ACCELERATE, [KEY_W, KEY_UP])
	_ensure_action(ACTION_BRAKE, [KEY_S, KEY_DOWN])
	_ensure_action(ACTION_JUMP, [KEY_SPACE])
	_ensure_action(ACTION_SKILL, [KEY_E])
	_ensure_action(ACTION_ITEM, [KEY_Q], [JOY_BUTTON_B])

func get_steer_axis() -> float:
	return Input.get_axis(ACTION_LEFT, ACTION_RIGHT)

func get_throttle_axis() -> float:
	return Input.get_action_strength(ACTION_ACCELERATE) - Input.get_action_strength(ACTION_BRAKE)

func get_move_vector() -> Vector2:
	var x := Input.get_action_strength(ACTION_RIGHT) - Input.get_action_strength(ACTION_LEFT)
	var y := Input.get_action_strength(ACTION_BRAKE) - Input.get_action_strength(ACTION_ACCELERATE)
	var vector := Vector2(x, y)
	return vector.normalized() if vector.length_squared() > 1.0 else vector

func consume_jump() -> bool:
	return Input.is_action_just_pressed(ACTION_JUMP)

func consume_skill() -> bool:
	return Input.is_action_just_pressed(ACTION_SKILL)

func consume_item() -> bool:
	return Input.is_action_just_pressed(ACTION_ITEM)

func _ensure_action(action: StringName, physical_keys: Array, joy_buttons: Array = []) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key_code in physical_keys:
		if not _has_physical_key(action, key_code):
			var event := InputEventKey.new()
			event.physical_keycode = key_code
			InputMap.action_add_event(action, event)
	for button_index in joy_buttons:
		if not _has_joy_button(action, button_index):
			var joy_event := InputEventJoypadButton.new()
			joy_event.button_index = button_index
			InputMap.action_add_event(action, joy_event)

func _has_physical_key(action: StringName, key_code: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == key_code:
			return true
	return false

func _has_joy_button(action: StringName, button_index: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button_index:
			return true
	return false
