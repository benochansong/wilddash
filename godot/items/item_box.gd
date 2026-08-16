class_name WildDashItemBox
extends Area3D

## RC9 yellow-box pickup hotfix.
## Player pickup never depends on RaceManager registration timing: the player is
## resolved directly from the wilddash_racer group every physics tick. AI still
## uses the shared race roster on a throttled scan. A successful pickup hides the
## box immediately, defers collision-state changes safely, then respawns it.

const AI_RADIUS := 3.45
const PLAYER_RADIUS := 5.50
const PLAYER_FALLBACK := 0.65
const AI_FALLBACK := 0.35
const PLAYER_VERTICAL := 3.80
const AI_VERTICAL := 3.10
const AI_SCAN_INTERVAL := 0.08
const GLOBAL_LOCK_MSEC := 300
const SAME_BOX_LOCK_MSEC := 2200
const DENIED_LOG_MSEC := 350
const PICKUP_LOCK_META: StringName = &"wilddash_item_box_pickup_until_msec"

@export var respawn_seconds := 5.0

var _active := true
var _visual: Node3D
var _collision: CollisionShape3D
var _ai_elapsed := 0.0
var _time := 0.0
var _previous_probe: Dictionary = {}
var _same_box_until: Dictionary = {}
var _denied_until: Dictionary = {}

func _ready() -> void:
	add_to_group("wilddash_item_box")
	collision_layer = 4
	collision_mask = 2
	monitoring = true
	monitorable = true
	_build_visual()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	print("YELLOW ITEM BOX READY box=%s player_direct_scan=true detectors=body+swept+proximity disappear_on_success=true radius=%.2f" % [
		name, PLAYER_RADIUS + PLAYER_FALLBACK,
	])

func _process(delta: float) -> void:
	_time += delta
	if _visual != null and _active:
		_visual.rotation.y += delta * 1.9
		_visual.position.y = sin(_time * 2.6) * 0.22

func _physics_process(delta: float) -> void:
	if not _active:
		return

	# P0 guarantee: scan the human racer directly from the racer group every
	# physics tick. This does not rely on RaceManager.racers being populated yet.
	var player_racer := _resolve_player_racer()
	if player_racer != null and _scan_racer(player_racer, true):
		return

	_ai_elapsed += delta
	if _ai_elapsed < AI_SCAN_INTERVAL:
		return
	_ai_elapsed = 0.0
	for value: Variant in RaceManager.racers:
		var racer := value as WildDashCharacterController
		if racer == null or not is_instance_valid(racer) or racer.is_player:
			continue
		if _scan_racer(racer, false):
			return

func _scan_racer(racer: WildDashCharacterController, human: bool) -> bool:
	if racer == null or not is_instance_valid(racer) or racer.finished:
		return false
	if RaceManager.finish_order.has(racer):
		return false

	var probe := racer.global_position + Vector3.UP * 0.8
	var id := racer.get_instance_id()
	var previous: Vector3 = _previous_probe.get(id, probe)
	_previous_probe[id] = probe
	var radius := PLAYER_RADIUS if human else AI_RADIUS
	if racer.has_method("get_interaction_radius"):
		radius = float(racer.call("get_interaction_radius", radius))
	radius = ItemSystem.get_pickup_radius(racer, radius)
	var vertical := PLAYER_VERTICAL if human else AI_VERTICAL
	var fallback := PLAYER_FALLBACK if human else AI_FALLBACK
	var swept := _swept_hit(global_position, previous, probe, radius, vertical)
	var proximity := _proximity_hit(global_position, probe, radius + fallback, vertical)
	var overlap := overlaps_body(racer)
	if not swept and not proximity and not overlap:
		return false
	return _try_pickup_context(racer, "player_direct_scan" if human else "ai_scan", swept, overlap, proximity)

func _resolve_player_racer() -> WildDashCharacterController:
	for node: Node in get_tree().get_nodes_in_group("wilddash_racer"):
		var racer := node as WildDashCharacterController
		if racer == null or not is_instance_valid(racer):
			continue
		if racer.is_player and racer.movement_mode == WildDashCharacterController.MovementMode.RACE and not racer.finished:
			return racer
	return null

