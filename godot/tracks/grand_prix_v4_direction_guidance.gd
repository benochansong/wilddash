class_name WildDashGrandPrixV4DirectionGuidance
extends Node3D

## Round 1 V4.4 navigation/readability pass.
## Adds collision-free road arrows and a persistent wrong-way warning without
## touching checkpoints, finish logic, off-road recovery, or racer physics.

const ARROW_SPACING: float = 30.0
const ARROW_LIFT: float = 0.10
const WRONG_WAY_SAMPLE_INTERVAL: float = 0.08
const WRONG_WAY_MIN_SPEED: float = 4.0
const WRONG_WAY_DOT_THRESHOLD: float = -0.35
const WRONG_WAY_TRIGGER_SECONDS: float = 0.60
const WRONG_WAY_CLEAR_SECONDS: float = 0.24
const WARNING_PULSE_SPEED: float = 9.0

var _route: Array[Vector3] = []
var _route_distances: Array[float] = []
var _player: WildDashCharacterController
var _arrow_root: Node3D
var _warning_layer: CanvasLayer
var _warning_overlay: ColorRect
var _warning_label: Label
var _sample_elapsed: float = 0.0
var _wrong_way_elapsed: float = 0.0
var _clear_elapsed: float = 0.0
var _warning_active: bool = false
var _pulse_time: float = 0.0
var _segment_hint: int = 0
var _arrow_count: int = 0

func _ready() -> void:
	process_priority = 136
	call_deferred("_initialize_when_ready")

func _initialize_when_ready() -> void:
	for _frame: int in range(60):
		await get_tree().process_frame
		if RaceManager.get_route_point_count() >= 2 and not RaceManager.racers.is_empty():
			break
	_route = RaceManager.get_route_points()
	_player = _find_player()
	if _route.size() < 2 or _player == null:
		push_warning("GrandPrixV4DirectionGuidance: route/player unavailable")
		return
	_build_route_distances()
	_build_direction_arrows()
	_build_wrong_way_ui()
	print("GRAND PRIX V4.4 DIRECTION GUIDANCE READY arrows=%d spacing=%.1fm wrong_way=true trigger=%.2fs min_speed=%.1f collision=false" % [
		_arrow_count,
		ARROW_SPACING,
		WRONG_WAY_TRIGGER_SECONDS,
		WRONG_WAY_MIN_SPEED,
	])

func _process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		_player = _find_player()
		if _player == null:
			return
	if _warning_label == null or _route.size() < 2:
		return

	_sample_elapsed += delta
	if _sample_elapsed >= WRONG_WAY_SAMPLE_INTERVAL:
		_sample_elapsed = fmod(_sample_elapsed, WRONG_WAY_SAMPLE_INTERVAL)
		_update_wrong_way_state(WRONG_WAY_SAMPLE_INTERVAL)

	if _warning_active:
		_pulse_time += delta
		var pulse: float = (sin(_pulse_time * WARNING_PULSE_SPEED) + 1.0) * 0.5
		_warning_overlay.color = Color(0.95, 0.02, 0.02, lerpf(0.035, 0.16, pulse))
		_warning_label.modulate = Color(1.0, lerpf(0.52, 0.92, pulse), lerpf(0.52, 0.92, pulse), 1.0)
	else:
		_warning_overlay.color = Color(0.95, 0.02, 0.02, 0.0)

func _build_route_distances() -> void:
	_route_distances.clear()
	_route_distances.append(0.0)
	var distance: float = 0.0
	for i: int in range(_route.size() - 1):
		distance += _route[i].distance_to(_route[i + 1])
		_route_distances.append(distance)

func _build_direction_arrows() -> void:
	_arrow_root = Node3D.new()
	_arrow_root.name = "V44RoadDirectionArrows"
	add_child(_arrow_root)

	var transforms: Array[Transform3D] = []
	var distance_carry: float = ARROW_SPACING * 0.55
	for segment_index: int in range(_route.size() - 1):
		var a: Vector3 = _route[segment_index]
		var b: Vector3 = _route[segment_index + 1]
		var segment: Vector3 = b - a
		var length: float = segment.length()
		if length <= 0.01:
			continue
		var direction: Vector3 = segment / length
		var planar_forward: Vector3 = Vector3(direction.x, 0.0, direction.z)
		if planar_forward.length_squared() <= 0.001:
			continue
		planar_forward = planar_forward.normalized()
		var right: Vector3 = Vector3(planar_forward.z, 0.0, -planar_forward.x).normalized()
		var basis := Basis(right, Vector3.UP, planar_forward)
		var along: float = distance_carry
		while along < length:
			var position: Vector3 = a + direction * along + Vector3.UP * ARROW_LIFT
			transforms.append(Transform3D(basis, position))
			along += ARROW_SPACING
		distance_carry = along - length

	var mesh: ArrayMesh = _build_arrow_mesh()
	if transforms.is_empty() or mesh.get_surface_count() == 0:
		return
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.72, 0.06, 1.0)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)

	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.instance_count = transforms.size()
	multi.mesh = mesh
	for i: int in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
	var instance := MultiMeshInstance3D.new()
	instance.name = "RoadArrows"
	instance.multimesh = multi
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arrow_root.add_child(instance)
	_arrow_count = transforms.size()

