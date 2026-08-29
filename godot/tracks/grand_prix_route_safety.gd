class_name WildDashGrandPrixRouteSafety
extends Node

## RC9 Grand Prix route safety V3.
## The visible road is still the primary collision surface. This final layer:
## - adds thick overlapping hidden floors under all 29 main-route segments,
## - tracks the active segment from RaceManager progress instead of nearest X/Z,
## - remembers each racer's last trustworthy road position,
## - immediately recovers even shallow under-road penetration (~10 cm),
## - keeps focused lateral containment at downhill/tunnel danger sections.

const ROUTE_WIDTHS: Array[float] = [
	18.0, 18.0, 14.0, 14.0, 12.0, 8.0, 16.0, 14.0, 11.0, 10.0,
	18.0, 17.0, 18.0, 16.0, 10.0, 20.0, 18.0, 18.0, 22.0, 22.0,
	20.0, 15.0, 14.0, 13.0, 13.0, 12.0, 11.0, 12.0, 18.0,
]

const LATERAL_PROTECTED_SEGMENTS: Array[int] = [11, 12, 13, 14, 15, 25, 26]
const SIDES: Array[float] = [-1.0, 1.0]

const NORMAL_WALL_THICKNESS: float = 1.20
const NORMAL_WALL_HEIGHT: float = 4.00
const TUNNEL_WALL_THICKNESS: float = 2.20
const TUNNEL_WALL_HEIGHT: float = 9.50
const WALL_EDGE_OFFSET: float = 0.46
const WALL_LENGTH_EXTENSION: float = 4.0

const UNDERLAY_DEPTH: float = 0.90
const UNDERLAY_THICKNESS: float = 1.50
const UNDERLAY_WIDTH_EXTRA: float = 1.50
const UNDERLAY_LENGTH_EXTENSION: float = 5.00

const SEAM_CATCH_DEPTH: float = 0.62
const SEAM_CATCH_THICKNESS: float = 1.05
const SEAM_CATCH_LENGTH: float = 8.00
const SEAM_CATCH_WIDTH_EXTRA: float = 1.80

const ROAD_TOP_OFFSET: float = 0.03
const FLOOR_PENETRATION_LIMIT: float = 0.10
const DEEP_RECOVERY_DEPTH: float = 1.20
const RECOVERY_HEIGHT_OFFSET: float = 0.10
const FLOOR_RECOVERY_LATERAL_EXTRA: float = 2.00
const LATERAL_PADDING: float = 0.30
const TUNNEL_LATERAL_PADDING: float = 0.68
const SPEED_RETENTION_AFTER_RECOVERY: float = 0.82
const FLOOR_SNAP_MINIMUM: float = 0.75
const SAFE_MARGIN_MINIMUM: float = 0.10
const ABSOLUTE_FALL_Y: float = -42.0

var _track: WildDashGrandPrixTrack
var _route: Array[Vector3] = []
var _route_distances: Array[float] = []
var _safety_root: Node3D
var _configured: bool = false
var _lateral_corrections: int = 0
var _floor_recoveries: int = 0
var _deep_recoveries: int = 0
var _last_safe_positions: Dictionary = {}
var _last_safe_segments: Dictionary = {}

func _ready() -> void:
	# Character=0, RacingFeel=100, environment collision=120, tunnel failsafe=180.
	# Run last so no later movement can put the racer back under the road.
	process_priority = 320
	call_deferred("_configure_after_track_ready")

func _configure_after_track_ready() -> void:
	for _frame: int in range(5):
		await get_tree().physics_frame
	_track = _find_track()
	if _track == null:
		push_warning("RC9 GRAND PRIX ROUTE SAFETY V3: Grand Prix track not found")
		return
	_route = _track.get_route_points()
	if _route.size() != ROUTE_WIDTHS.size() + 1:
		push_warning("RC9 GRAND PRIX ROUTE SAFETY V3: route/width contract mismatch")
		return
	_build_route_distances()
	_build_hidden_safety_geometry()
	_configured = true
	print("RC9 GRAND PRIX ROUTE SAFETY V3 READY route_segments=%d underlays=%d seams=%d floor_limit=%.2f priority=%d" % [
		ROUTE_WIDTHS.size(), ROUTE_WIDTHS.size(), maxi(0, _route.size() - 2),
		FLOOR_PENETRATION_LIMIT, process_priority,
	])