func force_pickup(racer: Node) -> bool:
	return _try_pickup_context(racer, "force", false, false, true)

func is_active() -> bool:
	return _active

func _on_body_entered(body: Node) -> void:
	_try_pickup_context(body, "body_entered", false, true, false)

func _try_pickup(body: Node) -> bool:
	return _try_pickup_context(body, "legacy_call", false, false, false)

func _try_pickup_context(body: Node, trigger: String, swept: bool, overlap: bool, proximity: bool) -> bool:
	if not _active:
		_log_denied(body, "INACTIVE", trigger)
		return false
	if body == null or not body.has_method("get_held_item") or not body.has_method("set_held_item"):
		_log_denied(body, "INVALID_RACER", trigger)
		return false
	if body is WildDashCharacterController:
		var racer := body as WildDashCharacterController
		print("ITEM PICKUP ATTEMPT box=%s racer=%s trigger=%s distance=%.2f swept=%s overlap=%s proximity=%s held_item=%s" % [
			name,
			_label(racer),
			trigger,
			global_position.distance_to(racer.global_position + Vector3.UP * 0.8),
			str(swept),
			str(overlap),
			str(proximity),
			String(racer.get_held_item()),
		])
	if _is_party_racer(body):
		return _try_party_pickup(body as WildDashCharacterController, trigger)
	return _try_legacy_pickup(body, trigger)

func _try_party_pickup(racer: WildDashCharacterController, trigger: String) -> bool:
	if racer == null:
		return false
	if racer.finished or RaceManager.finish_order.has(racer):
		_log_denied(racer, "FINISHED", trigger)
		return false
	var now := Time.get_ticks_msec()
	var id := racer.get_instance_id()
	if now < int(_same_box_until.get(id, 0)):
		_log_denied(racer, "COOLDOWN_SAME_BOX", trigger)
		return false
	if now < int(racer.get_meta(PICKUP_LOCK_META, 0)):
		_log_denied(racer, "COOLDOWN_GLOBAL", trigger)
		return false

	var previous := racer.get_held_item()
	var replaced := false
	if previous != &"":
		if not racer.is_player:
			_log_denied(racer, "HELD_ITEM_AI", trigger)
			return false
		# RC9 player guarantee: a stale/held item must never make a yellow box look
		# broken. Replace it atomically and restore it if the new grant fails.
		racer.set_held_item(&"")
		replaced = true

	if not ItemSystem.grant_weighted_item(racer):
		if replaced:
			racer.set_held_item(previous)
		_log_denied(racer, "GRANT_FAILED", trigger)
		return false

	racer.set_meta(PICKUP_LOCK_META, now + GLOBAL_LOCK_MSEC)
	_same_box_until[id] = now + SAME_BOX_LOCK_MSEC
	_success(racer, replaced, trigger)
	_deactivate()
	return true

func _try_legacy_pickup(body: Node, trigger: String) -> bool:
	var human := body is WildDashCharacterController and (body as WildDashCharacterController).is_player
	if human and Time.get_ticks_msec() < int(body.get_meta(PICKUP_LOCK_META, 0)):
		_log_denied(body, "COOLDOWN_GLOBAL", trigger)
		return false
	var previous := StringName(body.call("get_held_item"))
	var replaced := false
	if previous != &"":
		if not human:
			_log_denied(body, "HELD_ITEM_AI", trigger)
			return false
		body.call("set_held_item", &"")
		replaced = true
	if not ItemSystem.grant_weighted_item(body):
		if replaced:
			body.call("set_held_item", previous)
		_log_denied(body, "GRANT_FAILED", trigger)
		return false
	if human:
		body.set_meta(PICKUP_LOCK_META, Time.get_ticks_msec() + GLOBAL_LOCK_MSEC)
	if body is WildDashCharacterController:
		_success(body as WildDashCharacterController, replaced, trigger)
	_deactivate()
	return true

