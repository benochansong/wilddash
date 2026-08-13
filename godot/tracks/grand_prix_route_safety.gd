class_name WildDashGrandPrixRouteSafety
extends Node

## Final RC9 safety pass for the Grand Prix route.
## This controller is deliberately separate from the visual guardrail system.
## It protects the two steep descent transitions and the tunnel with:
## 1) hidden StaticBody side walls,
## 2) below-road seam catch plates on steep elevation changes,
## 3) a final post-physics position containment/recovery pass.

const ROUTE_WIDTHS: Array[float] = [
	18.0, 18.0, 14.0, 14.0, 12.0, 8.0, 16.0, 14.0, 11.0, 10.0,
	18.0, 17.0, 18.0, 16.0, 10.0, 20.0, 18.0, 18.0, 22.0, 22.0,
	20.0, 15.0, 14.0, 13.0, 13.0, 12.0, 11.0, 12.0, 18.0,
]

# User playtests repeatedly escaped at the long downhill and tunnel. Keep this
# list focused so intentional shortcut openings are not sealed.
const PROTECTED_SEGMENTS: Array[int] = [11, 12, 13, 14, 25]
const DESCENT_SEAM_ROUTE_INDICES: Array[int] = [12, 13, 14]
const SIDES: Array[float] = [-1.0, 1.0]

const NORMAL_WALL_THICKNESS: float = 1.10
const NORMAL_WALL_HEIGHT: float = 3.60
const TUNNEL_WALL_THICKNESS: float = 1.80
const TUNNEL_WALL_HEIGHT: float = 8.50
const WALL_EDGE_OFFSET: float = 0.52
const WALL_LENGTH_EXTENSION: float = 2.0

const SEAM_CATCH_DEPTH: float = 0.70
const SEAM_CATCH_THICKNESS: float = 0.55
const SEAM_CATCH_LENGTH: float = 7.0

const LATERAL_PADDING: float = 0.32
const TUNNEL_LATERAL_PADDING: float = 0.58
const SEGMENT_END_MARGIN_METERS: float = 3.0
const TUNNEL_END_MARGIN_METERS: float = 9.0
const UNDER_ROAD_RECOVERY_DEPTH: float = 1.35
const RECOVERY_HEIGHT_OFFSET: float = 0.18
const SPEED_RETENTION_AFTER_RECOVERY: float = 0.86

var _track: WildDashGrandPrixTrack
var _route: Array[Vector3] = []
var _safety_root: Node3D
var _configured: bool = false
var _lateral_corrections: int = 0
var _floor_recoveries: int = 0

func _ready() -> void:
	# Run after RacingFeel (100), environment collision (120) and the legacy
	# tunnel failsafe (180). This is the last protection layer in the frame.
	process_priority = 240
	call_deferred("_configure_after_track_ready")

func _configure_after_track_ready() -> void:
	for _frame: int in range(5):
		await get_tree().physics_frame
	_track = _find_track()
	if _track == null:
		push_warning("RC9 GRAND PRIX ROUTE SAFETY: Grand Prix track not found")
		return
	_route = _track.get_route_points()
	if _route.size() != ROUTE_WIDTHS.size() + 1:
		push_warning("RC9 GRAND PRIX ROUTE SAFETY: route/width contract mismatch")
		return
	_build_hidden_safety_geometry()
	_configured = true
	print("RC9 GRAND PRIX ROUTE SAFETY READY protected_segments=%s descent_seams=%s priority=%d" % [
		str(PROTECTED_SEGMENTS), str(DESCENT_SEAM_ROUTE_INDICES), process_priority,
	])

func _physics_process(_delta: float) -> void:
	if not _configured or not RaceManager.active:
		return
	for candidate: Node3D in RaceManager.racers:
		if candidate is WildDashCharacterController:
			_enforce_route_safety(candidate as WildDashCharacterController)

func _build_hidden_safety_geometry() -> void:
	_safety_root = Node3D.new()
	_safety_root.name = "RC9GrandPrixRouteSafetyGeometry"
	add_child(_safety_root)

	for segment_index: int in PROTECTED_SEGMENTS:
		_build_segment_side_walls(segment_index)
	for route_index: int in DESCENT_SEAM_ROUTE_INDICES:
		_build_seam_catch_plate(route_index)

