class_name WildDashNPCAnimalVisual
extends WildDashCharacterVisual

## Lightweight race-only animal visual builder. Each scene supplies one species,
## while gameplay/collision continues to come from WildDashAnimalDefinition.
@export var species: StringName = &"fox"

static var _material_cache: Dictionary = {}
var _detail_nodes: Array[Node3D] = []
var _micro_nodes: Array[Node3D] = []

func _ready() -> void:
	_build_species_visual()
	super._ready()

func set_lod_level(level: int) -> void:
	super.set_lod_level(level)
	for node in _detail_nodes:
		if is_instance_valid(node):
			node.visible = level < 2
	for node in _micro_nodes:
		if is_instance_valid(node):
			node.visible = level == 0

func _build_species_visual() -> void:
	var root := get_node_or_null("ImportedModel") as Node3D
	if root == null:
		return
	var p := _profile(species)
	var fur: Color = p["fur"]
	var secondary: Color = p["secondary"]
	var dark: Color = p["dark"]
	var accent: Color = p["accent"]
	_add_capsule(root, "Body", Vector3(0, 0.88, 0.04), Vector3(1.5708, 0, 0), p["body"], fur)
	_add_sphere(root, "Head", Vector3(0, 1.22, -0.68), p["head"], fur)
	_add_legs(root, fur, secondary)
	_add_head_features(root, secondary, dark, accent)
	_add_tail(root, fur, secondary, dark)
	_add_face(root, dark, accent)

func _add_legs(root: Node3D, fur: Color, secondary: Color) -> void:
	var positions := [Vector3(-0.32, 0.42, -0.38), Vector3(0.32, 0.42, -0.38), Vector3(-0.32, 0.42, 0.40), Vector3(0.32, 0.42, 0.40)]
	for i in range(positions.size()):
		_add_capsule(root, "Leg_%d" % i, positions[i], Vector3.ZERO, Vector3(0.105, 0.31, 0.105), secondary if i < 2 else fur)

func _add_head_features(root: Node3D, secondary: Color, dark: Color, accent: Color) -> void:
	match species:
		&"fox":
			_add_cone(root, "EarL", Vector3(-0.27, 1.64, -0.66), Vector3(0.05, 0, -0.15), Vector3(0.16, 0.30, 0.16), dark)
			_add_cone(root, "EarR", Vector3(0.27, 1.64, -0.66), Vector3(0.05, 0, 0.15), Vector3(0.16, 0.30, 0.16), dark)
			_add_sphere(root, "Muzzle", Vector3(0, 1.10, -1.03), Vector3(0.34, 0.21, 0.42), secondary)
		&"bear":
			_add_round_ears(root, dark, 0.34, 0.18)
			_add_sphere(root, "Muzzle", Vector3(0, 1.08, -1.04), Vector3(0.38, 0.24, 0.34), secondary)
		&"raccoon":
			_add_cone(root, "EarL", Vector3(-0.28, 1.57, -0.66), Vector3(0.10, 0, -0.12), Vector3(0.14, 0.23, 0.14), dark)
			_add_cone(root, "EarR", Vector3(0.28, 1.57, -0.66), Vector3(0.10, 0, 0.12), Vector3(0.14, 0.23, 0.14), dark)
			_add_box(root, "MaskL", Vector3(-0.18, 1.25, -1.05), Vector3(0.24, 0.15, 0.06), dark, true)
			_add_box(root, "MaskR", Vector3(0.18, 1.25, -1.05), Vector3(0.24, 0.15, 0.06), dark, true)
			_add_sphere(root, "Muzzle", Vector3(0, 1.08, -1.03), Vector3(0.31, 0.19, 0.28), secondary)
		&"panda":
			_add_round_ears(root, dark, 0.34, 0.20)
			_add_sphere(root, "PatchL", Vector3(-0.18, 1.25, -1.04), Vector3(0.20, 0.17, 0.07), dark, true)
			_add_sphere(root, "PatchR", Vector3(0.18, 1.25, -1.04), Vector3(0.20, 0.17, 0.07), dark, true)
			_add_sphere(root, "Muzzle", Vector3(0, 1.08, -1.03), Vector3(0.35, 0.22, 0.30), secondary)
		&"wolf":
			_add_cone(root, "EarL", Vector3(-0.28, 1.66, -0.67), Vector3(0.02, 0, -0.12), Vector3(0.15, 0.31, 0.15), dark)
			_add_cone(root, "EarR", Vector3(0.28, 1.66, -0.67), Vector3(0.02, 0, 0.12), Vector3(0.15, 0.31, 0.15), dark)
			_add_sphere(root, "Muzzle", Vector3(0, 1.10, -1.07), Vector3(0.32, 0.20, 0.45), secondary)
			_add_box(root, "BrowL", Vector3(-0.18, 1.39, -1.06), Vector3(0.22, 0.055, 0.06), dark, true)
			_add_box(root, "BrowR", Vector3(0.18, 1.39, -1.06), Vector3(0.22, 0.055, 0.06), dark, true)
		&"boar":
			_add_round_ears(root, dark, 0.31, 0.15)
			_add_sphere(root, "Snout", Vector3(0, 1.06, -1.09), Vector3(0.39, 0.24, 0.38), accent)
			_add_cone(root, "TuskL", Vector3(-0.29, 0.99, -1.14), Vector3(1.5708, 0, -0.25), Vector3(0.055, 0.16, 0.055), Color("f4e3be"))
			_add_cone(root, "TuskR", Vector3(0.29, 0.99, -1.14), Vector3(1.5708, 0, 0.25), Vector3(0.055, 0.16, 0.055), Color("f4e3be"))
		&"deer":
			_add_sphere(root, "EarL", Vector3(-0.30, 1.55, -0.67), Vector3(0.20, 0.11, 0.10), dark)
			_add_sphere(root, "EarR", Vector3(0.30, 1.55, -0.67), Vector3(0.20, 0.11, 0.10), dark)
			_add_sphere(root, "Muzzle", Vector3(0, 1.08, -1.05), Vector3(0.30, 0.18, 0.38), secondary)
			_add_antlers(root, dark)
		&"monkey":
			_add_sphere(root, "EarL", Vector3(-0.40, 1.30, -0.70), Vector3(0.19, 0.23, 0.12), secondary)
			_add_sphere(root, "EarR", Vector3(0.40, 1.30, -0.70), Vector3(0.19, 0.23, 0.12), secondary)
			_add_sphere(root, "FacePatch", Vector3(0, 1.20, -1.02), Vector3(0.36, 0.38, 0.13), secondary)

