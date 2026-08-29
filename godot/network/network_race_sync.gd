class_name WildDashNetworkRaceSync
extends Node

## RC9 LAN Grand Prix prototype.
## - Clients send input intent, never result/rank claims.
## - Host simulates remote human racers and broadcasts authoritative transforms.
## - Clients keep local prediction for responsiveness and receive gentle correction.
## This is intentionally limited to Grand Prix for the first multiplayer milestone.

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const INPUT_SEND_HZ: float = 30.0
const STATE_SEND_HZ: float = 15.0
const CLIENT_CORRECTION_WEIGHT: float = 0.22

var _mode: WildDashModeController
var _local_player: WildDashCharacterController
var _host_remote_racers: Dictionary = {}
var _client_remote_proxies: Dictionary = {}
var _remote_inputs: Dictionary = {}
var _remote_bump_cooldowns: Dictionary = {}
var _input_elapsed: float = 0.0
var _state_elapsed: float = 0.0
var _active: bool = false

func _ready() -> void:
	if not NetworkManager.is_party_active() or not NetworkManager.party_game_active:
		set_physics_process(false)
		return
	process_priority = 70
	call_deferred("_bind_after_mode_ready")

func _bind_after_mode_ready() -> void:
	for _frame: int in range(5):
		await get_tree().physics_frame
	_mode = get_parent() as WildDashModeController
	if _mode == null or _mode.mode_id != &"grand_prix":
		push_warning("RC9 NETWORK RACE SYNC: Grand Prix mode not found")
		return
	_local_player = _mode.player
	if _local_player == null:
		push_warning("RC9 NETWORK RACE SYNC: local Player racer missing")
		return
	if multiplayer.is_server():
		_spawn_host_remote_humans()
	else:
		_spawn_client_remote_proxies()
	_active = true
	set_physics_process(true)
	print("RC9 NETWORK RACE SYNC READY host=%s peer=%d humans=%d" % [
		str(multiplayer.is_server()), multiplayer.get_unique_id(), NetworkManager.get_players().size(),
	])

func _physics_process(delta: float) -> void:
	if not _active or not NetworkManager.is_party_active():
		return
	if multiplayer.is_server():
		_tick_remote_bump_cooldowns(delta)
		_apply_host_remote_inputs(delta)
		_state_elapsed += delta
		if _state_elapsed >= 1.0 / STATE_SEND_HZ:
			_state_elapsed = 0.0
			_broadcast_authoritative_state()
	else:
		_input_elapsed += delta
		if _input_elapsed >= 1.0 / INPUT_SEND_HZ:
			_input_elapsed = 0.0
			var input_state: WildDashRacerInputState = InputManager.sample_racer_input_state()
			rpc_id(1, "_server_receive_input", input_state.to_dictionary())

func _spawn_host_remote_humans() -> void:
	var roster: Dictionary = NetworkManager.get_players()
	var peer_ids: Array = roster.keys()
	peer_ids.sort()
	var slot: int = 1
	for peer_id_value: Variant in peer_ids:
		var peer_id: int = int(peer_id_value)
		if peer_id == 1:
			continue
		var state: Dictionary = roster[peer_id] as Dictionary
		var animal: StringName = StringName(String(state.get("animal_id", "dog")))
		var spawn: Vector3 = _local_player.global_position + Vector3(float(slot) * 2.55, 0.05, float(slot % 2) * 2.2)
		var racer: WildDashCharacterController = _instantiate_network_racer("HumanPeer_%d" % peer_id, animal, spawn, true)
		_host_remote_racers[peer_id] = racer
		_remote_inputs[peer_id] = WildDashRacerInputState.new().to_dictionary()
		_remote_bump_cooldowns[peer_id] = 0.0
		slot += 1

func _spawn_client_remote_proxies() -> void:
	var roster: Dictionary = NetworkManager.get_players()
	var local_peer: int = multiplayer.get_unique_id()
	var slot: int = 1
	for peer_id_value: Variant in roster.keys():
		var peer_id: int = int(peer_id_value)
		if peer_id == local_peer:
			continue
		var state: Dictionary = roster[peer_id] as Dictionary
		var animal: StringName = StringName(String(state.get("animal_id", "dog")))
		var spawn: Vector3 = _local_player.global_position + Vector3(float(slot) * 2.4, 0.05, 1.8)
		_client_remote_proxies[peer_id] = _instantiate_network_racer("RemotePeer_%d" % peer_id, animal, spawn, true)
		slot += 1