func _build_segment_side_walls(segment_index: int) -> void:
	if segment_index < 0 or segment_index + 1 >= _route.size():
		return
	var a: Vector3 = _route[segment_index]
	var b: Vector3 = _route[segment_index + 1]
	var delta: Vector3 = b - a
	var planar: Vector3 = Vector3(delta.x, 0.0, delta.z)
	if planar.length_squared() <= 0.001:
		return
	var direction: Vector3 = planar.normalized()
	var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var width: float = ROUTE_WIDTHS[segment_index]
	var segment_length: float = a.distance_to(b)
	var tunnel: bool = segment_index == 25
	var wall_thickness: float = TUNNEL_WALL_THICKNESS if tunnel else NORMAL_WALL_THICKNESS
	var wall_height: float = TUNNEL_WALL_HEIGHT if tunnel else NORMAL_WALL_HEIGHT
	var vertical_center: float = 2.15 if tunnel else 1.45
	var midpoint: Vector3 = (a + b) * 0.5

	for side: float in SIDES:
		var lateral_offset: Vector3 = right * side * (width * 0.5 + WALL_EDGE_OFFSET)
		var wall_center: Vector3 = midpoint + lateral_offset + Vector3.UP * vertical_center
		var wall_target: Vector3 = b + lateral_offset + Vector3.UP * vertical_center
		_add_static_box(
			"RouteWall_%02d_%s" % [segment_index, "L" if side < 0.0 else "R"],
			wall_center,
			wall_target,
			Vector3(wall_thickness, wall_height, segment_length + WALL_LENGTH_EXTENSION)
		)

func _build_seam_catch_plate(route_index: int) -> void:
	if route_index <= 0 or route_index >= _route.size() - 1:
		return
	var point: Vector3 = _route[route_index]
	var previous: Vector3 = _route[route_index - 1]
	var next: Vector3 = _route[route_index + 1]
	var planar_direction: Vector3 = next - previous
	planar_direction.y = 0.0
	if planar_direction.length_squared() <= 0.001:
		return
	planar_direction = planar_direction.normalized()
	var width_before: float = ROUTE_WIDTHS[route_index - 1]
	var width_after: float = ROUTE_WIDTHS[route_index]
	var catch_width: float = minf(width_before, width_after) + 1.0
	var catch_center: Vector3 = point + Vector3.DOWN * SEAM_CATCH_DEPTH
	var catch_target: Vector3 = catch_center + planar_direction * 5.0
	_add_static_box(
		"DescentSeamCatch_%02d" % route_index,
		catch_center,
		catch_target,
		Vector3(catch_width, SEAM_CATCH_THICKNESS, SEAM_CATCH_LENGTH)
	)