func _add_round_ears(root: Node3D, color: Color, x: float, radius: float) -> void:
	_add_sphere(root, "EarL", Vector3(-x, 1.55, -0.67), Vector3(radius, radius, radius * 0.72), color)
	_add_sphere(root, "EarR", Vector3(x, 1.55, -0.67), Vector3(radius, radius, radius * 0.72), color)

func _add_tail(root: Node3D, fur: Color, secondary: Color, dark: Color) -> void:
	match species:
		&"fox":
			_add_capsule(root, "Tail", Vector3(0, 1.00, 0.98), Vector3(0.90, 0, 0), Vector3(0.16, 0.53, 0.16), fur)
			_add_sphere(root, "TailTip", Vector3(0, 1.30, 1.36), Vector3(0.19, 0.25, 0.19), secondary, true)
		&"raccoon":
			for i in range(5):
				_add_capsule(root, "TailBand%d" % i, Vector3(0, 0.98 + i * 0.07, 0.92 + i * 0.16), Vector3(0.86, 0, 0), Vector3(0.12, 0.18, 0.12), dark if i % 2 == 0 else secondary, true)
		&"wolf":
			_add_capsule(root, "Tail", Vector3(0, 1.02, 0.98), Vector3(0.82, 0, 0), Vector3(0.14, 0.48, 0.14), dark)
		&"monkey":
			_add_capsule(root, "TailA", Vector3(0, 1.00, 1.00), Vector3(0.95, 0, 0), Vector3(0.08, 0.46, 0.08), fur)
			_add_capsule(root, "TailB", Vector3(0.24, 1.32, 1.30), Vector3(0.35, 0, -0.65), Vector3(0.075, 0.42, 0.075), fur, true)
			_add_capsule(root, "TailC", Vector3(0.40, 1.62, 1.18), Vector3(-0.35, 0, -0.72), Vector3(0.07, 0.34, 0.07), fur, true)
		_:
			_add_sphere(root, "Tail", Vector3(0, 1.02, 0.92), Vector3(0.18, 0.18, 0.18), secondary if species == &"deer" else fur)

func _add_antlers(root: Node3D, color: Color) -> void:
	for side in [-1.0, 1.0]:
		_add_box(root, "AntlerStem%s" % str(side), Vector3(0.22 * side, 1.82, -0.66), Vector3(0.07, 0.42, 0.07), color, true)
		_add_box(root, "AntlerBranch%s" % str(side), Vector3(0.32 * side, 1.94, -0.66), Vector3(0.24, 0.06, 0.06), color, true)
		_add_box(root, "AntlerTip%s" % str(side), Vector3(0.39 * side, 2.05, -0.66), Vector3(0.07, 0.24, 0.06), color, true)

