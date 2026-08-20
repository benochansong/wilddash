class_name WildDashGrandPrixV4RouteSignage
extends Node3D

## Round 1 V4.5 route-aware medium-distance navigation layer.
##
## V4.4 owns road arrows + wrong-way UI. This node only adds collision-free
## roadside signs before meaningful turns and route-confirm markers after them.
## It never changes checkpoints, route progress, racer physics or road collision.

const LOOKBACK_POINTS: int = 3
const LOOKAHEAD_POINTS: int = 3
const TURN_THRESHOLD_DEG: float = 34.0
const STRONG_TURN_THRESHOLD_DEG: float = 55.0
const SWITCHBACK_THRESHOLD_DEG: float = 72.0
const MIN_TURN_SPACING_METERS: float = 62.0
const APPROACH_DISTANCE: float = 16.0
const SHARP_WARNING_DISTANCE: float = 20.0
const CONFIRM_DISTANCE: float = 15.0
const ROAD_SIDE_OFFSET: float = 10.5
const CHEVRON_CLUSTER_SPACING: float = 3.2
const SIGN_BASE_LIFT: float = 0.10

var _route: Array[Vector3] = []
var _route_distances: Array[float] = []
var _sign_root: Node3D
var _turn_sign_count: int = 0
var _switchback_count: int = 0
var _confirm_count: int = 0
var _detected_turn_count: int = 0

func _ready() -> void:
	process_priority = 137
	call_deferred("_initialize_when_ready")

func _initialize_when_ready() -> void:
	for _frame: int in range(60):
		await get_tree().process_frame
		if RaceManager.get_route_point_count() >= 2:
			break
	_route = RaceManager.get_route_points()
	if _route.size() < LOOKBACK_POINTS + LOOKAHEAD_POINTS + 2:
		push_warning("GrandPrixV4RouteSignage: route unavailable")
		return

	_build_route_distances()
	_sign_root = Node3D.new()
	_sign_root.name = "V45RouteAwareSigns"
	add_child(_sign_root)
	_build_route_signage()

	print("GRAND PRIX V4.5 ROUTE SIGNAGE READY detected_turns=%d turn_boards=%d switchbacks=%d confirms=%d collision=false min_spacing=%.1fm approach=%.1fm" % [
		_detected_turn_count,
		_turn_sign_count,
		_switchback_count,
		_confirm_count,
		MIN_TURN_SPACING_METERS,
		APPROACH_DISTANCE,
	])

func _build_route_distances() -> void:
	_route_distances.clear()
	_route_distances.append(0.0)
	var total: float = 0.0
	for i: int in range(_route.size() - 1):
		total += _route[i].distance_to(_route[i + 1])
		_route_distances.append(total)

func _build_route_signage() -> void:
	var last_turn_distance: float = -10000.0
	for i: int in range(LOOKBACK_POINTS, _route.size() - LOOKAHEAD_POINTS):
		var route_distance: float = _route_distances[i]
		if route_distance - last_turn_distance < MIN_TURN_SPACING_METERS:
			continue

		var incoming: Vector3 = _route[i] - _route[i - LOOKBACK_POINTS]
		var outgoing: Vector3 = _route[i + LOOKAHEAD_POINTS] - _route[i]
		incoming.y = 0.0
		outgoing.y = 0.0
		if incoming.length_squared() <= 0.001 or outgoing.length_squared() <= 0.001:
			continue
		incoming = incoming.normalized()
		outgoing = outgoing.normalized()

		var angle_deg: float = rad_to_deg(acos(clampf(incoming.dot(outgoing), -1.0, 1.0)))
		if angle_deg < TURN_THRESHOLD_DEG:
			continue

		var cross_y: float = incoming.cross(outgoing).y
		if absf(cross_y) < 0.02:
			continue
		var turns_left: bool = cross_y > 0.0
		var right: Vector3 = Vector3(-incoming.z, 0.0, incoming.x).normalized()
		var outside_sign: float = 1.0 if turns_left else -1.0
		var side_offset: Vector3 = right * outside_sign * ROAD_SIDE_OFFSET
		var arrow_text: String = "<<<" if turns_left else ">>>"
		var single_arrow: String = "<" if turns_left else ">"

		_detected_turn_count += 1
		last_turn_distance = route_distance

		if angle_deg >= SWITCHBACK_THRESHOLD_DEG:
			_build_switchback_cluster(i, incoming, side_offset, arrow_text)
			_build_warning_board(_route[i] - incoming * SHARP_WARNING_DISTANCE + side_offset, incoming, "SHARP", arrow_text)
			_switchback_count += 1
		elif angle_deg >= STRONG_TURN_THRESHOLD_DEG:
			_build_large_chevron(_route[i] - incoming * APPROACH_DISTANCE + side_offset, incoming, arrow_text)
			_build_turn_board(_route[i] - incoming * 8.0 + side_offset, incoming, single_arrow)
		else:
			_build_turn_board(_route[i] - incoming * APPROACH_DISTANCE + side_offset, incoming, single_arrow)

		_turn_sign_count += 1
		_build_route_confirm(i, outgoing, turns_left)

