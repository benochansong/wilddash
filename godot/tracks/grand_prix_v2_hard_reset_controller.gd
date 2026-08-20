class_name WildDashGrandPrixV2HardResetController
extends Node

## V2.8 natural-boundary diagnostic gate.
## Visible guardrail rails/posts are gone. TerrainShell Detail and GroundingWorld
## Backdrop stay hidden in every isolation mode so the giant green-pole candidates
## cannot re-enter the frame while road/terrain/performance are stabilized.

const ISOLATION_MODES: Array[String] = ["A", "B", "C", "D"]
const PERF_SAMPLE_DELAY: float = 1.5
const DEBUG_LABEL_NAME: String = "V28NaturalBoundaryLabel"

var _mode: String = "C"
var _sample_generation: int = 0
var _debug_label: Label
var _route: Array[Vector3] = []
var _segment_sections: Array[StringName] = []
var _chunk_ranges: Array[Vector2i] = []

func _ready() -> void:
	process_priority = 130
	if OS.has_environment("WILDDASH_V27_ISOLATION"):
		var requested: String = OS.get_environment("WILDDASH_V27_ISOLATION").to_upper()
		if ISOLATION_MODES.has(requested):
			_mode = requested
	call_deferred("_initialize_after_world_build")

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo or key_event.keycode != KEY_F8:
		return
	var current_index: int = ISOLATION_MODES.find(_mode)
	_mode = ISOLATION_MODES[(current_index + 1) % ISOLATION_MODES.size()]
	_apply_isolation_mode()
	_schedule_perf_sample()

func _initialize_after_world_build() -> void:
	for _frame: int in range(14):
		await get_tree().process_frame
	var bundle: Dictionary = WildDashGrandPrixV2Layout.build_route_bundle()
	_route = bundle["points"]
	_segment_sections = bundle["segment_sections"]
	_chunk_ranges = _build_chunk_ranges(_route, WildDashGrandPrixV2TerrainShell.CHUNK_LENGTH)
	_build_debug_label()
	_apply_section_debug_materials()
	_apply_isolation_mode()
	_schedule_perf_sample()
	_report_state()

func _apply_isolation_mode() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var guidance: Node = parent.get_node_or_null("V2CourseGuidance")
	if guidance != null and guidance.has_method("set_barrier_collision_enabled"):
		guidance.call("set_barrier_collision_enabled", _mode != "A")

	var shell: Node3D = parent.get_node_or_null("V2TerrainShell") as Node3D
	var grounding: Node3D = parent.get_node_or_null("V2GroundingWorld") as Node3D
	var terrain_gameplay: Node3D = parent.get_node_or_null("V2TerrainGameplay") as Node3D
	var stage3: Node3D = parent.get_node_or_null("V2Stage3") as Node3D

	if shell != null:
		shell.visible = _mode == "C" or _mode == "D"
		# Deliberately disabled in every mode until tree/prop transforms are rebuilt.
		_set_named_descendants_visible(shell, "Detail", false)
	if grounding != null:
		grounding.visible = _mode == "C" or _mode == "D"
		# Hero/backdrop props remain off; subgrade/skirt stays visible through root.
		_set_named_descendants_visible(grounding, "Backdrop", false)
	if terrain_gameplay != null:
		terrain_gameplay.visible = _mode == "C" or _mode == "D"
	if stage3 != null:
		stage3.visible = _mode == "D"

	if _debug_label != null:
		_debug_label.text = _label_text()
	print("GRAND PRIX V2.8 ISOLATION APPLY mode=%s A=road_racers B=+invisible_safety_collision C=+terrain_subgrade D=+gameplay_obstacles visible_guardrails=0 decorative_props=0 f8_cycle=true" % _mode)

func _set_named_descendants_visible(root: Node, target_name: String, visible_now: bool) -> void:
	for child: Node in root.get_children():
		if child.name == target_name and child is Node3D:
			(child as Node3D).visible = visible_now
		_set_named_descendants_visible(child, target_name, visible_now)