func _add_static_box(node_name: String, position: Vector3, look_target: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position
	_safety_root.add_child(body)
	body.look_at(look_target, Vector3.UP)
	var shape_node: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape_node.shape = box
	body.add_child(shape_node)

func _enforce_route_safety(racer: WildDashCharacterController) -> void:
	if racer == null or racer.finished:
		return
	var best_segment: int = -1
	var best_t: float = 0.0
	var best_planar_distance: float = INF

	for segment_index: int in PROTECTED_SEGMENTS:
		var sample: Dictionary = _sample_segment(racer.global_position, segment_index)
		if not bool(sample.get("eligible", false)):
			continue
		var planar_distance: float = float(sample.get("planar_distance", INF))
		if planar_distance < best_planar_distance:
			best_planar_distance = planar_distance
			best_segment = segment_index
			best_t = float(sample.get("t", 0.0))

	if best_segment < 0:
		return
	var width: float = ROUTE_WIDTHS[best_segment]
	if best_planar_distance > width * 0.5 + 4.0:
		return

	var a: Vector3 = _route[best_segment]
	var b: Vector3 = _route[best_segment + 1]
	var centerline: Vector3 = a.lerp(b, best_t)
	var planar: Vector3 = b - a
	planar.y = 0.0
	if planar.length_squared() <= 0.001:
		return
	var direction: Vector3 = planar.normalized()
	var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var lateral: float = (racer.global_position - centerline).dot(right)
	var radius: float = _collision_radius(racer)
	var padding: float = TUNNEL_LATERAL_PADDING if best_segment == 25 else LATERAL_PADDING
	var allowed: float = maxf(1.0, width * 0.5 - radius - padding)

	if absf(lateral) > allowed:
		var side: float = signf(lateral)
		var corrected_lateral: float = side * allowed
		var correction: Vector3 = right * (lateral - corrected_lateral)
		racer.global_position -= correction
		racer.global_position -= right * side * 0.08
		var outward: Vector3 = right * side
		var outward_velocity: float = racer.velocity.dot(outward)
		if outward_velocity > 0.0:
			racer.velocity -= outward * outward_velocity
		_apply_recovery_speed(racer)
		racer.reset_physics_interpolation()
		_lateral_corrections += 1
		if _lateral_corrections <= 16 or OS.has_environment("WILDDASH_DEBUG_COLLISION"):
			print("RC9 ROUTE LATERAL BLOCK racer=%s segment=%d lateral=%.2f allowed=%.2f count=%d" % [
				racer.name, best_segment, lateral, allowed, _lateral_corrections,
			])

	# Catch a racer that slipped through a sloped road seam. Only positions below
	# the expected road plane are corrected; normal jumps above the road remain free.
	var expected_road_y: float = lerpf(a.y, b.y, best_t)
	if racer.global_position.y < expected_road_y - UNDER_ROAD_RECOVERY_DEPTH:
		var current_lateral: float = (racer.global_position - centerline).dot(right)
		if absf(current_lateral) <= width * 0.5 + 1.2:
			racer.global_position.y = expected_road_y + RECOVERY_HEIGHT_OFFSET
			if racer.velocity.y < 0.0:
				racer.velocity.y = 0.0
			_apply_recovery_speed(racer)
			racer.reset_physics_interpolation()
			_floor_recoveries += 1
			if _floor_recoveries <= 12 or OS.has_environment("WILDDASH_DEBUG_COLLISION"):
				print("RC9 ROUTE FLOOR RECOVERY racer=%s segment=%d road_y=%.2f recovered_y=%.2f count=%d" % [
					racer.name, best_segment, expected_road_y, racer.global_position.y, _floor_recoveries,
				])

func _sample_segment(world_position: Vector3, segment_index: int) -> Dictionary:
	if segment_index < 0 or segment_index + 1 >= _route.size():
		return {"eligible": false}
	var a: Vector3 = _route[segment_index]
	var b: Vector3 = _route[segment_index + 1]
	var a2: Vector2 = Vector2(a.x, a.z)
	var b2: Vector2 = Vector2(b.x, b.z)
	var p2: Vector2 = Vector2(world_position.x, world_position.z)
	var ab2: Vector2 = b2 - a2
	var length_squared: float = ab2.length_squared()
	if length_squared <= 0.001:
		return {"eligible": false}
	var raw_t: float = (p2 - a2).dot(ab2) / length_squared
	var segment_length: float = sqrt(length_squared)
	var margin_meters: float = TUNNEL_END_MARGIN_METERS if segment_index == 25 else SEGMENT_END_MARGIN_METERS
	var margin_t: float = margin_meters / maxf(0.01, segment_length)
	if raw_t < -margin_t or raw_t > 1.0 + margin_t:
		return {"eligible": false}
	var t: float = clampf(raw_t, 0.0, 1.0)
	var closest: Vector2 = a2.lerp(b2, t)
	var distance: float = p2.distance_to(closest)
	return {
		"eligible": true,
		"t": t,
		"planar_distance": distance,
	}

func _collision_radius(racer: WildDashCharacterController) -> float:
	var shape_node: CollisionShape3D = racer.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape_node != null and shape_node.shape is CapsuleShape3D:
		return (shape_node.shape as CapsuleShape3D).radius
	return 0.62

func _apply_recovery_speed(racer: WildDashCharacterController) -> void:
	var cap: float = maxf(racer.cruise_speed, racer.max_speed * SPEED_RETENTION_AFTER_RECOVERY)
	racer.current_speed = minf(racer.current_speed, cap)

func _find_track() -> WildDashGrandPrixTrack:
	var parent: Node = get_parent()
	if parent == null:
		return null
	for child: Node in parent.get_children():
		if child is WildDashGrandPrixTrack:
			return child as WildDashGrandPrixTrack
	return null