func _instantiate_network_racer(node_name: String, animal: StringName, position: Vector3, race_body: bool) -> WildDashCharacterController:
	var racer: WildDashCharacterController = RACER_SCENE.instantiate() as WildDashCharacterController
	if racer == null:
		return null
	racer.name = node_name
	racer.is_player = false
	racer.movement_mode = WildDashCharacterController.MovementMode.RACE if race_body else WildDashCharacterController.MovementMode.ARENA
	racer.animal_id = animal if WildDashAnimalCatalog.is_playable(animal) else &"dog"
	racer.position = position
	_mode.add_child(racer)
	return racer

@rpc("any_peer", "call_remote", "unreliable_ordered")
func _server_receive_input(payload: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	var peer_id: int = multiplayer.get_remote_sender_id()
	if not _host_remote_racers.has(peer_id):
		return
	_remote_inputs[peer_id] = WildDashRacerInputState.from_dictionary(payload).to_dictionary()

func _apply_host_remote_inputs(delta: float) -> void:
	if not RaceManager.active:
		return
	for peer_id_value: Variant in _host_remote_racers.keys():
		var peer_id: int = int(peer_id_value)
		var racer: WildDashCharacterController = _host_remote_racers[peer_id] as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		var input: WildDashRacerInputState = WildDashRacerInputState.from_dictionary(_remote_inputs.get(peer_id, {}))
		_drive_remote_racer(racer, input, delta)
		if input.bump_pressed:
			_try_remote_body_check(peer_id, racer)
		input.jump_pressed = false
		input.skill_pressed = false
		input.item_pressed = false
		input.bump_pressed = false
		_remote_inputs[peer_id] = input.to_dictionary()

func _drive_remote_racer(racer: WildDashCharacterController, input: WildDashRacerInputState, delta: float) -> void:
	# LAN boost is still prototype-only and will receive the same energy authority
	# state in the dedicated multiplayer balance pass. Keep existing input response
	# here so this change stays focused on body-check parity.
	var target_speed: float = racer.cruise_speed
	var acceleration_scale: float = 1.0
	if input.throttle > 0.05:
		target_speed = WildDashRacingActionController.get_overdrive_target(racer.max_speed, input.throttle)
		acceleration_scale = WildDashRacingActionController.OVERDRIVE_ACCELERATION_MULTIPLIER
	elif input.throttle < -0.05:
		target_speed = racer.max_speed * 0.25
	target_speed *= racer.get_active_speed_scale()
	racer.current_speed = move_toward(
		racer.current_speed,
		target_speed,
		racer.acceleration * racer.get_active_acceleration_scale() * acceleration_scale * delta
	)
	racer.rotate_y(-input.steer * racer.turn_speed * racer.get_active_handling_scale() * delta)

	if input.jump_pressed and racer.is_on_floor():
		racer.velocity.y = racer.jump_velocity
	if input.skill_pressed:
		racer.try_use_skill(Vector2(input.steer, -1.0))
	if input.item_pressed:
		ItemSystem.use_held_item(racer)

	if not racer.is_on_floor():
		racer.velocity.y -= racer.gravity * delta
	elif racer.velocity.y < 0.0:
		racer.velocity.y = 0.0
	var forward: Vector3 = -racer.global_transform.basis.z.normalized()
	var knockback: Vector3 = racer.get_knockback_velocity()
	racer.velocity.x = forward.x * racer.current_speed + knockback.x
	racer.velocity.z = forward.z * racer.current_speed + knockback.z
	racer.move_and_slide()
	racer.resolve_skill_contacts()
	if racer.has_blocking_collision():
		racer.current_speed = maxf(racer.cruise_speed * 0.55, racer.current_speed * racer.get_collision_speed_retention())
	racer.decay_knockback(delta)

func _try_remote_body_check(peer_id: int, racer: WildDashCharacterController) -> void:
	if float(_remote_bump_cooldowns.get(peer_id, 0.0)) > 0.0:
		return
	var target: WildDashCharacterController = _find_body_check_target(racer)
	if target == null:
		return
	var raw_offset: Vector3 = target.global_position - racer.global_position
	var offset: Vector3 = Vector3(raw_offset.x, 0.0, raw_offset.z)
	if offset.length_squared() <= 0.001:
		return

	var attacker_right: Vector3 = racer.global_transform.basis.x.normalized()
	var side_amount: float = offset.dot(attacker_right)
	var side_sign: float = signf(side_amount)
	if absf(side_amount) < 0.18:
		side_sign = 1.0
	var lateral_push: Vector3 = attacker_right * side_sign
	var push_direction: Vector3 = (lateral_push * 0.78 + offset.normalized() * 0.22).normalized()
	var impulse: float = WildDashRacingActionController.calculate_body_check_impulse(racer.animal_id, target.animal_id)
	target.apply_knockback(push_direction, impulse)
	var target_retention: float = clampf(0.94 - maxf(0.0, impulse - 3.0) * 0.018, 0.80, 0.94)
	target.current_speed *= target_retention
	racer.current_speed *= WildDashRacingActionController.ATTACKER_SPEED_RETENTION
	_remote_bump_cooldowns[peer_id] = WildDashRacingActionController.BODY_CHECK_COOLDOWN
	print("RC9 NETWORK BODY CHECK attacker=%s target=%s impulse=%.2f" % [racer.name, target.name, impulse])

func _find_body_check_target(racer: WildDashCharacterController) -> WildDashCharacterController:
	var best: WildDashCharacterController = null
	var best_score: float = INF
	var forward: Vector3 = -racer.global_transform.basis.z.normalized()
	for candidate: Node3D in RaceManager.racers:
		if candidate == racer or not candidate is WildDashCharacterController:
			continue
		var target: WildDashCharacterController = candidate as WildDashCharacterController
		if target.finished:
			continue
		var raw_offset: Vector3 = target.global_position - racer.global_position
		if absf(raw_offset.y) > WildDashRacingActionController.BODY_CHECK_MAX_VERTICAL_DELTA:
			continue
		var offset: Vector3 = Vector3(raw_offset.x, 0.0, raw_offset.z)
		var distance: float = offset.length()
		if distance <= 0.01 or distance > WildDashRacingActionController.BODY_CHECK_RANGE:
			continue
		var alignment: float = forward.dot(offset / distance)
		if alignment < WildDashRacingActionController.BODY_CHECK_FORWARD_DOT:
			continue
		var score: float = distance - maxf(0.0, alignment) * 0.35
		if score < best_score:
			best_score = score
			best = target
	return best

func _tick_remote_bump_cooldowns(delta: float) -> void:
	for peer_id: Variant in _remote_bump_cooldowns.keys():
		_remote_bump_cooldowns[peer_id] = maxf(0.0, float(_remote_bump_cooldowns[peer_id]) - delta)

func _broadcast_authoritative_state() -> void:
	if not multiplayer.is_server() or _local_player == null:
		return
	var snapshot: Array = []
	snapshot.append(_racer_state(1, _local_player))
	for peer_id_value: Variant in _host_remote_racers.keys():
		var peer_id: int = int(peer_id_value)
		var racer: WildDashCharacterController = _host_remote_racers[peer_id] as WildDashCharacterController
		if racer != null:
			snapshot.append(_racer_state(peer_id, racer))
	rpc("_client_receive_authoritative_state", snapshot)

func _racer_state(peer_id: int, racer: WildDashCharacterController) -> Dictionary:
	return {
		"peer_id": peer_id,
		"position": racer.global_position,
		"rotation_y": racer.rotation.y,
		"velocity": racer.velocity,
		"speed": racer.current_speed,
		"rank": RaceManager.get_rank(racer),
		"finished": racer.finished,
	}

@rpc("authority", "call_remote", "unreliable_ordered")
func _client_receive_authoritative_state(snapshot: Array) -> void:
	if multiplayer.is_server() or _local_player == null:
		return
	var local_peer: int = multiplayer.get_unique_id()
	for value: Variant in snapshot:
		if typeof(value) != TYPE_DICTIONARY:
			continue
		var state: Dictionary = value as Dictionary
		var peer_id: int = int(state.get("peer_id", 0))
		var position: Vector3 = state.get("position", Vector3.ZERO)
		var rotation_y: float = float(state.get("rotation_y", 0.0))
		var speed: float = float(state.get("speed", 0.0))
		if peer_id == local_peer:
			if _local_player.global_position.distance_to(position) > 0.18:
				_local_player.global_position = _local_player.global_position.lerp(position, CLIENT_CORRECTION_WEIGHT)
				_local_player.rotation.y = lerp_angle(_local_player.rotation.y, rotation_y, CLIENT_CORRECTION_WEIGHT)
				_local_player.current_speed = lerpf(_local_player.current_speed, speed, CLIENT_CORRECTION_WEIGHT)
			continue
		var proxy: WildDashCharacterController = _client_remote_proxies.get(peer_id) as WildDashCharacterController
		if proxy == null:
			var roster: Dictionary = NetworkManager.get_players()
			var player_state: Dictionary = roster.get(peer_id, {}) as Dictionary
			var animal: StringName = StringName(String(player_state.get("animal_id", "dog")))
			proxy = _instantiate_network_racer("RemotePeer_%d" % peer_id, animal, position, true)
			_client_remote_proxies[peer_id] = proxy
		if proxy != null:
			proxy.global_position = proxy.global_position.lerp(position, 0.42)
			proxy.rotation.y = lerp_angle(proxy.rotation.y, rotation_y, 0.42)
			proxy.current_speed = lerpf(proxy.current_speed, speed, 0.42)