func _add_face(root: Node3D, dark: Color, accent: Color) -> void:
	var eye_x := 0.20 if species in [&"bear", &"panda", &"boar"] else 0.18
	for side in [-1.0, 1.0]:
		_add_sphere(root, "Eye%s" % str(side), Vector3(eye_x * side, 1.30, -1.075), Vector3(0.115, 0.13, 0.07), Color("f4f7f8"))
		_add_sphere(root, "Iris%s" % str(side), Vector3(eye_x * side, 1.30, -1.137), Vector3(0.055, 0.065, 0.035), accent, true)
		_add_sphere(root, "Pupil%s" % str(side), Vector3(eye_x * side, 1.30, -1.161), Vector3(0.026, 0.036, 0.020), Color("16191b"), true)
	_add_sphere(root, "Nose", Vector3(0, 1.09, -1.19), Vector3(0.095, 0.07, 0.07), dark, true)

func _profile(id: StringName) -> Dictionary:
	match id:
		&"fox": return _make_profile("e97832", "f5dfc0", "492a24", "d9a53c", Vector3(0.48, 0.70, 0.48), Vector3(0.42, 0.43, 0.45))
		&"bear": return _make_profile("745038", "cda981", "38271f", "b77b4d", Vector3(0.62, 0.76, 0.62), Vector3(0.54, 0.52, 0.52))
		&"raccoon": return _make_profile("747d82", "c9c7b9", "25292d", "b69ad8", Vector3(0.48, 0.66, 0.48), Vector3(0.43, 0.43, 0.44))
		&"panda": return _make_profile("f0eadc", "f2e9d6", "17191b", "79c2d0", Vector3(0.60, 0.75, 0.60), Vector3(0.53, 0.52, 0.51))
		&"wolf": return _make_profile("6d7780", "c2c8c8", "343b42", "8fb7c9", Vector3(0.50, 0.71, 0.49), Vector3(0.43, 0.44, 0.48))
		&"boar": return _make_profile("7d5142", "b0836c", "352a27", "b66d6b", Vector3(0.62, 0.68, 0.64), Vector3(0.50, 0.46, 0.50))
		&"deer": return _make_profile("b57943", "e4c49b", "513426", "94c27d", Vector3(0.44, 0.75, 0.44), Vector3(0.39, 0.45, 0.47))
		&"monkey": return _make_profile("8c623f", "d8aa78", "3a2a22", "f0a95d", Vector3(0.43, 0.62, 0.43), Vector3(0.41, 0.43, 0.40))
		_: return _make_profile("888888", "dddddd", "333333", "f0b64a", Vector3(0.48, 0.68, 0.48), Vector3(0.43, 0.43, 0.43))

func _make_profile(fur: String, secondary: String, dark: String, accent: String, body: Vector3, head: Vector3) -> Dictionary:
	return {"fur": Color(fur), "secondary": Color(secondary), "dark": Color(dark), "accent": Color(accent), "body": body, "head": head}

func _add_sphere(root: Node3D, node_name: String, pos: Vector3, scale_value: Vector3, color: Color, micro := false) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return _add_mesh(root, node_name, mesh, pos, Vector3.ZERO, scale_value, color, micro)

func _add_capsule(root: Node3D, node_name: String, pos: Vector3, rot: Vector3, scale_value: Vector3, color: Color, micro := false) -> MeshInstance3D:
	var mesh := CapsuleMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 2
	return _add_mesh(root, node_name, mesh, pos, rot, scale_value, color, micro)

func _add_box(root: Node3D, node_name: String, pos: Vector3, scale_value: Vector3, color: Color, micro := false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	return _add_mesh(root, node_name, mesh, pos, Vector3.ZERO, scale_value, color, micro)

func _add_cone(root: Node3D, node_name: String, pos: Vector3, rot: Vector3, scale_value: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 7
	return _add_mesh(root, node_name, mesh, pos, rot, scale_value, color, true)

func _add_mesh(root: Node3D, node_name: String, mesh: PrimitiveMesh, pos: Vector3, rot: Vector3, scale_value: Vector3, color: Color, micro: bool) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = pos
	node.rotation = rot
	node.scale = scale_value
	mesh.material = _material(color)
	node.mesh = mesh
	root.add_child(node)
	if micro:
		_micro_nodes.append(node)
	else:
		_detail_nodes.append(node)
	return node

static func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	_material_cache[key] = material
	return material