func _build_arrow_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array([
		Vector3(-0.55, 0.0, -2.25),
		Vector3(0.55, 0.0, -2.25),
		Vector3(0.55, 0.0, 0.10),
		Vector3(1.30, 0.0, 0.10),
		Vector3(0.0, 0.0, 2.55),
		Vector3(-1.30, 0.0, 0.10),
		Vector3(-0.55, 0.0, 0.10),
	])
	var normals := PackedVector3Array()
	for _i: int in range(vertices.size()):
		normals.append(Vector3.UP)
	var indices := PackedInt32Array([
		0, 1, 2,
		0, 2, 6,
		6, 2, 3,
		6, 3, 5,
		5, 3, 4,
	])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func _build_wrong_way_ui() -> void:
	_warning_layer = CanvasLayer.new()
	_warning_layer.name = "V44WrongWayWarning"
	_warning_layer.layer = 95
	add_child(_warning_layer)

	_warning_overlay = ColorRect.new()
	_warning_overlay.name = "WrongWayRedFlash"
	_warning_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_warning_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_overlay.color = Color(0.95, 0.02, 0.02, 0.0)
	_warning_layer.add_child(_warning_overlay)

	_warning_label = Label.new()
	_warning_label.name = "WrongWayLabel"
	_warning_label.anchor_left = 0.0
	_warning_label.anchor_right = 1.0
	_warning_label.anchor_top = 0.0
	_warning_label.anchor_bottom = 0.0
	_warning_label.offset_left = 0.0
	_warning_label.offset_right = 0.0
	_warning_label.offset_top = 66.0
	_warning_label.offset_bottom = 132.0
	_warning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warning_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_warning_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warning_label.text = "⚠  역주행!  WRONG WAY!  ↺ 돌아가세요  ⚠"
	_warning_label.add_theme_font_size_override("font_size", 34)
	_warning_label.add_theme_color_override("font_color", Color(1.0, 0.12, 0.10, 1.0))
	_warning_label.add_theme_color_override("font_outline_color", Color(0.08, 0.0, 0.0, 1.0))
	_warning_label.add_theme_constant_override("outline_size", 8)
	_warning_label.visible = false
	_warning_layer.add_child(_warning_label)

func _update_wrong_way_state(step: float) -> void:
	if not RaceManager.active or _player.finished:
		_set_warning(false)
		_wrong_way_elapsed = 0.0
		_clear_elapsed = 0.0
		return
	var speed: float = absf(_player.current_speed)
	if speed < WRONG_WAY_MIN_SPEED:
		_wrong_way_elapsed = maxf(0.0, _wrong_way_elapsed - step * 1.5)
		if _warning_active:
			_clear_elapsed += step
			if _clear_elapsed >= WRONG_WAY_CLEAR_SECONDS:
				_set_warning(false)
		return

	var route_forward: Vector3 = _route_forward_at_progress(RaceManager.get_track_progress(_player))
	var racer_forward: Vector3 = -_player.global_transform.basis.z
	racer_forward.y = 0.0
	if racer_forward.length_squared() <= 0.001 or route_forward.length_squared() <= 0.001:
		return
	racer_forward = racer_forward.normalized()
	route_forward = route_forward.normalized()
	var alignment: float = racer_forward.dot(route_forward)

	if alignment <= WRONG_WAY_DOT_THRESHOLD:
		_clear_elapsed = 0.0
		_wrong_way_elapsed += step
		if _wrong_way_elapsed >= WRONG_WAY_TRIGGER_SECONDS:
			_set_warning(true)
	else:
		_wrong_way_elapsed = maxf(0.0, _wrong_way_elapsed - step * 2.0)
		if _warning_active:
			_clear_elapsed += step
			if _clear_elapsed >= WRONG_WAY_CLEAR_SECONDS and alignment > 0.05:
				_set_warning(false)

func _route_forward_at_progress(progress: float) -> Vector3:
	if _route.size() < 2 or _route_distances.size() != _route.size():
		return Vector3.FORWARD
	progress = clampf(progress, 0.0, _route_distances[-1])
	_segment_hint = clampi(_segment_hint, 0, _route.size() - 2)
	while _segment_hint < _route.size() - 2 and _route_distances[_segment_hint + 1] < progress:
		_segment_hint += 1
	while _segment_hint > 0 and _route_distances[_segment_hint] > progress:
		_segment_hint -= 1
	var tangent: Vector3 = _route[_segment_hint + 1] - _route[_segment_hint]
	tangent.y = 0.0
	return tangent.normalized() if tangent.length_squared() > 0.001 else Vector3.FORWARD

func _set_warning(enabled: bool) -> void:
	if _warning_active == enabled:
		return
	_warning_active = enabled
	_warning_label.visible = enabled
	if enabled:
		_pulse_time = 0.0
		print("GRAND PRIX WRONG WAY WARNING active=true progress=%.1f%%" % RaceManager.get_progress_percent(_player))
	else:
		_warning_overlay.color = Color(0.95, 0.02, 0.02, 0.0)
		print("GRAND PRIX WRONG WAY WARNING active=false")

func _find_player() -> WildDashCharacterController:
	for racer: Node3D in RaceManager.racers:
		if racer is WildDashCharacterController and (racer as WildDashCharacterController).is_player:
			return racer as WildDashCharacterController
	return null
