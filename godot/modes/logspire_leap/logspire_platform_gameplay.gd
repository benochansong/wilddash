extends Node

const ROUTE_SAFE: StringName = &"safe"
const ROUTE_WILD: StringName = &"wild"

const WEIGHT_LIGHT: StringName = &"LIGHT"
const WEIGHT_MEDIUM: StringName = &"MEDIUM"
const WEIGHT_HEAVY: StringName = &"HEAVY"
const LIGHT_IDS: Array[StringName] = [&"rabbit", &"cat", &"fox"]
const HEAVY_IDS: Array[StringName] = [&"boar", &"bear", &"crocodile", &"elephant"]

const SFX_WOOD_LAND := "wood_land"
const SFX_WOOD_CRACK := "wood_crack"
const SFX_WOOD_BREAK := "wood_break"
const SFX_LOG_ROLL := "log_roll"
const SFX_LOG_SWING := "log_swing"
const SFX_MUSHROOM_BOUNCE := "mushroom_bounce"
const SFX_VINE_SWING := "vine_swing"

const CRACK_USAGE_TO_WARN: float = 0.80
const CRACK_WARNING_SECONDS: float = 0.80
const CRACK_BREAK_SECONDS: float = 0.65
const CRACK_RESPAWN_SECONDS: float = 4.80
const LAUNCH_COOLDOWN_SECONDS: float = 1.15
const PLATFORM_CONTACT_VERTICAL: float = 4.5

var _world: Node
var _graph: Node
var _configured: bool = false
var _runtime: Dictionary = {}
var _launch_cooldowns: Dictionary = {}
var _shortcut_logged: Dictionary = {}
var _design_shortcut_saving_seconds: float = 4.0

func configure(world: Node, graph: Node) -> void:
	_world = world
	_graph = graph
	if _world == null or _graph == null:
		push_error("LOGSPIRE PHASE2 GAMEPLAY configure failed: world/graph missing")
		return

	_runtime.clear()
	_build_rolling_log(&"Z3_02", 1.0, 2.75, 11.5)
	_build_balance_log(&"Z3_03")
	_build_cracking_log(&"Z3_05")
	_build_rolling_log(&"Z3_07", -1.0, 2.75, 11.5)

	_build_swing_log(&"Z4_SAFE_04", 3.0, 4.8, 2.45, 17.0, ROUTE_SAFE)
	_build_mushroom(&"Z4_WILD_01")
	_build_vine(&"Z4_WILD_02")
	_build_swing_log(&"Z4_WILD_04", 4.2, 4.0, 2.25, 13.5, ROUTE_WILD)

	# Finale preparation: three readable scripted swings, not random physics.
	_build_swing_log(&"Z6_03", 2.8, 4.6, 2.25, 12.0, ROUTE_SAFE)
	_build_swing_log(&"Z6_05", -3.2, 4.2, 2.25, 12.0, ROUTE_SAFE)
	_build_swing_log(&"Z6_07", 3.6, 3.9, 2.25, 12.0, ROUTE_SAFE)

	var safe_length: float = float(_graph.call("get_route_length", ROUTE_SAFE))
	var wild_length: float = float(_graph.call("get_route_length", ROUTE_WILD))
	var geometric_saving: float = maxf(0.0, safe_length - wild_length) / 11.5
	# Mushroom + vine scripted launch contribute a deliberate extra tempo gain.
	_design_shortcut_saving_seconds = clampf(geometric_saving + 2.6, 4.0, 8.0)
	_configured = true
	print("LOGSPIRE MOVING LOG READY rolling=2 balance=1 cracking=1 swing=5 animatable=true rigidbody=false")
	print("LOGSPIRE PHASE2 ROUTE READY safe_length=%.1fm wild_length=%.1fm design_saving=%.1fs mushroom=true vine=true recovery_branch=true" % [
		safe_length, wild_length, _design_shortcut_saving_seconds,
	])

