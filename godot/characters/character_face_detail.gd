class_name WildDashCharacterFaceDetail
extends Node3D

## Runtime-friendly facial detail layer for the procedural RC5 character meshes.
## Keeps expressive parts separate from the base silhouette so higher LODs can
## cheaply hide micro detail without changing gameplay collision or animation.

@export var species: StringName = &"dog"
@export var face_scale := 1.0

var _primary_root: Node3D
var _micro_root: Node3D
var _lod_level := 0

func _ready() -> void:
	rebuild()

func configure(new_species: StringName, new_scale := 1.0) -> void:
	species = new_species
	face_scale = new_scale
	if is_inside_tree():
		rebuild()

func set_detail_lod(level: int) -> void:
	_lod_level = clampi(level, 0, 2)
	if _primary_root:
		_primary_root.visible = _lod_level <= 1
	if _micro_root:
		_micro_root.visible = _lod_level == 0

func rebuild() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	_primary_root = Node3D.new()
	_primary_root.name = "PrimaryFace"
	add_child(_primary_root)
	_micro_root = Node3D.new()
	_micro_root.name = "MicroFace"
	add_child(_micro_root)

	var profile := _profile_for_species(species)
	_build_eyes(profile)
	_build_brows(profile)
	_build_nose_and_mouth(profile)
	_build_species_details(profile)
	set_detail_lod(_lod_level)

func _build_eyes(profile: Dictionary) -> void:
	var eye_x := float(profile.get("eye_x", 0.16))
	var eye_y := float(profile.get("eye_y", 0.10))
	var eye_z := float(profile.get("eye_z", -0.40))
	var eye_radius := float(profile.get("eye_radius", 0.11))
	var iris_color: Color = profile.get("iris_color", Color(0.32, 0.20, 0.08, 1.0))
	var eye_scale: Vector3 = profile.get("eye_scale", Vector3(1.0, 1.08, 0.52))
	var pupil_scale: Vector3 = profile.get("pupil_scale", Vector3(0.72, 1.0, 0.48))

	for side in [-1.0, 1.0]:
		var eye := _mesh_instance(_sphere_mesh(eye_radius), Color(0.985, 0.985, 0.96, 1.0), 0.48)
		eye.name = "LeftEye" if side < 0.0 else "RightEye"
		eye.position = Vector3(side * eye_x, eye_y, eye_z) * face_scale
		eye.scale = eye_scale * face_scale
		_primary_root.add_child(eye)

		var iris := _mesh_instance(_sphere_mesh(eye_radius * 0.58), iris_color, 0.38)
		iris.name = "LeftIris" if side < 0.0 else "RightIris"
		iris.position = Vector3(side * eye_x, eye_y, eye_z - eye_radius * 0.34) * face_scale
		iris.scale = Vector3(0.82, 1.0, 0.42) * face_scale
		_primary_root.add_child(iris)

		var pupil := _mesh_instance(_sphere_mesh(eye_radius * 0.34), Color(0.035, 0.028, 0.035, 1.0), 0.32)
		pupil.name = "LeftPupil" if side < 0.0 else "RightPupil"
		pupil.position = Vector3(side * eye_x, eye_y, eye_z - eye_radius * 0.52) * face_scale
		pupil.scale = pupil_scale * face_scale
		_primary_root.add_child(pupil)

		var highlight := _mesh_instance(_sphere_mesh(eye_radius * 0.11), Color(1, 1, 1, 1), 0.2)
		highlight.name = "EyeHighlight"
		highlight.position = Vector3(side * eye_x - side * eye_radius * 0.10, eye_y + eye_radius * 0.18, eye_z - eye_radius * 0.70) * face_scale
		highlight.scale = Vector3.ONE * face_scale
		_micro_root.add_child(highlight)

