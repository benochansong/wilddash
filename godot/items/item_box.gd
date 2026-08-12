class_name WildDashItemBox
extends Area3D

const AI_PICKUP_RADIUS := 3.3
const PLAYER_PICKUP_RADIUS := 4.4
const PLAYER_PICKUP_BONUS := 0.75
const PLAYER_VERTICAL_TOLERANCE := 3.4
const PLAYER_SCAN_INTERVAL := 0.025
const AI_SCAN_INTERVAL := 0.10
const PLAYER_REPICKUP_COOLDOWN_MSEC := 320
const PICKUP_LOCK_META: StringName = &"wilddash_item_box_pickup_until_msec"

@export var respawn_seconds := 5.0

var _active := true
var _visual_root: Node3D
var _collision: CollisionShape3D
var _time := 0.0
var _player_scan_elapsed := 0.0
var _ai_scan_elapsed := 0.0
var _previous_probe_positions: Dictionary = {}

func _ready() -> void:
	add_to_group("wilddash_item_box")
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	monitorable = true
	_build_visual()
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	_time += delta
	if _visual_root != null and _active:
		_visual_root.rotation.y += delta * 1.9
		_visual_root.position.y = sin(_time * 2.6) * 0.22

func _physics_process(delta: float) -> void:
	if not _active:
		return
	_player_scan_elapsed += delta
	_ai_scan_elapsed += delta
	var scan_player := _player_scan_elapsed >= PLAYER_SCAN_INTERVAL
	var scan_ai := _ai_scan_elapsed >= AI_SCAN_INTERVAL
	if not scan_player and not scan_ai:
		return
	if scan_player:
		_player_scan_elapsed = 0.0
	if scan_ai:
		_ai_scan_elapsed = 0.0

	for racer in RaceManager.racers:
		if racer == null or not is_instance_valid(racer) or RaceManager.finish_order.has(racer):
			continue
		var is_human_player := _is_human_player(racer)
		if is_human_player and not scan_player:
			continue
		if not is_human_player and not scan_ai:
			continue

		var probe_position := racer.global_position + Vector3.UP * 0.8
		var pickup_radius := PLAYER_PICKUP_RADIUS if is_human_player else AI_PICKUP_RADIUS
		if racer.has_method("get_interaction_radius"):
			pickup_radius = float(racer.call("get_interaction_radius", pickup_radius))
		pickup_radius = ItemSystem.get_pickup_radius(racer, pickup_radius)

		if is_human_player:
			pickup_radius += PLAYER_PICKUP_BONUS
			var racer_id := racer.get_instance_id()
			var previous_probe: Vector3 = _previous_probe_positions.get(racer_id, probe_position)
			_previous_probe_positions[racer_id] = probe_position
			# Use horizontal swept pickup plus a separate vertical tolerance. This
			# catches fast crossings on slopes/ice without allowing a box on an
			# overpass several metres above/below the racer to be collected.
			if _player_swept_pickup_hit(global_position, previous_probe, probe_position, pickup_radius):
				if _try_pickup(racer):
					return
		elif global_position.distance_to(probe_position) <= pickup_radius:
			# Preserve the original AI cadence/radius and one-slot behaviour. The
			# high-frequency swept forgiveness and replacement behaviour are kept
			# player-only so AI combat density and balance do not inflate.
			if _try_pickup(racer):
				return

func force_pickup(racer: Node) -> bool:
	return _try_pickup(racer)

func is_active() -> bool:
	return _active

func _on_body_entered(body: Node) -> void:
	_try_pickup(body)

func _try_pickup(body: Node) -> bool:
	if not _active or body == null or not body.has_method("get_held_item") or not body.has_method("set_held_item"):
		return false

	var is_human_player := _is_human_player(body)
	if is_human_player and _player_pickup_locked(body):
		return false

	var previous_item := StringName(body.call("get_held_item"))
	var replaced_existing := false
	if previous_item != &"":
		# Human racing should always get a clear response from driving through a
		# box. Refresh the one-slot inventory instead of silently ignoring the
		# pickup. AI retains the original no-replacement rule.
		if not is_human_player:
			return false
		body.call("set_held_item", &"")
		replaced_existing = true

	if not ItemSystem.grant_weighted_item(body):
		if replaced_existing:
			body.call("set_held_item", previous_item)
		return false

	if is_human_player:
		body.set_meta(PICKUP_LOCK_META, Time.get_ticks_msec() + PLAYER_REPICKUP_COOLDOWN_MSEC)

	var item_id := StringName(body.call("get_held_item"))
	print("ITEM BOX PICKUP racer=%s item=%s rank=%d replaced=%s" % [
		RaceManager.get_racer_label(body) if body is Node3D else body.name,
		ItemSystem.get_display_name(item_id),
		RaceManager.get_rank(body) if body is Node3D else 0,
		str(replaced_existing),
	])
	_deactivate()
	return true

func _player_pickup_locked(body: Node) -> bool:
	var until_msec := int(body.get_meta(PICKUP_LOCK_META, 0))
	return Time.get_ticks_msec() < until_msec

func _is_human_player(body: Node) -> bool:
	return body is WildDashCharacterController and (body as WildDashCharacterController).is_player

func _deactivate() -> void:
	if not _active:
		return
	_active = false
	_previous_probe_positions.clear()
	set_deferred("monitoring", false)
	if _collision != null:
		_collision.set_deferred("disabled", true)
	if _visual_root != null:
		_visual_root.visible = false
	_respawn_later()

func _respawn_later() -> void:
	await get_tree().create_timer(respawn_seconds).timeout
	if not is_inside_tree():
		return
	_active = true
	_previous_probe_positions.clear()
	monitoring = true
	if _collision != null:
		_collision.disabled = false
	if _visual_root != null:
		_visual_root.visible = true
	call_deferred("_try_overlapping_pickup")

func _try_overlapping_pickup() -> void:
	if not _active or not monitoring:
		return
	for body in get_overlapping_bodies():
		if _try_pickup(body):
			return

func _player_swept_pickup_hit(point: Vector3, a: Vector3, b: Vector3, radius: float) -> bool:
	var point_xz := Vector2(point.x, point.z)
	var a_xz := Vector2(a.x, a.z)
	var b_xz := Vector2(b.x, b.z)
	var segment := b_xz - a_xz
	var length_squared := segment.length_squared()
	var t := 1.0
	if length_squared > 0.0001:
		t = clampf((point_xz - a_xz).dot(segment) / length_squared, 0.0, 1.0)
	var closest_xz := a_xz.lerp(b_xz, t)
	if point_xz.distance_to(closest_xz) > radius:
		return false
	var closest_y := lerpf(a.y, b.y, t)
	return absf(point.y - closest_y) <= PLAYER_VERTICAL_TOLERANCE

func _build_visual() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "Visual"
	add_child(_visual_root)

	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.45, 1.45, 1.45)
	mesh_instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.96, 0.78, 0.16)
	material.emission_enabled = true
	material.emission = Color(0.24, 0.18, 0.02)
	material.emission_energy_multiplier = 1.6
	material.metallic = 0.18
	material.roughness = 0.35
	mesh_instance.material_override = material
	_visual_root.add_child(mesh_instance)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.76
	torus.outer_radius = 0.92
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.2, 0.86, 1.0)
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.05, 0.35, 0.55)
	ring_material.emission_energy_multiplier = 2.0
	ring.material_override = ring_material
	_visual_root.add_child(ring)

	_collision = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.0
	_collision.shape = shape
	add_child(_collision)