func _physics_process(_delta: float) -> void:
	if not _configured or not RaceManager.active:
		return
	for candidate: Node3D in RaceManager.racers:
		if candidate is WildDashCharacterController:
			var racer: WildDashCharacterController = candidate as WildDashCharacterController
			racer.floor_snap_length = maxf(racer.floor_snap_length, FLOOR_SNAP_MINIMUM)
			racer.safe_margin = maxf(racer.safe_margin, SAFE_MARGIN_MINIMUM)
			_enforce_route_safety(racer)

func _build_route_distances() -> void:
	_route_distances.clear()
	if _route.is_empty():
		return
	var total: float = 0.0
	_route_distances.append(0.0)
	for index: int in range(_route.size() - 1):
		total += _route[index].distance_to(_route[index + 1])
		_route_distances.append(total)

func _build_hidden_safety_geometry() -> void:
	_safety_root = Node3D.new()
	_safety_root.name = "RC9GrandPrixRouteSafetyGeometryV3"
	add_child(_safety_root)

	for segment_index: int in range(ROUTE_WIDTHS.size()):
		_build_segment_underlay(segment_index)
	for route_index: int in range(1, _route.size() - 1):
		_build_seam_catch_plate(route_index)
	for segment_index: int in LATERAL_PROTECTED_SEGMENTS:
		_build_segment_side_walls(segment_index)

func _build_segment_underlay(segment_index: int) -> void:
	if segment_index < 0 or segment_index + 1 >= _route.size():
		return
	var a: Vector3 = _route[segment_index]
	var b: Vector3 = _route[segment_index + 1]
	var length: float = a.distance_to(b)
	if length <= 0.01:
		return
	var center: Vector3 = (a + b) * 0.5 + Vector3.DOWN * UNDERLAY_DEPTH
	var target: Vector3 = b + Vector3.DOWN * UNDERLAY_DEPTH
	var width: float = ROUTE_WIDTHS[segment_index] + UNDERLAY_WIDTH_EXTRA
	_add_static_box(
		"RoadUnderlay_%02d" % segment_index,
		center,
		target,
		Vector3(width, UNDERLAY_THICKNESS, length + UNDERLAY_LENGTH_EXTENSION)
	)

func _build_seam_catch_plate(route_index: int) -> void:
	if route_index <= 0 or route_index >= _route.size() - 1:
		return
	var point: Vector3 = _route[route_index]
	var previous: Vector3 = _route[route_index - 1]
	var following: Vector3 = _route[route_index + 1]
	var direction: Vector3 = following - previous
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()
	var width_before: float = ROUTE_WIDTHS[route_index - 1]
	var width_after: float = ROUTE_WIDTHS[route_index]
	var width: float = maxf(width_before, width_after) + SEAM_CATCH_WIDTH_EXTRA
	var center: Vector3 = point + Vector3.DOWN * SEAM_CATCH_DEPTH
	_add_static_box(
		"RouteSeamCatch_%02d" % route_index,
		center,
		center + direction * 5.0,
		Vector3(width, SEAM_CATCH_THICKNESS, SEAM_CATCH_LENGTH)
	)

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
	var length: float = a.distance_to(b)
	var tunnel: bool = segment_index == 25
	var wall_thickness: float = TUNNEL_WALL_THICKNESS if tunnel else NORMAL_WALL_THICKNESS
	var wall_height: float = TUNNEL_WALL_HEIGHT if tunnel else NORMAL_WALL_HEIGHT
	var vertical_center: float = 2.40 if tunnel else 1.65
	var midpoint: Vector3 = (a + b) * 0.5
	for side: float in SIDES:
		var lateral_offset: Vector3 = right * side * (width * 0.5 + WALL_EDGE_OFFSET)
		var wall_center: Vector3 = midpoint + lateral_offset + Vector3.UP * vertical_center
		var wall_target: Vector3 = b + lateral_offset + Vector3.UP * vertical_center
		_add_static_box(
			"RouteWall_%02d_%s" % [segment_index, "L" if side < 0.0 else "R"],
			wall_center,
			wall_target,
			Vector3(wall_thickness, wall_height, length + WALL_LENGTH_EXTENSION)
		)