func _build_brows(profile: Dictionary) -> void:
	var eye_x := float(profile.get("eye_x", 0.16))
	var brow_y := float(profile.get("brow_y", 0.25))
	var brow_z := float(profile.get("brow_z", -0.43))
	var brow_tilt := float(profile.get("brow_tilt", 0.12))
	var brow_color: Color = profile.get("brow_color", Color(0.12, 0.08, 0.07, 1.0))
	var brow_size: Vector3 = profile.get("brow_size", Vector3(0.20, 0.035, 0.035))
	for side in [-1.0, 1.0]:
		var brow := _mesh_instance(_box_mesh(brow_size * face_scale), brow_color, 0.72)
		brow.name = "LeftBrow" if side < 0.0 else "RightBrow"
		brow.position = Vector3(side * eye_x, brow_y, brow_z) * face_scale
		brow.rotation.z = side * brow_tilt
		_micro_root.add_child(brow)

func _build_nose_and_mouth(profile: Dictionary) -> void:
	if bool(profile.get("has_nose", true)):
		var nose_radius := float(profile.get("nose_radius", 0.072))
		var nose_pos: Vector3 = profile.get("nose_pos", Vector3(0.0, -0.055, -0.48))
		var nose_scale: Vector3 = profile.get("nose_scale", Vector3(1.15, 0.82, 0.70))
		var nose_color: Color = profile.get("nose_color", Color(0.10, 0.075, 0.07, 1.0))
		var nose := _mesh_instance(_sphere_mesh(nose_radius), nose_color, 0.42)
		nose.name = "Nose"
		nose.position = nose_pos * face_scale
		nose.scale = nose_scale * face_scale
		_primary_root.add_child(nose)

	var mouth_y := float(profile.get("mouth_y", -0.16))
	var mouth_z := float(profile.get("mouth_z", -0.48))
	var mouth_width := float(profile.get("mouth_width", 0.13))
	var mouth_color: Color = profile.get("mouth_color", Color(0.12, 0.055, 0.065, 1.0))
	for side in [-1.0, 1.0]:
		var mouth := _mesh_instance(_box_mesh(Vector3(mouth_width, 0.026, 0.026) * face_scale), mouth_color, 0.62)
		mouth.name = "MouthLeft" if side < 0.0 else "MouthRight"
		mouth.position = Vector3(side * mouth_width * 0.42, mouth_y, mouth_z) * face_scale
		mouth.rotation.z = -side * 0.23
		_primary_root.add_child(mouth)

func _build_species_details(profile: Dictionary) -> void:
	match species:
		&"rabbit":
			_build_rabbit_details(profile)
		&"cat":
			_build_cat_details(profile)
		&"elephant":
			_build_elephant_details(profile)
		_:
			_build_dog_details(profile)