func _physics_process(delta: float) -> void:
	_update_launch_cooldowns(delta)
	if not _configured or not RaceManager.active:
		return
	for key: Variant in _runtime.keys():
		var platform_id := StringName(key)
		var data: Dictionary = _runtime[platform_id]
		var kind: StringName = data.get("kind", &"")
		match kind:
			&"rolling":
				_update_rolling(platform_id, data, delta)
			&"balance":
				_update_balance(platform_id, data, delta)
			&"cracking":
				_update_cracking(platform_id, data, delta)
			&"swing":
				_update_swing(platform_id, data, delta)
			_:
				pass

func get_weight_category(racer: WildDashCharacterController) -> StringName:
	if racer == null:
		return WEIGHT_MEDIUM
	if LIGHT_IDS.has(racer.animal_id):
		return WEIGHT_LIGHT
	if HEAVY_IDS.has(racer.animal_id):
		return WEIGHT_HEAVY
	return WEIGHT_MEDIUM

func get_weight_scale(racer: WildDashCharacterController) -> float:
	match get_weight_category(racer):
		WEIGHT_LIGHT:
			return 0.78
		WEIGHT_HEAVY:
			return 1.28
		_:
			return 1.0

func get_stability_scale(racer: WildDashCharacterController) -> float:
	if racer == null:
		return 1.0
	match racer.animal_id:
		&"bear":
			return 1.22
		&"elephant":
			return 1.30
		&"crocodile":
			return 1.18
		&"boar":
			return 1.14
		&"cat":
			return 1.08
		_:
			return 1.0

func predict_landing(platform_id: StringName, travel_time: float) -> Vector3:
	var fallback: Vector3 = _platform_top(platform_id)
	if not _runtime.has(platform_id):
		return fallback
	var data: Dictionary = _runtime[platform_id]
	var body := data.get("body") as AnimatableBody3D
	if body == null:
		return fallback
	var top_offset: float = float(data.get("top_offset", 0.4))
	var predicted := body.global_position + Vector3.UP * top_offset
	var kind: StringName = data.get("kind", &"")
	if kind == &"swing":
		var velocity: Vector3 = data.get("velocity", Vector3.ZERO)
		predicted += velocity * clampf(travel_time, 0.0, 0.55)
	elif kind == &"rolling":
		var right: Vector3 = data.get("right", Vector3.RIGHT)
		var angular: float = float(data.get("angular_speed", 0.0))
		predicted -= right * angular * 0.28
	return predicted

func get_platform_velocity(platform_id: StringName) -> Vector3:
	if not _runtime.has(platform_id):
		return Vector3.ZERO
	var data: Dictionary = _runtime[platform_id]
	return data.get("velocity", Vector3.ZERO)

func get_platform_rotation(platform_id: StringName) -> Vector3:
	if not _runtime.has(platform_id):
		return Vector3.ZERO
	var data: Dictionary = _runtime[platform_id]
	var body := data.get("body") as AnimatableBody3D
	return Vector3.ZERO if body == null else body.rotation

func get_platform_kind(platform_id: StringName) -> StringName:
	if not _runtime.has(platform_id):
		return &"stable"
	var data: Dictionary = _runtime[platform_id]
	return data.get("kind", &"stable")

func get_design_shortcut_saving_seconds() -> float:
	return _design_shortcut_saving_seconds

func _build_rolling_log(platform_id: StringName, direction_sign: float, radius: float, length: float) -> void:
	_disable_original_platform(platform_id)
	var forward: Vector3 = _platform_forward(platform_id, ROUTE_SAFE)
	var body := _make_log_body(platform_id, radius, length, forward)
	if body == null:
		return
	var area := _make_contact_area(body, radius, length)
	var spin := body.get_node_or_null("SpinVisual") as Node3D
	_runtime[platform_id] = {
		"kind": &"rolling",
		"body": body,
		"area": area,
		"spin": spin,
		"top_offset": radius,
		"angular_speed": direction_sign * 1.15,
		"right": _right_from_forward(forward),
		"velocity": Vector3.ZERO,
	}