func _apply_section_debug_materials() -> void:
	var shell: Node = get_parent().get_node_or_null("V2TerrainShell")
	if shell == null:
		return
	for chunk_index: int in range(_chunk_ranges.size()):
		var chunk: Node = shell.get_node_or_null("V2SpatialChunk_%02d" % chunk_index)
		if chunk == null:
			continue
		var point_range: Vector2i = _chunk_ranges[chunk_index]
		var midpoint: int = clampi((point_range.x + point_range.y) / 2, 0, _route.size() - 1)
		var section_id: StringName = WildDashGrandPrixV2Geometry.point_section_id(_segment_sections, midpoint)
		var material: StandardMaterial3D = _section_debug_material(section_id)
		var near_mesh: MeshInstance3D = chunk.get_node_or_null("Terrain/NearTerrain") as MeshInstance3D
		var far_mesh: MeshInstance3D = chunk.get_node_or_null("Terrain/FarTerrain") as MeshInstance3D
		if near_mesh != null:
			near_mesh.material_override = material
		if far_mesh != null:
			far_mesh.material_override = material

func _section_debug_material(section_id: StringName) -> StandardMaterial3D:
	var color: Color
	match section_id:
		&"meadow_start": color = Color(0.18, 0.78, 0.18)
		&"forest_obstacle": color = Color(0.04, 0.28, 0.08)
		&"long_river": color = Color(0.08, 0.48, 0.52)
		&"mountain_approach", &"mountain_ascent": color = Color(0.38, 0.40, 0.42)
		&"summit_ridge": color = Color(0.68, 0.70, 0.72)
		&"rough_descent": color = Color(0.38, 0.22, 0.10)
		&"canyon_obstacle": color = Color(0.62, 0.28, 0.10)
		&"final_sprint": color = Color(0.56, 0.74, 0.12)
		_: color = Color(0.30, 0.32, 0.30)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.96
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func _build_chunk_ranges(points: Array[Vector3], chunk_length: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if points.size() < 2:
		return result
	var start_point: int = 0
	var distance: float = 0.0
	for segment_index: int in range(points.size() - 1):
		distance += points[segment_index].distance_to(points[segment_index + 1])
		if distance >= chunk_length and segment_index + 1 < points.size() - 1:
			result.append(Vector2i(start_point, segment_index + 1))
			start_point = segment_index + 1
			distance = 0.0
	if start_point < points.size() - 1:
		result.append(Vector2i(start_point, points.size() - 1))
	return result

func _build_debug_label() -> void:
	_debug_label = Label.new()
	_debug_label.name = DEBUG_LABEL_NAME
	_debug_label.position = Vector2(24.0, 252.0)
	_debug_label.add_theme_font_size_override("font_size", 16)
	_debug_label.text = _label_text()
	get_parent().add_child(_debug_label)

func _label_text() -> String:
	return "V2.8 NATURAL BOUNDARY  |  Isolation %s  |  F8: A/B/C/D\nRails 0 | Posts 0 | Decorative pole props OFF" % _mode

func _schedule_perf_sample() -> void:
	_sample_generation += 1
	var generation: int = _sample_generation
	_sample_perf_after_delay(generation)

func _sample_perf_after_delay(generation: int) -> void:
	await get_tree().create_timer(PERF_SAMPLE_DELAY).timeout
	if generation != _sample_generation:
		return
	var fps: float = Performance.get_monitor(Performance.TIME_FPS)
	var draw_calls: float = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	var physics_objects: float = Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	var node_count: float = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	print("GRAND PRIX V2.8 PERF ISOLATION mode=%s fps=%.1f draw_calls=%.0f physics_active=%.0f nodes=%.0f" % [
		_mode, fps, draw_calls, physics_objects, node_count,
	])

func _report_state() -> void:
	var detail_roots: int = _count_named_descendants(get_parent().get_node_or_null("V2TerrainShell"), "Detail")
	var backdrop_roots: int = _count_named_descendants(get_parent().get_node_or_null("V2GroundingWorld"), "Backdrop")
	var visual_owners: int = get_tree().get_nodes_in_group(WildDashGrandPrixV2CourseGuidance.VISUAL_OWNER_GROUP).size()
	print("GRAND PRIX V2.8 NATURAL BOUNDARY ACTIVE mode=%s visual_guardrail_owners=%d rails=0 posts=0 terrain_debug_colors=true terrain_detail_roots=%d backdrop_roots=%d details_visible=false backdrops_visible=false giant_green_pole_candidates_hidden=true graphical_pass=REQUIRED" % [
		_mode, visual_owners, detail_roots, backdrop_roots,
	])
	if visual_owners != 0:
		push_error("V2.8 expected zero visible guardrail owners")

func _count_named_descendants(root: Node, target_name: String) -> int:
	if root == null:
		return 0
	var count: int = 0
	for child: Node in root.get_children():
		if child.name == target_name:
			count += 1
		count += _count_named_descendants(child, target_name)
	return count
