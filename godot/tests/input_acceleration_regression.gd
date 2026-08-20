extends Node

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")

func _ready() -> void:
	var failures: Array[String] = []

	# Simulate an old/stale save that remembers a non-default accelerate key.
	InputManager.apply_keyboard_bindings({"accelerate": int(KEY_T)})
	if not _has_key(InputManager.ACTION_ACCELERATE, KEY_W):
		failures.append("W safety alias missing after saved binding apply")
	if not _has_key(InputManager.ACTION_ACCELERATE, KEY_UP):
		failures.append("Up safety alias missing after saved binding apply")

	Input.action_press(InputManager.ACTION_ACCELERATE, 1.0)
	await get_tree().process_frame
	if InputManager.get_throttle_axis() < 0.95:
		failures.append("Accelerate action did not produce positive throttle")
	Input.action_release(InputManager.ACTION_ACCELERATE)

	Input.action_press(InputManager.ACTION_BRAKE, 1.0)
	await get_tree().process_frame
	if InputManager.get_throttle_axis() > -0.95:
		failures.append("Brake action did not produce negative throttle")
	Input.action_release(InputManager.ACTION_BRAKE)

	var racer := RACER_SCENE.instantiate() as WildDashCharacterController
	racer.name = "AccelerationProbe"
	racer.is_player = true
	racer.movement_mode = WildDashCharacterController.MovementMode.RACE
	racer.animal_id = &"dog"
	add_child(racer)
	await get_tree().physics_frame
	RaceManager.active = true
	racer.current_speed = racer.cruise_speed
	var cruise_before := racer.cruise_speed
	var max_speed := racer.max_speed

	Input.action_press(InputManager.ACTION_ACCELERATE, 1.0)
	for _frame in range(24):
		await get_tree().physics_frame
	Input.action_release(InputManager.ACTION_ACCELERATE)
	var accelerated_speed := racer.current_speed
	if accelerated_speed <= cruise_before + 0.5:
		failures.append("Held accelerate did not raise speed above cruise")
	if accelerated_speed > max_speed + 0.25:
		failures.append("Held accelerate exceeded expected max-speed envelope")

	for _frame in range(36):
		await get_tree().physics_frame
	var released_speed := racer.current_speed
	if released_speed > accelerated_speed + 0.1:
		failures.append("Released throttle unexpectedly increased speed")
	if absf(released_speed - racer.cruise_speed) > 0.75:
		failures.append("Released throttle did not return toward cruise speed")

	RaceManager.active = false
	if failures.is_empty():
		print("RC9 INPUT ACCELERATION PASS cruise=%.2f held=%.2f released=%.2f max=%.2f W_alias=true" % [
			cruise_before, accelerated_speed, released_speed, max_speed,
		])
		get_tree().quit(0)
		return
	for failure in failures:
		push_error("RC9 INPUT ACCELERATION FAIL " + failure)
	get_tree().quit(1)

func _has_key(action: StringName, keycode: Key) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.physical_keycode == keycode or key_event.keycode == keycode:
				return true
	return false