func _add_static_box(node_name: String, position: Vector3, look_target: Vector3, size: Vector3) -> void:
	var body: StaticBody3D = StaticBody3D.new()
	body.name = node_name
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = position
	_safety_root.add_child(body)
	body.look_at(look_target, Vector3.UP)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	collision.shape = box
	body.add_child(collision)

func _enforce_route_safety(racer: WildDashCharacterController) -> void:
	if racer == null or racer.finished:
		return
	var progress: float = RaceManager.get_track_progress(racer)
	var segment_index: int = _segment_from_progress(progress)
	if segment_index < 0:
		return
	var a: Vector3 = _route[segment_index]
	var b: Vector3 = _route[segment_index + 1]
	var segment_length: float = maxf(0.01, a.distance_to(b))
	var segment_start: float = _route_distances[segment_index]
	var t: float = clampf((progress - segment_start) / segment_length, 0.0, 1.0)
	var centerline: Vector3 = a.lerp(b, t)
	var planar: Vector3 = b - a
	planar.y = 0.0
	if planar.length_squared() <= 0.001:
		return
	var direction: Vector3 = planar.normalized()
	var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var width: float = ROUTE_WIDTHS[segment_index]
	var radius: float = _collision_radius(racer)
	var lateral: float = (racer.global_position - centerline).dot(right)
	var expected_road_y: float = lerpf(a.y, b.y, t) + ROAD_TOP_OFFSET
	var vertical_error: float = racer.global_position.y - expected_road_y
	var near_route: bool = absf(lateral) <= width * 0.5 + FLOOR_RECOVERY_LATERAL_EXTRA
	var safe_lateral: float = maxf(1.0, width * 0.5 - radius - LATERAL_PADDING)

	# Save normal contact more generously than V2. The racer root is designed to
	# sit at road level, so a small +- tolerance is enough to establish a safe point.
	if racer.is_on_floor() and absf(lateral) <= safe_lateral + 0.35 and vertical_error >= -0.06 and vertical_error <= 0.45:
		_last_safe_positions[racer.get_instance_id()] = racer.global_position
		_last_safe_segments[racer.get_instance_id()] = segment_index

	if LATERAL_PROTECTED_SEGMENTS.has(segment_index):
		var padding: float = TUNNEL_LATERAL_PADDING if segment_index == 25 else LATERAL_PADDING
		var allowed: float = maxf(1.0, width * 0.5 - radius - padding)
		if absf(lateral) > allowed and absf(lateral) <= width * 0.5 + 6.0:
			_apply_lateral_recovery(racer, right, lateral, allowed, segment_index)
			lateral = (racer.global_position - centerline).dot(right)
			near_route = absf(lateral) <= width * 0.5 + FLOOR_RECOVERY_LATERAL_EXTRA

	# V2 allowed ~0.78m of penetration, which let the racer ride the hidden
	# underlay while visibly inside the black road. V3 corrects at ~0.10m.
	if near_route and vertical_error < -FLOOR_PENETRATION_LIMIT:
		_apply_floor_recovery(racer, centerline, right, lateral, width, radius, expected_road_y, segment_index)
		return

	# Directly detect a world surface immediately above the racer. This catches
	# the exact case where the root is already under a road box but progress still
	# appears valid. Recovery always targets the known route plane, not the hit.
	if near_route and vertical_error < 0.02 and _has_world_surface_above(racer, expected_road_y):
		_apply_floor_recovery(racer, centerline, right, lateral, width, radius, expected_road_y, segment_index)
		return

	# Last-resort restore for deep geometry penetration or a runaway fall.
	if vertical_error < -DEEP_RECOVERY_DEPTH or racer.global_position.y < ABSOLUTE_FALL_Y:
		_restore_last_safe_or_respawn(racer, segment_index, vertical_error)

func _segment_from_progress(progress: float) -> int:
	if _route_distances.size() != _route.size() or _route_distances.size() < 2:
		return -1
	for index: int in range(_route_distances.size() - 1):
		if progress <= _route_distances[index + 1] + 0.01:
			return index
	return _route_distances.size() - 2