func _build_balance_log(platform_id: StringName) -> void:
	_disable_original_platform(platform_id)
	var forward: Vector3 = _platform_forward(platform_id, ROUTE_SAFE)
	var body := _make_box_body(platform_id, Vector3(13.0, 0.8, 11.0), forward, Color(0.46, 0.30, 0.13))
	if body == null:
		return
	var area := _make_box_contact_area(body, Vector3(13.0, 3.0, 11.0))
	_runtime[platform_id] = {
		"kind": &"balance",
		"body": body,
		"area": area,
		"top_offset": 0.4,
		"right": _right_from_forward(forward),
		"velocity": Vector3.ZERO,
		"tilt": 0.0,
	}

func _build_cracking_log(platform_id: StringName) -> void:
	_disable_original_platform(platform_id)
	var forward: Vector3 = _platform_forward(platform_id, ROUTE_SAFE)
	var material := _make_material(Color(0.48, 0.31, 0.13))
	var body := _make_box_body(platform_id, Vector3(12.0, 0.8, 11.0), forward, Color(0.48, 0.31, 0.13), material)
	if body == null:
		return
	var area := _make_box_contact_area(body, Vector3(12.0, 3.0, 11.0))
	_runtime[platform_id] = {
		"kind": &"cracking",
		"body": body,
		"area": area,
		"top_offset": 0.4,
		"velocity": Vector3.ZERO,
		"state": &"SAFE",
		"usage": 0.0,
		"timer": 0.0,
		"base_position": body.global_position,
		"base_rotation": body.rotation,
		"material": material,
	}

func _build_swing_log(
	platform_id: StringName,
	amplitude: float,
	period: float,
	radius: float,
	length: float,
	route_id: StringName
) -> void:
	_disable_original_platform(platform_id)
	var forward: Vector3 = _platform_forward(platform_id, route_id)
	var body := _make_log_body(platform_id, radius, length, forward)
	if body == null:
		return
	var area := _make_contact_area(body, radius, length)
	var base_position: Vector3 = body.global_position
	_runtime[platform_id] = {
		"kind": &"swing",
		"body": body,
		"area": area,
		"top_offset": radius,
		"right": _right_from_forward(forward),
		"base_position": base_position,
		"previous_position": base_position,
		"velocity": Vector3.ZERO,
		"amplitude": amplitude,
		"period": maxf(2.5, period),
		"phase": float(platform_id.hash() % 100) * 0.021,
		"previous_riders": {},
	}

func _build_mushroom(platform_id: StringName) -> void:
	var top: Vector3 = _platform_top(platform_id)
	var area := Area3D.new()
	area.name = "Phase2MushroomArea"
	area.global_position = top + Vector3.UP * 1.1
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 3.2
	shape.height = 2.2
	collision.shape = shape
	area.add_child(collision)
	_world.add_child(area)
	area.body_entered.connect(_on_mushroom_body_entered.bind(platform_id))

	var cap := MeshInstance3D.new()
	cap.name = "Phase2MushroomVisual"
	var mesh := SphereMesh.new()
	mesh.radius = 3.2
	mesh.height = 2.0
	mesh.material = _make_material(Color(0.82, 0.20, 0.18))
	cap.mesh = mesh
	cap.scale = Vector3(1.0, 0.45, 1.0)
	cap.global_position = top + Vector3.UP * 0.55
	_world.add_child(cap)

func _build_vine(platform_id: StringName) -> void:
	var top: Vector3 = _platform_top(platform_id)
	var area := Area3D.new()
	area.name = "Phase2VineArea"
	area.global_position = top + Vector3.UP * 2.5
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(6.5, 6.0, 8.5)
	collision.shape = shape
	area.add_child(collision)
	_world.add_child(area)
	area.body_entered.connect(_on_vine_body_entered.bind(platform_id))

	var vine := MeshInstance3D.new()
	vine.name = "Phase2VineVisual"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.16
	mesh.bottom_radius = 0.22
	mesh.height = 8.5
	mesh.material = _make_material(Color(0.18, 0.52, 0.16))
	vine.mesh = mesh
	vine.global_position = top + Vector3.UP * 5.8
	_world.add_child(vine)