func _build_switchback_cluster(index: int, incoming: Vector3, side_offset: Vector3, arrow_text: String) -> void:
	var base: Vector3 = _route[index] + side_offset
	for j: int in range(3):
		var longitudinal: float = (float(j) - 1.0) * CHEVRON_CLUSTER_SPACING
		var position: Vector3 = base + incoming * longitudinal
		_build_large_chevron(position, incoming, arrow_text)

func _build_large_chevron(world_position: Vector3, incoming: Vector3, text: String) -> void:
	var sign: Node3D = _make_sign_root(world_position, incoming, "LargeChevron")
	_add_posts(sign, 2.35, 2.0)
	_add_panel(sign, Vector3(5.4, 2.05, 0.16), Vector3(0.0, 2.30, 0.0), Color(0.96, 0.73, 0.08, 1.0))
	_add_label(sign, text, Vector3(0.0, 2.30, -0.105), 118, Color(0.035, 0.035, 0.025, 1.0))

func _build_turn_board(world_position: Vector3, incoming: Vector3, text: String) -> void:
	var sign: Node3D = _make_sign_root(world_position, incoming, "TurnBoard")
	_add_posts(sign, 1.70, 1.45)
	_add_panel(sign, Vector3(2.8, 1.55, 0.15), Vector3(0.0, 1.72, 0.0), Color(0.96, 0.73, 0.08, 1.0))
	_add_label(sign, text, Vector3(0.0, 1.72, -0.10), 104, Color(0.035, 0.035, 0.025, 1.0))

func _build_warning_board(world_position: Vector3, incoming: Vector3, title: String, arrow_text: String) -> void:
	var sign: Node3D = _make_sign_root(world_position, incoming, "SwitchbackWarning")
	_add_posts(sign, 2.15, 1.75)
	_add_panel(sign, Vector3(4.7, 2.15, 0.16), Vector3(0.0, 2.12, 0.0), Color(0.95, 0.66, 0.05, 1.0))
	_add_label(sign, arrow_text, Vector3(0.0, 2.48, -0.105), 90, Color(0.03, 0.03, 0.02, 1.0))
	_add_label(sign, title, Vector3(0.0, 1.72, -0.105), 42, Color(0.03, 0.03, 0.02, 1.0))

func _build_route_confirm(index: int, outgoing: Vector3, turns_left: bool) -> void:
	var right: Vector3 = Vector3(-outgoing.z, 0.0, outgoing.x).normalized()
	var confirm_side: float = -1.0 if turns_left else 1.0
	var position: Vector3 = _route[index] + outgoing * CONFIRM_DISTANCE + right * confirm_side * 9.0
	var sign: Node3D = _make_sign_root(position, outgoing, "RouteConfirm")
	_add_posts(sign, 1.45, 1.20)
	_add_panel(sign, Vector3(3.4, 1.20, 0.14), Vector3(0.0, 1.42, 0.0), Color(0.16, 0.48, 0.20, 1.0))
	_add_label(sign, "ROUTE OK", Vector3(0.0, 1.42, -0.095), 40, Color(0.95, 0.98, 0.88, 1.0))
	_confirm_count += 1

func _make_sign_root(world_position: Vector3, incoming: Vector3, base_name: String) -> Node3D:
	var sign := Node3D.new()
	sign.name = "%s_%03d" % [base_name, _turn_sign_count + _confirm_count]
	_sign_root.add_child(sign)
	world_position.y += SIGN_BASE_LIFT
	sign.global_position = world_position
	var look_target: Vector3 = world_position - incoming.normalized() * 10.0
	look_target.y = world_position.y
	# Node3D.look_at() points local -Z at the approaching racer. The sign artwork
	# is therefore authored on the local -Z face so every roadside board faces the
	# race direction consistently.
	sign.look_at(look_target, Vector3.UP)
	return sign

func _add_posts(parent: Node3D, top_height: float, half_spacing: float) -> void:
	for x: float in [-half_spacing, half_spacing]:
		var post := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.09
		mesh.bottom_radius = 0.12
		mesh.height = top_height
		mesh.radial_segments = 6
		post.mesh = mesh
		post.position = Vector3(x, top_height * 0.5, 0.10)
		post.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		post.material_override = _material(Color(0.20, 0.12, 0.055, 1.0))
		parent.add_child(post)

func _add_panel(parent: Node3D, size: Vector3, position: Vector3, color: Color) -> void:
	var panel := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	panel.mesh = mesh
	panel.position = position
	panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	panel.material_override = _material(color)
	parent.add_child(panel)

func _add_label(parent: Node3D, text: String, position: Vector3, font_size: int, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = position
	# Label3D's readable/front face is +Z, while the board's racer-facing surface
	# is local -Z. Without this half-turn every arrow/text panel is seen from its
	# back side and appears reversed. Rotate once here so ALL Round 1 roadside
	# chevrons, turn arrows, SHARP warnings and ROUTE OK boards read correctly.
	label.rotation.y = PI
	label.font_size = font_size
	label.pixel_size = 0.010
	label.modulate = color
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.0)
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(label)

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material