func _success(racer: WildDashCharacterController, replaced: bool, trigger: String) -> void:
	print("ITEM PICKUP SUCCESS box=%s racer=%s item=%s rank=%d replaced=%s trigger=%s disappear=true" % [
		name,
		_label(racer),
		ItemSystem.get_display_name(racer.get_held_item()),
		RaceManager.get_rank(racer),
		str(replaced),
		trigger,
	])
	var audio := get_node_or_null("/root/AudioManager")
	if audio != null:
		audio.call("play_sfx_id", "item", 0.88)

func _log_denied(body: Node, reason: String, trigger: String) -> void:
	var now := Time.get_ticks_msec()
	var id := body.get_instance_id() if body != null else -1
	var key := "%d:%s" % [id, reason]
	if now < int(_denied_until.get(key, 0)):
		return
	_denied_until[key] = now + DENIED_LOG_MSEC
	var held := ""
	if body != null and body.has_method("get_held_item"):
		held = String(body.call("get_held_item"))
	print("ITEM PICKUP DENIED box=%s racer=%s reason=%s trigger=%s held_item=%s" % [
		name, _label(body), reason, trigger, held,
	])

func _is_party_racer(body: Node) -> bool:
	return body is WildDashCharacterController and (body as WildDashCharacterController).movement_mode == WildDashCharacterController.MovementMode.RACE

func _label(body: Node) -> String:
	if body == null:
		return "NULL"
	if body is Node3D and RaceManager.racers.has(body):
		return RaceManager.get_racer_label(body)
	return body.name

func _deactivate() -> void:
	if not _active:
		return
	_active = false
	if _visual != null:
		_visual.visible = false
	# Never mutate physics-query state directly from body_entered/physics scan.
	# Deferred toggles avoid Godot's flushing-queries state-change error.
	set_deferred("monitoring", false)
	if _collision != null:
		_collision.set_deferred("disabled", true)
	_respawn_later()

func _respawn_later() -> void:
	await get_tree().create_timer(respawn_seconds).timeout
	if not is_inside_tree():
		return
	_active = true
	_previous_probe.clear()
	set_deferred("monitoring", true)
	if _collision != null:
		_collision.set_deferred("disabled", false)
	if _visual != null:
		_visual.visible = true
	print("ITEM BOX RESPAWN box=%s seconds=%.1f" % [name, respawn_seconds])

func _swept_hit(point: Vector3, a: Vector3, b: Vector3, radius: float, vertical: float) -> bool:
	var p := Vector2(point.x, point.z)
	var av := Vector2(a.x, a.z)
	var bv := Vector2(b.x, b.z)
	var segment := bv - av
	var length_sq := segment.length_squared()
	var t := clampf((p - av).dot(segment) / length_sq, 0.0, 1.0) if length_sq > 0.0001 else 1.0
	var closest := av.lerp(bv, t)
	return p.distance_to(closest) <= radius and absf(point.y - lerpf(a.y, b.y, t)) <= vertical

func _proximity_hit(point: Vector3, probe: Vector3, radius: float, vertical: float) -> bool:
	return absf(point.y - probe.y) <= vertical and Vector2(point.x, point.z).distance_to(Vector2(probe.x, probe.z)) <= radius

func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	var cube := MeshInstance3D.new()
	var cube_mesh := BoxMesh.new()
	cube_mesh.size = Vector3(1.45, 1.45, 1.45)
	cube.mesh = cube_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.96, 0.78, 0.16)
	material.emission_enabled = true
	material.emission = Color(0.24, 0.18, 0.02)
	material.emission_energy_multiplier = 1.6
	cube.material_override = material
	_visual.add_child(cube)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.76
	torus.outer_radius = 0.92
	ring.mesh = torus
	ring.rotation_degrees.x = 90.0
	ring.material_override = material
	_visual.add_child(ring)
	_collision = CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 2.35
	_collision.shape = shape
	add_child(_collision)