func _update_rolling(platform_id: StringName, data: Dictionary, delta: float) -> void:
	var spin := data.get("spin") as Node3D
	var angular: float = float(data.get("angular_speed", 0.0))
	if spin != null:
		spin.rotation.z += angular * delta
	var area := data.get("area") as Area3D
	if area == null:
		return
	var right: Vector3 = data.get("right", Vector3.RIGHT)
	for body_value: Node3D in area.get_overlapping_bodies():
		var racer := body_value as WildDashCharacterController
		if not _is_valid_contact_racer(racer, area.global_position):
			continue
		var current: Vector3 = racer.get_knockback_velocity()
		var lateral: float = current.dot(right)
		var target_lateral: float = angular * 0.72 / get_stability_scale(racer)
		var adjusted := current + right * (target_lateral - lateral) * minf(1.0, delta * 4.2)
		racer.set("_knockback_velocity", adjusted)

func _update_balance(_platform_id: StringName, data: Dictionary, delta: float) -> void:
	var body := data.get("body") as AnimatableBody3D
	var area := data.get("area") as Area3D
	if body == null or area == null:
		return
	var right: Vector3 = data.get("right", Vector3.RIGHT)
	var weighted_side: float = 0.0
	var total_weight: float = 0.0
	for body_value: Node3D in area.get_overlapping_bodies():
		var racer := body_value as WildDashCharacterController
		if not _is_valid_contact_racer(racer, area.global_position):
			continue
		var side: float = clampf((racer.global_position - body.global_position).dot(right) / 6.0, -1.0, 1.0)
		var weight: float = get_weight_scale(racer)
		weighted_side += side * weight
		total_weight += weight
	var target_tilt: float = 0.0
	if total_weight > 0.01:
		target_tilt = clampf(weighted_side / maxf(1.0, total_weight) * 0.16, -0.16, 0.16)
	body.rotation.z = lerpf(body.rotation.z, target_tilt, minf(1.0, delta * 3.6))
	data["tilt"] = body.rotation.z
	_runtime[_platform_id] = data

func _update_cracking(platform_id: StringName, data: Dictionary, delta: float) -> void:
	var body := data.get("body") as AnimatableBody3D
	var area := data.get("area") as Area3D
	if body == null or area == null:
		return
	var state: StringName = data.get("state", &"SAFE")
	var usage: float = float(data.get("usage", 0.0))
	var timer: float = float(data.get("timer", 0.0))
	var material := data.get("material") as StandardMaterial3D

	if state == &"SAFE":
		var active_weight: float = 0.0
		for body_value: Node3D in area.get_overlapping_bodies():
			var racer := body_value as WildDashCharacterController
			if _is_valid_contact_racer(racer, area.global_position):
				active_weight += get_weight_scale(racer)
		if active_weight > 0.0:
			usage += delta * active_weight
		else:
			usage = maxf(0.0, usage - delta * 0.18)
		if usage >= CRACK_USAGE_TO_WARN:
			state = &"CRACKED"
			timer = 0.0
			if material != null:
				material.albedo_color = Color(0.67, 0.35, 0.10)
			_play_sfx_hook(SFX_WOOD_CRACK, "tree_break", 0.55)
			print("LOGSPIRE BREAK LOG platform=%s state=CRACKED usage=%.2f warning=%.2fs" % [platform_id, usage, CRACK_WARNING_SECONDS])
	elif state == &"CRACKED":
		timer += delta
		body.rotation.z = sin(timer * 28.0) * 0.035
		if timer >= CRACK_WARNING_SECONDS:
			state = &"BREAKING"
			timer = 0.0
			_play_sfx_hook(SFX_WOOD_BREAK, "tree_break", 0.78)
			print("LOGSPIRE BREAK LOG platform=%s state=BREAKING" % platform_id)
	elif state == &"BREAKING":
		timer += delta
		var t: float = clampf(timer / CRACK_BREAK_SECONDS, 0.0, 1.0)
		var base_position: Vector3 = data.get("base_position", body.global_position)
		body.global_position = base_position + Vector3.DOWN * (t * 4.5)
		body.rotation.z = t * 0.55
		if timer >= CRACK_BREAK_SECONDS:
			state = &"FALLEN"
			timer = 0.0
			body.collision_layer = 0
			body.visible = false
			print("LOGSPIRE BREAK LOG platform=%s state=FALLEN respawn=%.1fs" % [platform_id, CRACK_RESPAWN_SECONDS])
	elif state == &"FALLEN":
		timer += delta
		if timer >= CRACK_RESPAWN_SECONDS:
			state = &"RESPAWN"
			timer = 0.0
	elif state == &"RESPAWN":
		var base_position: Vector3 = data.get("base_position", body.global_position)
		var base_rotation: Vector3 = data.get("base_rotation", Vector3.ZERO)
		body.global_position = base_position
		body.rotation = base_rotation
		body.visible = true
		body.collision_layer = 1
		usage = 0.0
		state = &"SAFE"
		if material != null:
			material.albedo_color = Color(0.48, 0.31, 0.13)
		print("LOGSPIRE BREAK LOG platform=%s state=SAFE respawn_complete=true" % platform_id)

	data["state"] = state
	data["usage"] = usage
	data["timer"] = timer
	_runtime[platform_id] = data

