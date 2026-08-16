extends Node

const LIGHT_IDS: Array[StringName] = [&"rabbit", &"cat", &"fox"]
const HEAVY_IDS: Array[StringName] = [&"elephant", &"bear", &"crocodile", &"boar"]
const HEAVY_JUMP_FLOOR: float = 9.20
const STANDARD_JUMP_FLOOR: float = 8.35
const HEAVY_AI_SPEED_SCALE: float = 0.94
const STANDARD_AI_SPEED_SCALE: float = 0.89
const LANDING_FLOOR_SNAP: float = 0.62
const COYOTE_TIME_SECONDS: float = 0.13
const JUMP_BUFFER_SECONDS: float = 0.14

var _logged_racers: Dictionary = {}
var _logged_drivers: Dictionary = {}
var _player_coyote_remaining: float = 0.0
var _player_jump_buffer_remaining: float = 0.0
var _player_was_on_floor: bool = false

func _physics_process(delta: float) -> void:
	_configure_racers()
	_configure_ai_drivers()
	_update_player_jump_assist(delta)

func _configure_racers() -> void:
	for racer_value: Variant in RaceManager.racers:
		var racer := racer_value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer):
			continue
		var racer_id: int = racer.get_instance_id()
		var heavy: bool = HEAVY_IDS.has(racer.animal_id)
		var jump_floor: float = HEAVY_JUMP_FLOOR if heavy else STANDARD_JUMP_FLOOR
		racer.jump_velocity = maxf(racer.jump_velocity, jump_floor)
		racer.floor_snap_length = maxf(racer.floor_snap_length, LANDING_FLOOR_SNAP)
		if _logged_racers.has(racer_id):
			continue
		_apply_animal_platform_identity(racer)
		_logged_racers[racer_id] = true
		print("LOGSPIRE MOBILITY racer=%s animal=%s jump=%.2f floor_snap=%.2f weight=%s coyote=%.2f buffer=%.2f" % [
			RaceManager.get_racer_label(racer),
			String(racer.animal_id),
			racer.jump_velocity,
			racer.floor_snap_length,
			_weight_name(racer),
			COYOTE_TIME_SECONDS,
			JUMP_BUFFER_SECONDS,
		])

func _configure_ai_drivers() -> void:
	for node: Node in get_tree().get_nodes_in_group("wilddash_ai_driver"):
		var driver := node as WildDashAIController
		if driver == null or driver.get_parent() != get_parent():
			continue
		var racer: WildDashCharacterController = driver.get_racer()
		if racer == null:
			continue
		var scale: float = HEAVY_AI_SPEED_SCALE if HEAVY_IDS.has(racer.animal_id) else STANDARD_AI_SPEED_SCALE
		driver.target_speed = maxf(driver.target_speed, racer.max_speed * scale)
		driver.acceleration = maxf(driver.acceleration, 23.0)
		var driver_id: int = driver.get_instance_id()
		if _logged_drivers.has(driver_id):
			continue
		_logged_drivers[driver_id] = true
		print("LOGSPIRE AI MOBILITY racer=%s target_speed=%.2f jump=%.2f" % [
			RaceManager.get_racer_label(racer), driver.target_speed, racer.jump_velocity,
		])

func _update_player_jump_assist(delta: float) -> void:
	var player := _resolve_player()
	if player == null or player.finished or not RaceManager.active:
		_player_coyote_remaining = 0.0
		_player_jump_buffer_remaining = 0.0
		_player_was_on_floor = false
		return

	var on_floor: bool = player.is_on_floor()
	if on_floor:
		_player_coyote_remaining = COYOTE_TIME_SECONDS
	elif _player_was_on_floor:
		_player_coyote_remaining = COYOTE_TIME_SECONDS
	else:
		_player_coyote_remaining = maxf(0.0, _player_coyote_remaining - delta)
	_player_jump_buffer_remaining = maxf(0.0, _player_jump_buffer_remaining - delta)

	var jump_pressed: bool = Input.is_action_just_pressed(&"jump")
	if jump_pressed and not on_floor:
		if _player_coyote_remaining > 0.0 and player.velocity.y <= 1.0:
			player.velocity.y = maxf(player.velocity.y, player.jump_velocity)
			_player_coyote_remaining = 0.0
			_player_jump_buffer_remaining = 0.0
			print("LOGSPIRE JUMP ASSIST type=coyote racer=%s" % RaceManager.get_racer_label(player))
		else:
			_player_jump_buffer_remaining = JUMP_BUFFER_SECONDS

	if on_floor and not _player_was_on_floor and _player_jump_buffer_remaining > 0.0:
		player.velocity.y = maxf(player.velocity.y, player.jump_velocity)
		_player_jump_buffer_remaining = 0.0
		_player_coyote_remaining = 0.0
		print("LOGSPIRE JUMP ASSIST type=buffer racer=%s" % RaceManager.get_racer_label(player))

	_player_was_on_floor = on_floor

func _apply_animal_platform_identity(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	match racer.animal_id:
		&"rabbit":
			racer.turn_speed *= 1.06
			racer.set_meta(&"logspire_aerial_adjustment", 1.12)
		&"cat":
			racer.floor_snap_length = maxf(racer.floor_snap_length, 0.82)
			racer.set_meta(&"logspire_landing_stability", 1.14)
		&"monkey":
			racer.set_meta(&"logspire_vine_affinity", 1.10)
		&"bear":
			racer.set_meta(&"logspire_platform_stability", 1.22)
		&"elephant":
			racer.set_meta(&"logspire_platform_stability", 1.30)
		_:
			pass

func _resolve_player() -> WildDashCharacterController:
	for racer_value: Variant in RaceManager.racers:
		var racer := racer_value as WildDashCharacterController
		if racer != null and racer.is_player:
			return racer
	return null

func _weight_name(racer: WildDashCharacterController) -> String:
	if racer == null:
		return "MEDIUM"
	if LIGHT_IDS.has(racer.animal_id):
		return "LIGHT"
	if HEAVY_IDS.has(racer.animal_id):
		return "HEAVY"
	return "MEDIUM"
