class_name WildDashGrandPrixRouteSafety
extends Node

## RC9 final Grand Prix containment layer.
## The visible road remains untouched. This controller adds invisible safety
## geometry below every main-route segment plus post-physics recovery so a
## CharacterBody cannot continue driving underneath the course after a missed
## sloped CSG contact.

const ROUTE_WIDTHS: Array[float] = [
	18.0, 18.0, 14.0, 14.0, 12.0, 8.0, 16.0, 14.0, 11.0, 10.0,
	18.0, 17.0, 18.0, 16.0, 10.0, 20.0, 18.0, 18.0, 22.0, 22.0,
	20.0, 15.0, 14.0, 13.0, 13.0, 12.0, 11.0, 12.0, 18.0,
]

# Side containment is intentionally focused so shortcut openings remain usable.
const LATERAL_PROTECTED_SEGMENTS: Array[int] = [11, 12, 13, 14, 15, 25, 26]
const SIDES: Array[float] = [-1.0, 1.0]

const NORMAL_WALL_THICKNESS: float = 1.10
const NORMAL_WALL_HEIGHT: float = 3.80
const TUNNEL_WALL_THICKNESS: float = 2.00
const TUNNEL_WALL_HEIGHT: float = 9.00
const WALL_EDGE_OFFSET: float = 0.48
const WALL_LENGTH_EXTENSION: float = 3.0

# Original Grand Prix road collision is a 0.5 m CSG box centered at -0.22 m.
# These hidden StaticBody boxes sit below it and overlap segment ends, so a
# missed CSG contact cannot drop the racer into the scenery.
const UNDERLAY_DEPTH: float = 0.72
const UNDERLAY_THICKNESS: float = 1.10
const UNDERLAY_WIDTH_EXTRA: float = 1.20
const UNDERLAY_LENGTH_EXTENSION: float = 3.50

const SEAM_CATCH_DEPTH: float = 0.52
const SEAM_CATCH_THICKNESS: float = 0.86
const SEAM_CATCH_LENGTH: float = 6.50
const SEAM_CATCH_WIDTH_EXTRA: float = 1.50

const ROAD_TOP_OFFSET: float = 0.03
const FLOOR_RECOVERY_DEPTH: float = 0.78
const DEEP_RECOVERY_DEPTH: float = 2.40
const RECOVERY_HEIGHT_OFFSET: float = 0.22
const FLOOR_RECOVERY_LATERAL_EXTRA: float = 1.60
const LATERAL_PADDING: float = 0.28
const TUNNEL_LATERAL_PADDING: float = 0.62
const SEGMENT_END_MARGIN_METERS: float = 4.0
const TUNNEL_END_MARGIN_METERS: float = 11.0
const SPEED_RETENTION_AFTER_RECOVERY: float = 0.84
const FLOOR_SNAP_MINIMUM: float = 0.65
const SAFE_MARGIN_MINIMUM: float = 0.09

var _track: WildDashGrandPrixTrack
var _route: Array[Vector3] = []
var _safety_root: Node3D
var _configured: bool = false
var _lateral_corrections: int = 0
var _floor_recoveries: int = 0
var _deep_recoveries: int = 0
var _last_safe_positions: Dictionary = {}