func _update_swing(platform_id: StringName, data: Dictionary, delta: float) -> void:
	var body := data.get("body") as AnimatableBody3D
	var area := data.get("area") as Area3D
	if body == null or area == null:
		return
	var base_position: Vector3 = data.get("base_position", body.global_position)
	var previous: Vector3 = data.get("previous_position", body.global_position)
	var right: Vector3 = data.get("right", Vector3.RIGHT)
	var amplitude: float = float(data.get("amplitude", 3.0))
	var period: float = maxf(2.5, float(data.get("period", 4.5)))
	var phase: float = float(data.get("phase", 0.0))
	var time_seconds: float = Time.get_ticks_msec() * 0.001
	var offset: float = sin((time_seconds / period) * TAU + phase) * amplitude
	var target_position: Vector3 = base_position + right * offset
	body.global_position = target_position
	var velocity: Vector3 = (target_position - previous) / maxf(delta, 0.0001)
	data["previous_position"] = target_position
	data["velocity"] = velocity

	var current_riders: Dictionary = {}
	for body_value: Node3D in area.get_overlapping_bodies():
		var racer := body_value as WildDashCharacterController
		if not _is_valid_contact_racer(racer, area.global_position):
			continue
		current_riders[racer.get_instance_id()] = racer
	var previous_riders: Dictionary = data.get("previous_riders", {})
	for rider_id: Variant in previous_riders.keys():
		if current_riders.has(rider_id):
			continue
		var racer := previous_riders[rider_id] as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.is_on_floor():
			continue
		var impulse_value: Variant = racer.get("_skill_impulse_velocity")
		var impulse: Vector3 = impulse_value if impulse_value is Vector3 else Vector3.ZERO
		racer.set("_skill_impulse_velocity", impulse + velocity * 0.32)
	data["previous_riders"] = current_riders
	_runtime[platform_id] = data

func _on_mushroom_body_entered(body: Node3D, platform_id: StringName) -> void:
	var racer := body as WildDashCharacterController
	if not _can_launch(racer):
		return
	_set_launch_cooldown(racer)
	var forward: Vector3 = _platform_forward(platform_id, ROUTE_WILD)
	var bonus: float = 1.08 if racer.animal_id == &"rabbit" else 1.0
	var impulse_value: Variant = racer.get("_skill_impulse_velocity")
	var impulse: Vector3 = impulse_value if impulse_value is Vector3 else Vector3.ZERO
	racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * 1.32 * bonus)
	racer.current_speed = maxf(racer.current_speed, racer.max_speed * 1.08)
	racer.set("_skill_impulse_velocity", impulse + forward * 5.8)
	_orient_racer(racer, forward)
	_play_sfx_hook(SFX_MUSHROOM_BOUNCE, "jump", 0.82)
	_log_shortcut_once(racer, "mushroom")
	print("LOGSPIRE MUSHROOM BOUNCE racer=%s launch_y=%.2f forward=5.8" % [RaceManager.get_racer_label(racer), racer.velocity.y])

