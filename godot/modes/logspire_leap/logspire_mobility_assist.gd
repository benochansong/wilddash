extends Node

const HEAVY_IDS: Array[StringName] = [&"elephant", &"bear", &"crocodile", &"boar"]
const HEAVY_JUMP_FLOOR: float = 9.20
const STANDARD_JUMP_FLOOR: float = 8.35
const HEAVY_AI_SPEED_SCALE: float = 0.94
const STANDARD_AI_SPEED_SCALE: float = 0.89
const LANDING_FLOOR_SNAP: float = 0.55

var _logged_racers: Dictionary = {}
var _logged_drivers: Dictionary = {}

func _physics_process(_delta: float) -> void:
	_configure_racers()
	_configure_ai_drivers()

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
		_logged_racers[racer_id] = true
		print("LOGSPIRE MOBILITY racer=%s animal=%s jump=%.2f floor_snap=%.2f heavy=%s" % [
			RaceManager.get_racer_label(racer), String(racer.animal_id), racer.jump_velocity, racer.floor_snap_length, str(heavy),
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
