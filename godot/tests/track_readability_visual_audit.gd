extends Node3D

const TRACK_SCENE: PackedScene = preload("res://tracks/grand_prix_track.tscn")
const SHOTS: Array[Dictionary] = [
	{"name": "01_meadow_first_bend", "route_index": 0, "lead": 0.58},
	{"name": "02_forest_uphill", "route_index": 2, "lead": 0.44},
	{"name": "03_jump_bridge_approach", "route_index": 3, "lead": 0.48},
	{"name": "04_canyon_s_curve", "route_index": 7, "lead": 0.48},
	{"name": "05_river_bridge", "route_index": 13, "lead": 0.48},
	{"name": "06_shortcut_a_obstacles", "route_index": 15, "lead": 0.48},
	{"name": "07_wide_hairpin", "route_index": 18, "lead": 0.46},
	{"name": "08_multijump_shortcut_b", "route_index": 21, "lead": 0.42},
	{"name": "09_tunnel_approach", "route_index": 24, "lead": 0.50},
	{"name": "10_final_chicane", "route_index": 26, "lead": 0.46},
	{"name": "11_finish_approach", "route_index": 28, "lead": 0.34},
]

var _track: Node3D
var _camera: Camera3D

func _ready() -> void:
	_track = TRACK_SCENE.instantiate()
	add_child(_track)
	_camera = Camera3D.new()
	_camera.name = "ReadabilityAuditCamera"
	_camera.current = true
	_camera.fov = 72.0
	_camera.near = 0.2
	_camera.far = 700.0
	add_child(_camera)
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var capture_succeeded := await _capture_route_views()
	get_tree().quit(0 if capture_succeeded else 1)

func _capture_route_views() -> bool:
	var output_dir := OS.get_environment("WILDDASH_READABILITY_OUTPUT")
	if output_dir.is_empty():
		output_dir = ProjectSettings.globalize_path("res://../outputs/readability-audit")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var route: Array[Vector3] = _track.get_route_points()
	for shot in SHOTS:
		var route_index: int = shot["route_index"]
		var a := route[route_index]
		var b := route[route_index + 1]
		var forward := (b - a).normalized()
		var planar_forward := Vector3(forward.x, 0.0, forward.z).normalized()
		var focus := a.lerp(b, float(shot["lead"]))
		_camera.global_position = focus - planar_forward * 10.0 + Vector3.UP * 4.6
		_camera.look_at(focus + forward * 28.0 + Vector3.UP * 1.1, Vector3.UP)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		var path := output_dir.path_join(String(shot["name"]) + ".png")
		var error := image.save_png(path)
		if error != OK:
			push_error("READABILITY AUDIT capture failed path=%s error=%d" % [path, error])
			return false
		print("READABILITY AUDIT CAPTURE %s" % path)
	print("READABILITY VISUAL AUDIT CAPTURE PASS shots=%d" % SHOTS.size())
	return true