func _on_vine_body_entered(body: Node3D, platform_id: StringName) -> void:
	var racer := body as WildDashCharacterController
	if not _can_launch(racer):
		return
	_set_launch_cooldown(racer)
	var forward: Vector3 = _platform_forward(platform_id, ROUTE_WILD)
	var monkey_bonus: float = 1.10 if racer.animal_id == &"monkey" else 1.0
	var impulse_value: Variant = racer.get("_skill_impulse_velocity")
	var impulse: Vector3 = impulse_value if impulse_value is Vector3 else Vector3.ZERO
	racer.velocity.y = maxf(racer.velocity.y, racer.jump_velocity * 1.10 * monkey_bonus)
	racer.current_speed = maxf(racer.current_speed, racer.max_speed * 1.04)
	racer.set("_skill_impulse_velocity", impulse + forward * (7.2 * monkey_bonus))
	_orient_racer(racer, forward)
	racer.set_meta(&"logspire_vine_swing_until", Time.get_ticks_msec() + 420)
	_play_sfx_hook(SFX_VINE_SWING, "skill", 0.72)
	_log_shortcut_once(racer, "vine")
	print("LOGSPIRE VINE SWING racer=%s auto_attach=true scripted_release=true monkey_bonus=%.2f" % [
		RaceManager.get_racer_label(racer), monkey_bonus,
	])

func _log_shortcut_once(racer: WildDashCharacterController, source: String) -> void:
	if racer == null:
		return
	var id: int = racer.get_instance_id()
	if _shortcut_logged.has(id):
		return
	_shortcut_logged[id] = true
	print("LOGSPIRE SHORTCUT racer=%s route=wild source=%s design_saving=%.1fs" % [
		RaceManager.get_racer_label(racer), source, _design_shortcut_saving_seconds,
	])

func _can_launch(racer: WildDashCharacterController) -> bool:
	if racer == null or racer.finished or not RaceManager.active:
		return false
	return not _launch_cooldowns.has(racer.get_instance_id())

func _set_launch_cooldown(racer: WildDashCharacterController) -> void:
	_launch_cooldowns[racer.get_instance_id()] = LAUNCH_COOLDOWN_SECONDS

func _update_launch_cooldowns(delta: float) -> void:
	for id: Variant in _launch_cooldowns.keys():
		var remaining: float = float(_launch_cooldowns[id]) - delta
		if remaining <= 0.0:
			_launch_cooldowns.erase(id)
		else:
			_launch_cooldowns[id] = remaining

func _disable_original_platform(platform_id: StringName) -> void:
	if _world == null:
		return
	var root := _world.get_node_or_null(NodePath(String(platform_id))) as Node3D
	if root == null:
		push_warning("LOGSPIRE PHASE2 missing graybox platform=%s" % platform_id)
		return
	var mesh := root.get_node_or_null("Mesh") as MeshInstance3D
	if mesh != null:
		mesh.visible = false
	var collision_body := root.get_node_or_null("Collision") as StaticBody3D
	if collision_body != null:
		collision_body.collision_layer = 0
		for child: Node in collision_body.get_children():
			var shape := child as CollisionShape3D
			if shape != null:
				shape.set_deferred("disabled", true)