func _ready() -> void:
	# RacingFeel=100, environment collision=120, legacy tunnel failsafe=180.
	# This controller must see the final racer position for the frame.
	process_priority = 300
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
	print("RC9 GRAND PRIX ROUTE SAFETY V2 READY route_segments=%d underlays=%d seam_catches=%d lateral_segments=%s priority=%d" % [
		ROUTE_WIDTHS.size(), ROUTE_WIDTHS.size(), maxi(0, _route.size() - 2),
		str(LATERAL_PROTECTED_SEGMENTS), process_priority,
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

func _build_hidden_safety_geometry() -> void:
	_safety_root = Node3D.new()
	_safety_root.name = "RC9GrandPrixRouteSafetyGeometry"
	add_child(_safety_root)

	# Every main-route road strip gets a thick overlapping underlay.
	for segment_index: int in range(ROUTE_WIDTHS.size()):
		_build_segment_underlay(segment_index)

	# Every route joint gets a second catch plate. It sits below the visible road
	# and only matters if the thin CSG surfaces miss at a steep/angled seam.
	for route_index: int in range(1, _route.size() - 1):
		_build_seam_catch_plate(route_index)

	for segment_index: int in LATERAL_PROTECTED_SEGMENTS:
		_build_segment_side_walls(segment_index)

func _build_segment_underlay(segment_index: int) -> void:
	if segment_index < 0 or segment_index + 1 >= _route.size():
		return
	var a: Vector3 = _route[segment_index]
	var b: Vector3 = _route[segment_index + 1]
	var segment_length: float = a.distance_to(b)
	if segment_length <= 0.01:
		return
	var center: Vector3 = (a + b) * 0.5 + Vector3.DOWN * UNDERLAY_DEPTH
	var target: Vector3 = b + Vector3.DOWN * UNDERLAY_DEPTH
	var width: float = ROUTE_WIDTHS[segment_index] + UNDERLAY_WIDTH_EXTRA
	_add_static_box(
		"RoadUnderlay_%02d" % segment_index,
		center,
		target,
		Vector3(width, UNDERLAY_THICKNESS, segment_length + UNDERLAY_LENGTH_EXTENSION)
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
	var segment_length: float = a.distance_to(b)
	var tunnel: bool = segment_index == 25
	var wall_thickness: float = TUNNEL_WALL_THICKNESS if tunnel else NORMAL_WALL_THICKNESS
	var wall_height: float = TUNNEL_WALL_HEIGHT if tunnel else NORMAL_WALL_HEIGHT
	var vertical_center: float = 2.30 if tunnel else 1.55
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
	var direction: Vector3 = next - previous
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()
	var width_before: float = ROUTE_WIDTHS[route_index - 1]
	var width_after: float = ROUTE_WIDTHS[route_index]
	var catch_width: float = maxf(width_before, width_after) + SEAM_CATCH_WIDTH_EXTRA
	var catch_center: Vector3 = point + Vector3.DOWN * SEAM_CATCH_DEPTH
	var catch_target: Vector3 = catch_center + direction * 5.0
	_add_static_box(
		"RouteSeamCatch_%02d" % route_index,
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

	# Floor safety covers the entire 29-segment Grand Prix route, not just the
	# downhill/tunnel sections. This is the critical difference from V1.
	for segment_index: int in range(ROUTE_WIDTHS.size()):
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
	var expected_road_y: float = lerpf(a.y, b.y, best_t) + ROAD_TOP_OFFSET
	var vertical_error: float = racer.global_position.y - expected_road_y
	var safe_allowed: float = maxf(1.0, width * 0.5 - radius - LATERAL_PADDING)

	# Remember a trustworthy road position. If an extreme tunnel/seam miss ever
	# happens, this gives us a deterministic recovery point instead of allowing
	# the racer to continue under the world.
	if racer.is_on_floor() and absf(lateral) <= safe_allowed + 0.45 and vertical_error >= -0.18 and vertical_error <= 1.40:
		_last_safe_positions[racer.get_instance_id()] = racer.global_position

	# Lateral containment remains focused on downhill/tunnel segments so shortcut
	# entrances elsewhere stay open.
	if LATERAL_PROTECTED_SEGMENTS.has(best_segment):
		var padding: float = TUNNEL_LATERAL_PADDING if best_segment == 25 else LATERAL_PADDING
		var allowed: float = maxf(1.0, width * 0.5 - radius - padding)
		var lateral_limit: float = width * 0.5 + (10.0 if best_segment == 25 else 4.0)
		if absf(lateral) > allowed and best_planar_distance <= lateral_limit:
			_apply_lateral_recovery(racer, right, lateral, allowed, best_segment)
			# Recompute after position correction so floor recovery uses the new lane.
			lateral = (racer.global_position - centerline).dot(right)

	# Main protection: if the racer root is below the expected road plane while
	# still horizontally inside/near that road, put it back on top immediately.
	var floor_limit: float = width * 0.5 + FLOOR_RECOVERY_LATERAL_EXTRA
	if vertical_error < -FLOOR_RECOVERY_DEPTH and best_planar_distance <= floor_limit:
		_apply_floor_recovery(racer, centerline, right, lateral, width, radius, expected_road_y, best_segment, false)
		return

	# Extreme fallback for a deep miss. Prefer the last known valid road location.
	# This catches the exact screenshot case where the character is fully under
	# the mesh and keeps driving forward inside the scenery.
	if vertical_error < -DEEP_RECOVERY_DEPTH:
		var racer_id: int = racer.get_instance_id()
		if _last_safe_positions.has(racer_id):
			var last_safe: Vector3 = _last_safe_positions[racer_id] as Vector3
			racer.global_position = last_safe + Vector3.UP * RECOVERY_HEIGHT_OFFSET
			if racer.velocity.y < 0.0:
				racer.velocity.y = 0.0
			_apply_recovery_speed(racer)
			racer.reset_physics_interpolation()
			_deep_recoveries += 1
			if _deep_recoveries <= 12 or OS.has_environment("WILDDASH_DEBUG_COLLISION"):
				print("RC9 ROUTE DEEP RESTORE racer=%s segment=%d vertical_error=%.2f count=%d" % [
					racer.name, best_segment, vertical_error, _deep_recoveries,
				])

func _apply_lateral_recovery(
	racer: WildDashCharacterController,
	right: Vector3,
	lateral: float,
	allowed: float,
	segment_index: int
) -> void:
	var side: float = signf(lateral)
	var corrected_lateral: float = side * allowed
	var correction: Vector3 = right * (lateral - corrected_lateral)
	racer.global_position -= correction
	racer.global_position -= right * side * 0.10
	var outward: Vector3 = right * side
	var outward_velocity: float = racer.velocity.dot(outward)
	if outward_velocity > 0.0:
		racer.velocity -= outward * outward_velocity
	_apply_recovery_speed(racer)
	racer.reset_physics_interpolation()
	_lateral_corrections += 1
	if _lateral_corrections <= 20 or OS.has_environment("WILDDASH_DEBUG_COLLISION"):
		print("RC9 ROUTE LATERAL BLOCK racer=%s segment=%d lateral=%.2f allowed=%.2f count=%d" % [
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
	segment_index: int,
	deep: bool
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
	_floor_recoveries += 1
	if _floor_recoveries <= 20 or OS.has_environment("WILDDASH_DEBUG_COLLISION"):
		print("RC9 ROUTE FLOOR RECOVERY racer=%s segment=%d road_y=%.2f recovered_y=%.2f deep=%s count=%d" % [
			racer.name, segment_index, expected_road_y, recovered.y, str(deep), _floor_recoveries,
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