func _has_world_surface_above(racer: WildDashCharacterController, expected_road_y: float) -> bool:
	var start_y: float = racer.global_position.y + 0.04
	var end_y: float = maxf(start_y + 0.40, expected_road_y + 0.70)
	if end_y - start_y > 3.0:
		end_y = start_y + 3.0
	var start: Vector3 = Vector3(racer.global_position.x, start_y, racer.global_position.z)
	var finish: Vector3 = Vector3(racer.global_position.x, end_y, racer.global_position.z)
	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(start, finish, 1)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var hit: Dictionary = racer.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var hit_position: Vector3 = hit.get("position", Vector3.ZERO)
	return hit_position.y > racer.global_position.y + 0.05 and absf(hit_position.y - expected_road_y) <= 1.15

func _apply_lateral_recovery(
	racer: WildDashCharacterController,
	right: Vector3,
	lateral: float,
	allowed: float,
	segment_index: int
) -> void:
	var side: float = signf(lateral)
	var corrected_lateral: float = side * allowed
	racer.global_position -= right * (lateral - corrected_lateral)
	racer.global_position -= right * side * 0.10
	var outward: Vector3 = right * side
	var outward_velocity: float = racer.velocity.dot(outward)
	if outward_velocity > 0.0:
		racer.velocity -= outward * outward_velocity
	_apply_recovery_speed(racer)
	racer.reset_physics_interpolation()
	_lateral_corrections += 1
	if _lateral_corrections <= 20 or OS.has_environment("WILDDASH_DEBUG_COLLISION"):
		print("RC9 ROUTE V3 LATERAL BLOCK racer=%s segment=%d lateral=%.2f allowed=%.2f count=%d" % [
			racer.name, segment_index, lateral, allowed, _lateral_corrections,
		])

func _apply_floor_recovery(
	racer: WildDashCharacterController,
	centerline: Vector3,
	right: Vector3,
	lateral: float,
	width: float,
	radius: float,
	expected_road_y: float,
	segment_index: int
) -> void:
	var allowed: float = maxf(1.0, width * 0.5 - radius - LATERAL_PADDING)
	var clamped_lateral: float = clampf(lateral, -allowed, allowed)
	var recovered: Vector3 = centerline + right * clamped_lateral
	recovered.y = expected_road_y + RECOVERY_HEIGHT_OFFSET
	racer.global_position = recovered
	if racer.velocity.y < 0.0:
		racer.velocity.y = 0.0
	_apply_recovery_speed(racer)
	racer.reset_physics_interpolation()
	_last_safe_positions[racer.get_instance_id()] = recovered
	_last_safe_segments[racer.get_instance_id()] = segment_index
	_floor_recoveries += 1
	if _floor_recoveries <= 30 or OS.has_environment("WILDDASH_DEBUG_COLLISION"):
		print("RC9 ROUTE V3 FLOOR RECOVERY racer=%s segment=%d road_y=%.2f recovered_y=%.2f count=%d" % [
			racer.name, segment_index, expected_road_y, recovered.y, _floor_recoveries,
		])

func _restore_last_safe_or_respawn(racer: WildDashCharacterController, segment_index: int, vertical_error: float) -> void:
	var racer_id: int = racer.get_instance_id()
	var recovered: Vector3
	if _last_safe_positions.has(racer_id):
		recovered = _last_safe_positions[racer_id] as Vector3
		recovered += Vector3.UP * RECOVERY_HEIGHT_OFFSET
	else:
		recovered = RaceManager.get_respawn_position(racer)
	racer.global_position = recovered
	racer.velocity = Vector3.ZERO
	_apply_recovery_speed(racer)
	racer.reset_physics_interpolation()
	_deep_recoveries += 1
	if _deep_recoveries <= 20 or OS.has_environment("WILDDASH_DEBUG_COLLISION"):
		print("RC9 ROUTE V3 DEEP RESTORE racer=%s segment=%d vertical_error=%.2f restored=%s count=%d" % [
			racer.name, segment_index, vertical_error, str(recovered), _deep_recoveries,
		])

func _collision_radius(racer: WildDashCharacterController) -> float:
	var collision: CollisionShape3D = racer.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision != null and collision.shape is CapsuleShape3D:
		return (collision.shape as CapsuleShape3D).radius
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