func _build_dog_details(_profile: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		for y_offset in [-0.035, 0.025]:
			var freckle := _mesh_instance(_sphere_mesh(0.017), Color(0.15, 0.09, 0.06, 1.0), 0.7)
			freckle.position = Vector3(side * 0.16, -0.09 + y_offset, -0.57) * face_scale
			freckle.scale = Vector3(1.0, 0.7, 0.45) * face_scale
			_micro_root.add_child(freckle)

func _build_rabbit_details(_profile: Dictionary) -> void:
	var tooth := _mesh_instance(_box_mesh(Vector3(0.085, 0.10, 0.025) * face_scale), Color(1.0, 0.98, 0.88, 1.0), 0.45)
	tooth.name = "FrontTooth"
	tooth.position = Vector3(0.0, -0.225, -0.405) * face_scale
	_micro_root.add_child(tooth)
	for side in [-1.0, 1.0]:
		var cheek := _mesh_instance(_sphere_mesh(0.055), Color(1.0, 0.48, 0.62, 0.36), 0.55, true)
		cheek.position = Vector3(side * 0.22, -0.10, -0.36) * face_scale
		cheek.scale = Vector3(1.25, 0.70, 0.28) * face_scale
		_micro_root.add_child(cheek)

func _build_cat_details(_profile: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		for row in [-1.0, 0.0, 1.0]:
			var whisker := _mesh_instance(_cylinder_mesh(0.008, 0.34), Color(0.92, 0.88, 0.96, 1.0), 0.6)
			whisker.name = "Whisker"
			whisker.position = Vector3(side * 0.25, -0.07 + row * 0.045, -0.39) * face_scale
			whisker.rotation.z = deg_to_rad(90.0 + side * row * 5.0)
			whisker.scale = Vector3.ONE * face_scale
			_micro_root.add_child(whisker)

func _build_elephant_details(_profile: Dictionary) -> void:
	for side in [-1.0, 1.0]:
		var nostril := _mesh_instance(_sphere_mesh(0.026), Color(0.12, 0.13, 0.18, 1.0), 0.78)
		nostril.name = "TrunkNostril"
		nostril.position = Vector3(side * 0.052, -0.79, -0.50) * face_scale
		nostril.scale = Vector3(1.0, 0.52, 0.36) * face_scale
		_micro_root.add_child(nostril)
	for i in range(3):
		var wrinkle := _mesh_instance(_box_mesh(Vector3(0.19 - i * 0.025, 0.012, 0.018) * face_scale), Color(0.25, 0.28, 0.42, 1.0), 0.9)
		wrinkle.position = Vector3(0.0, -0.31 - i * 0.10, -0.505) * face_scale
		_micro_root.add_child(wrinkle)

func _profile_for_species(value: StringName) -> Dictionary:
	match value:
		&"rabbit":
			return {
				"eye_x": 0.15,
				"eye_y": 0.10,
				"eye_z": -0.355,
				"eye_radius": 0.108,
				"iris_color": Color(0.20, 0.66, 0.34, 1.0),
				"brow_y": 0.245,
				"brow_z": -0.37,
				"brow_tilt": 0.10,
				"brow_color": Color(0.48, 0.20, 0.38, 1.0),
				"nose_pos": Vector3(0.0, -0.055, -0.395),
				"nose_radius": 0.052,
				"nose_scale": Vector3(1.2, 0.72, 0.70),
				"nose_color": Color(0.96, 0.34, 0.52, 1.0),
				"mouth_y": -0.145,
				"mouth_z": -0.402,
				"mouth_width": 0.095,
			}
		&"cat":
			return {
				"eye_x": 0.145,
				"eye_y": 0.095,
				"eye_z": -0.34,
				"eye_radius": 0.105,
				"iris_color": Color(0.94, 0.68, 0.12, 1.0),
				"pupil_scale": Vector3(0.42, 1.15, 0.46),
				"brow_y": 0.235,
				"brow_z": -0.36,
				"brow_tilt": 0.18,
				"brow_color": Color(0.11, 0.045, 0.16, 1.0),
				"nose_pos": Vector3(0.0, -0.055, -0.472),
				"nose_radius": 0.050,
				"nose_scale": Vector3(1.15, 0.70, 0.62),
				"nose_color": Color(0.96, 0.34, 0.50, 1.0),
				"mouth_y": -0.145,
				"mouth_z": -0.465,
				"mouth_width": 0.088,
			}
		&"elephant":
			return {
				"eye_x": 0.205,
				"eye_y": 0.13,
				"eye_z": -0.49,
				"eye_radius": 0.125,
				"iris_color": Color(0.20, 0.28, 0.42, 1.0),
				"brow_y": 0.30,
				"brow_z": -0.50,
				"brow_tilt": 0.09,
				"brow_size": Vector3(0.23, 0.040, 0.040),
				"brow_color": Color(0.20, 0.23, 0.34, 1.0),
				"has_nose": false,
				"mouth_y": -0.205,
				"mouth_z": -0.515,
				"mouth_width": 0.105,
			}
		_:
			return {
				"eye_x": 0.165,
				"eye_y": 0.105,
				"eye_z": -0.41,
				"eye_radius": 0.112,
				"iris_color": Color(0.48, 0.27, 0.08, 1.0),
				"brow_y": 0.255,
				"brow_z": -0.43,
				"brow_tilt": 0.12,
				"brow_color": Color(0.18, 0.10, 0.065, 1.0),
				"nose_pos": Vector3(0.0, -0.055, -0.595),
				"nose_radius": 0.070,
				"nose_scale": Vector3(1.18, 0.78, 0.70),
				"nose_color": Color(0.10, 0.075, 0.065, 1.0),
				"mouth_y": -0.165,
				"mouth_z": -0.592,
				"mouth_width": 0.105,
			}

func _mesh_instance(mesh: Mesh, color: Color, roughness := 0.7, transparent := false) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	if transparent:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	instance.material_override = material
	return instance

func _sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh

func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

func _cylinder_mesh(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	return mesh
