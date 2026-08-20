class_name WildDashGrandPrixTunnelFailsafe
extends Node

const TUNNEL_START_ROUTE_INDEX := 25
const TUNNEL_END_ROUTE_INDEX := 26
const TUNNEL_HALF_WIDTH := 6.0
const ENTRY_EXTENSION_METERS := 7.0
const EXIT_EXTENSION_METERS := 7.0
const EDGE_PADDING := 0.48
const HARD_WALL_THICKNESS := 1.60
const HARD_WALL_HEIGHT := 8.0
const HARD_ROOF_THICKNESS := 1.20
const HARD_ROOF_HEIGHT := 5.0
const SPEED_RETENTION_ON_CORRECTION := 0.88
const TUNNEL_SIDES: Array[float] = [-1.0, 1.0]

var _a: Vector3 = Vector3.ZERO
var _b: Vector3 = Vector3.ZERO
var _planar_direction: Vector3 = Vector3.ZERO
var _right: Vector3 = Vector3.ZERO
var _planar_length: float = 0.0
var _configured: bool = false
var _corrections: int = 0
var _hard_shell_root: Node3D

func _ready() -> void:
	# RacingFeelController runs at 100 and the environment collision controller
	# at 120. Keep this final pass after both.
	process_priority = 180
	call_deferred("_configure_after_track_ready")

func _configure_after_track_ready() -> void:
	for _frame in range(5):
		await get_tree().physics_frame
	var track: WildDashGrandPrixTrack = _find_grand_prix_track()
	if track == null:
		push_warning("RC9 TUNNEL CONTAINMENT: Grand Prix track not found")
		return
	var route: Array[Vector3] = track.get_route_points()
	if route.size() <= TUNNEL_END_ROUTE_INDEX:
		push_warning("RC9 TUNNEL CONTAINMENT: route does not contain tunnel indices")
		return
	_a = route[TUNNEL_START_ROUTE_INDEX]
	_b = route[TUNNEL_END_ROUTE_INDEX]
	var planar: Vector3 = _b - _a
	planar.y = 0.0
	_planar_length = planar.length()
	if _planar_length <= 0.01:
		push_warning("RC9 TUNNEL CONTAINMENT: tunnel segment has no planar length")
		return
	_planar_direction = planar / _planar_length
	_right = Vector3(-_planar_direction.z, 0.0, _planar_direction.x)
	_build_hard_shell()
	_configured = true
	print("RC9 TUNNEL HARD CONTAINMENT READY length=%.1f half_width=%.2f wall_thickness=%.2f entry=%.1f exit=%.1f" % [
		_planar_length, TUNNEL_HALF_WIDTH, HARD_WALL_THICKNESS,
		ENTRY_EXTENSION_METERS, EXIT_EXTENSION_METERS,
	])

func _physics_process(_delta: float) -> void:
	if not _configured or not RaceManager.active:
		return
	for candidate in RaceManager.racers:
		if candidate is WildDashCharacterController:
			_enforce_corridor(candidate as WildDashCharacterController)

func _build_hard_shell() -> void:
	if _hard_shell_root != null:
		_hard_shell_root.queue_free()
	_hard_shell_root = Node3D.new()
	_hard_shell_root.name = "RC9TunnelHardShell"
	add_child(_hard_shell_root)

	var slope_direction: Vector3 = (_b - _a).normalized()
	var extended_a: Vector3 = _a - slope_direction * ENTRY_EXTENSION_METERS
	var extended_b: Vector3 = _b + slope_direction * EXIT_EXTENSION_METERS
	var shell_length: float = extended_a.distance_to(extended_b)
	var midpoint: Vector3 = (extended_a + extended_b) * 0.5

	for side in TUNNEL_SIDES:
		var wall_center: Vector3 = midpoint + _right * TUNNEL_HALF_WIDTH * side + Vector3.UP * 2.0
		var wall_target: Vector3 = extended_b + _right * TUNNEL_HALF_WIDTH * side + Vector3.UP * 2.0
		_add_static_box(
			"HardWall_%s" % ("L" if side < 0.0 else "R"),
			wall_center,
			wall_target,
			Vector3(HARD_WALL_THICKNESS, HARD_WALL_HEIGHT, shell_length)
		)

	_add_static_box(
		"HardRoof",
		midpoint + Vector3.UP * HARD_ROOF_HEIGHT,
		extended_b + Vector3.UP * HARD_ROOF_HEIGHT,
		Vector3(TUNNEL_HALF_WIDTH * 2.0 + HARD_WALL_THICKNESS, HARD_ROOF_THICKNESS, shell_length)
	)

func _add_static_box(node_name: String, position: Vector3, look_target: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position
	_hard_shell_root.add_child(body)
	body.look_at(look_target, Vector3.UP)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)

func _enforce_corridor(racer: WildDashCharacterController) -> void:
	if racer == null or racer.finished:
		return
	var from_start: Vector3 = racer.global_position - _a
	var planar_from_start: Vector3 = Vector3(from_start.x, 0.0, from_start.z)
	var longitudinal: float = planar_from_start.dot(_planar_direction)
	if longitudinal < -ENTRY_EXTENSION_METERS or longitudinal > _planar_length + EXIT_EXTENSION_METERS:
		return

	var center_longitudinal: float = clampf(longitudinal, 0.0, _planar_length)
	var center_t: float = center_longitudinal / maxf(0.01, _planar_length)
	var centerline: Vector3 = Vector3(
		_a.x + _planar_direction.x * center_longitudinal,
		lerpf(_a.y, _b.y, center_t),
		_a.z + _planar_direction.z * center_longitudinal
	)
	if absf(racer.global_position.y - centerline.y) > 7.5:
		return

	var lateral: float = (racer.global_position - centerline).dot(_right)
	var allowed: float = maxf(1.0, TUNNEL_HALF_WIDTH - _collision_radius(racer) - EDGE_PADDING)
	if absf(lateral) <= allowed:
		return

	var side: float = signf(lateral)
	var corrected_lateral: float = side * allowed
	var corrected: Vector3 = racer.global_position - _right * (lateral - corrected_lateral)
	# Place a tiny extra margin inside so the next physics tick starts cleanly
	# away from the collision plane rather than exactly touching it.
	corrected -= _right * side * 0.08
	racer.global_position = corrected
	racer.reset_physics_interpolation()

	var outward: Vector3 = _right * side
	var outward_velocity: float = racer.velocity.dot(outward)
	if outward_velocity > 0.0:
		racer.velocity -= outward * outward_velocity
	var max_after_correction: float = maxf(racer.cruise_speed, racer.max_speed * SPEED_RETENTION_ON_CORRECTION)
	racer.current_speed = minf(racer.current_speed, max_after_correction)
	_corrections += 1
	if _corrections <= 12 or OS.has_environment("WILDDASH_DEBUG_COLLISION"):
		print("RC9 TUNNEL CONTAINMENT BLOCK racer=%s lateral=%.2f allowed=%.2f corrected=true count=%d" % [
			racer.name, lateral, allowed, _corrections,
		])

func _collision_radius(racer: WildDashCharacterController) -> float:
	var shape: CollisionShape3D = racer.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null and shape.shape is CapsuleShape3D:
		return (shape.shape as CapsuleShape3D).radius
	return 0.62

func _find_grand_prix_track() -> WildDashGrandPrixTrack:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is WildDashGrandPrixTrack:
			return child as WildDashGrandPrixTrack
	return null