func _make_log_body(platform_id: StringName, radius: float, length: float, forward: Vector3) -> AnimatableBody3D:
	var top: Vector3 = _platform_top(platform_id)
	var body := AnimatableBody3D.new()
	body.name = "Phase2_%s" % String(platform_id)
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = true
	body.global_position = top - Vector3.UP * radius
	body.rotation.y = atan2(-forward.x, -forward.z)
	_world.add_child(body)

	var spin := Node3D.new()
	spin.name = "SpinVisual"
	body.add_child(spin)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "LogMesh"
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.material = _make_material(Color(0.42, 0.27, 0.11))
	mesh_instance.mesh = mesh
	mesh_instance.rotation.x = PI * 0.5
	spin.add_child(mesh_instance)

	var marker := MeshInstance3D.new()
	marker.name = "RollMarker"
	var marker_mesh := BoxMesh.new()
	marker_mesh.size = Vector3(0.42, 0.42, length * 0.92)
	marker_mesh.material = _make_material(Color(0.76, 0.48, 0.15))
	marker.mesh = marker_mesh
	marker.position = Vector3(radius * 0.78, 0.0, 0.0)
	spin.add_child(marker)

	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = length
	collision.shape = shape
	collision.rotation.x = PI * 0.5
	body.add_child(collision)
	return body

func _make_box_body(
	platform_id: StringName,
	size: Vector3,
	forward: Vector3,
	color: Color,
	material_override: StandardMaterial3D = null
) -> AnimatableBody3D:
	var top: Vector3 = _platform_top(platform_id)
	var body := AnimatableBody3D.new()
	body.name = "Phase2_%s" % String(platform_id)
	body.collision_layer = 1
	body.collision_mask = 0
	body.sync_to_physics = true
	body.global_position = top - Vector3.UP * (size.y * 0.5)
	body.rotation.y = atan2(-forward.x, -forward.z)
	_world.add_child(body)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Visual"
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material_override if material_override != null else _make_material(color)
	mesh_instance.mesh = mesh
	body.add_child(mesh_instance)

	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	return body

func _make_contact_area(body: AnimatableBody3D, radius: float, length: float) -> Area3D:
	var area := Area3D.new()
	area.name = "ContactArea"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.position = Vector3.UP * (radius + 0.55)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(radius * 2.3, 2.4, length)
	collision.shape = shape
	area.add_child(collision)
	body.add_child(area)
	return area

func _make_box_contact_area(body: AnimatableBody3D, size: Vector3) -> Area3D:
	var area := Area3D.new()
	area.name = "ContactArea"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	area.position = Vector3.UP * 1.15
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	body.add_child(area)
	return area

func _platform_top(platform_id: StringName) -> Vector3:
	var value: Variant = _world.call("get_platform_position", platform_id)
	return value if value is Vector3 else Vector3.ZERO

func _platform_forward(platform_id: StringName, route_id: StringName) -> Vector3:
	var value: Variant = _graph.call("get_platform_forward", platform_id, route_id)
	var forward: Vector3 = value if value is Vector3 else Vector3.FORWARD
	forward.y = 0.0
	return Vector3.FORWARD if forward.length_squared() <= 0.001 else forward.normalized()

func _right_from_forward(forward: Vector3) -> Vector3:
	var right := Vector3(-forward.z, 0.0, forward.x)
	return Vector3.RIGHT if right.length_squared() <= 0.001 else right.normalized()

func _is_valid_contact_racer(racer: WildDashCharacterController, contact_position: Vector3) -> bool:
	if racer == null or racer.finished:
		return false
	return absf(racer.global_position.y - contact_position.y) <= PLATFORM_CONTACT_VERTICAL

func _orient_racer(racer: WildDashCharacterController, forward: Vector3) -> void:
	if racer == null or forward.length_squared() <= 0.001:
		return
	var direction := forward.normalized()
	racer.rotation.y = atan2(-direction.x, -direction.z)

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.88
	return material

func _play_sfx_hook(preferred_id: String, fallback_id: String, volume: float) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var library_value: Variant = AudioManager.get("_sfx_library")
	if library_value is Dictionary:
		var library: Dictionary = library_value
		if library.has(preferred_id):
			AudioManager.play_sfx_id(preferred_id, volume)
			return
	AudioManager.play_sfx_id(fallback_id, volume)
