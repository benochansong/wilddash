class_name WildDashGrandPrixRivalPressure
extends Node

const RIVAL_NAME := "AI_01"
const PRESSURE_SPEED_SCALE := 1.08
const LEADING_SPEED_SCALE := 1.02
const ACCELERATION_SCALE := 1.06
const MAX_PRESSURE_GAP_METERS := 140.0
const UPDATE_INTERVAL := 0.10

var _driver: WildDashAIController
var _racer: WildDashCharacterController
var _base_target_speed := 0.0
var _base_acceleration := 0.0
var _ready_for_pressure := false
var _update_elapsed := 0.0

func _ready() -> void:
	process_priority = 60
	call_deferred("_bind_signature_rival")

func _bind_signature_rival() -> void:
	for _frame in range(5):
		await get_tree().physics_frame
	for node in get_tree().get_nodes_in_group("wilddash_ai_driver"):
		if not node is WildDashAIController:
			continue
		var driver := node as WildDashAIController
		var racer := driver.get_racer()
		if racer == null or racer.name != RIVAL_NAME or racer.is_player:
			continue
		_driver = driver
		_racer = racer
		_base_target_speed = driver.target_speed
		_base_acceleration = driver.acceleration
		_driver.acceleration = maxf(_driver.acceleration, _base_acceleration * ACCELERATION_SCALE)
		_driver.steering_strength = maxf(_driver.steering_strength, 6.4)
		_ready_for_pressure = true
		print("RC7 SIGNATURE RIVAL READY racer=%s target=%.2f pressure=%.2f accel=%.2f update_hz=%.1f" % [
			_racer.name, _base_target_speed, PRESSURE_SPEED_SCALE, _driver.acceleration, 1.0 / UPDATE_INTERVAL,
		])
		return
	push_warning("RC7 SIGNATURE RIVAL: AI_01 driver not found")

func _process(delta: float) -> void:
	if not _ready_for_pressure or _driver == null or _racer == null:
		return
	if not RaceManager.active or _racer.finished:
		return
	_update_elapsed += delta
	if _update_elapsed < UPDATE_INTERVAL:
		return
	_update_elapsed = fmod(_update_elapsed, UPDATE_INTERVAL)

	var player := _find_player()
	if player == null or player.finished:
		return

	var player_progress := RaceManager.get_track_progress(player)
	var rival_progress := RaceManager.get_track_progress(_racer)
	var rival_rank := RaceManager.get_rank(_racer)
	var gap := player_progress - rival_progress
	var pressure_scale := LEADING_SPEED_SCALE
	if gap >= 0.0 and gap <= MAX_PRESSURE_GAP_METERS:
		pressure_scale = PRESSURE_SPEED_SCALE
	elif gap > MAX_PRESSURE_GAP_METERS:
		pressure_scale = 1.10
	elif rival_rank > 1:
		pressure_scale = 1.05

	_driver.target_speed = maxf(_driver.target_speed, _base_target_speed * pressure_scale)
	_driver.acceleration = maxf(_driver.acceleration, _base_acceleration * ACCELERATION_SCALE)

func _find_player() -> WildDashCharacterController:
	for candidate in RaceManager.racers:
		if candidate is WildDashCharacterController and (candidate as WildDashCharacterController).is_player:
			return candidate as WildDashCharacterController
	return null
