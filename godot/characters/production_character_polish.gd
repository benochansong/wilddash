class_name WildDashProductionCharacterPolish
extends Node3D

## RC7 production-art bridge for the four playable racers.
## Adds visual-only low-poly hero details while preserving the existing
## CharacterController, collision body, skills, AI and VisualModel contract.
## When authored GLB characters arrive this node can be removed without
## touching gameplay code.

@export var species: StringName = &"dog"
@export var imported_model_path: NodePath = NodePath("../ImportedModel")

var _root: Node3D

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var model := get_node_or_null(imported_model_path) as Node3D
	if model == null:
		push_warning("ProductionCharacterPolish could not resolve ImportedModel for %s" % species)
		return
	_root = Node3D.new()
	_root.name = "ProductionArtDetail"
	model.add_child(_root)
	match species:
		&"rabbit":
			_build_rabbit()
		&"cat":
			_build_cat()
		&"elephant":
			_build_elephant()
		_:
			_build_dog()

func _build_dog() -> void:
	var cream := _material(Color(1.0, 0.86, 0.62, 1.0), 0.78)
	var orange := _material(Color(1.0, 0.42, 0.16, 1.0), 0.72)
	var teal := _material(Color(0.08, 0.76, 0.78, 1.0), 0.48)
	var dark := _material(Color(0.16, 0.09, 0.06, 1.0), 0.70)
	_add_ellipsoid("ChestBib", Vector3(0, 0.92, -0.39), Vector3(0.31, 0.34, 0.12), cream)
	_add_band("Collar", Vector3(0, 1.13, -0.32), Vector3(0.43, 0.075, 0.39), teal)
	_add_box("CollarTag", Vector3(0, 1.04, -0.73), Vector3(0.16, 0.16, 0.055), orange, Vector3(0, 0, 0.20))
	for x in [-0.33, 0.33]:
		_add_band("PawCuff", Vector3(x, 0.23, -0.38), Vector3(0.14, 0.09, 0.14), cream)
		_add_band("PawCuff", Vector3(x, 0.23, 0.42), Vector3(0.14, 0.09, 0.14), cream)
	_add_ellipsoid("BackMark", Vector3(0, 1.02, 0.40), Vector3(0.29, 0.17, 0.08), dark)
	_add_ellipsoid("TailTip", Vector3(0, 1.28, 1.09), Vector3(0.12, 0.16, 0.12), cream)

func _build_rabbit() -> void:
	var white := _material(Color(1.0, 0.91, 0.95, 1.0), 0.78)
	var coral := _material(Color(1.0, 0.36, 0.56, 1.0), 0.68)
	var mint := _material(Color(0.26, 0.86, 0.68, 1.0), 0.52)
	_add_ellipsoid("ChestBib", Vector3(0, 0.80, -0.34), Vector3(0.27, 0.31, 0.11), white)
	for x in [-0.18, 0.18]:
		_add_capsule("InnerEar", Vector3(x, 1.73, -0.58), 0.055, 0.62, coral, Vector3(0.04, 0, 0))
	for x in [-0.29, 0.29]:
		_add_ellipsoid("HindPaw", Vector3(x, 0.17, 0.40), Vector3(0.17, 0.09, 0.24), white)
	_add_band("RunnerBand", Vector3(0, 0.94, -0.19), Vector3(0.39, 0.055, 0.33), mint)
	_add_box("RunnerBadge", Vector3(0, 0.91, -0.54), Vector3(0.13, 0.16, 0.045), coral, Vector3(0, 0, -0.10))

func _build_cat() -> void:
	var lavender := _material(Color(0.88, 0.70, 1.0, 1.0), 0.72)
	var plum := _material(Color(0.18, 0.06, 0.26, 1.0), 0.66)
	var gold := _material(Color(1.0, 0.66, 0.16, 1.0), 0.46)
	_add_ellipsoid("ChestPatch", Vector3(0, 0.77, -0.33), Vector3(0.24, 0.28, 0.09), lavender)
	for side in [-1.0, 1.0]:
		_add_box("EarInset", Vector3(side * 0.22, 1.43, -0.56), Vector3(0.105, 0.19, 0.055), lavender, Vector3(0.10, -side * 0.15, side * 0.42))
	for z in [-0.20, 0.04, 0.28]:
		_add_box("BackStripe", Vector3(0, 0.98, z), Vector3(0.54, 0.055, 0.10), plum, Vector3(0.06, 0, 0))
	_add_band("Collar", Vector3(0, 1.01, -0.32), Vector3(0.36, 0.055, 0.33), gold)
	_add_ellipsoid("Bell", Vector3(0, 0.96, -0.69), Vector3(0.075, 0.075, 0.055), gold)
	_add_ellipsoid("TailTip", Vector3(0.26, 1.46, 1.08), Vector3(0.10, 0.15, 0.10), lavender)

func _build_elephant() -> void:
	var ear_inner := _material(Color(0.62, 0.62, 0.86, 1.0), 0.80)
	var ivory := _material(Color(1.0, 0.92, 0.72, 1.0), 0.66)
	var cyan := _material(Color(0.12, 0.74, 0.88, 1.0), 0.50)
	var navy := _material(Color(0.18, 0.24, 0.42, 1.0), 0.72)
	for side in [-1.0, 1.0]:
		_add_ellipsoid("EarInset", Vector3(side * 0.57, 1.43, -0.70), Vector3(0.055, 0.32, 0.25), ear_inner)
	for x in [-0.46, 0.46]:
		for z in [-0.38, 0.48]:
			_add_band("FootCuff", Vector3(x, 0.20, z), Vector3(0.19, 0.10, 0.19), ivory)
	_add_band("RaceHarness", Vector3(0, 1.09, 0.12), Vector3(0.66, 0.075, 0.54), cyan)
	_add_box("HarnessBadge", Vector3(0, 1.09, -0.51), Vector3(0.21, 0.20, 0.06), navy, Vector3(0, 0, 0.08))
	_add_ellipsoid("ForeheadMark", Vector3(0, 1.63, -1.16), Vector3(0.17, 0.10, 0.055), cyan)

func _material(color: Color, roughness: float, metallic := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _add_ellipsoid(node_name: String, position: Vector3, scale: Vector3, material: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.rings = 6
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.scale = scale * 2.0
	_root.add_child(instance)

func _add_capsule(node_name: String, position: Vector3, radius: float, height: float, material: Material, rotation := Vector3.ZERO) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 3
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation
	_root.add_child(instance)

func _add_box(node_name: String, position: Vector3, size: Vector3, material: Material, rotation := Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.rotation = rotation
	_root.add_child(instance)

func _add_band(node_name: String, position: Vector3, scale: Vector3, material: Material) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.40
	mesh.outer_radius = 0.50
	mesh.rings = 12
	mesh.ring_segments = 8
	mesh.material = material
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.scale = scale
	instance.rotation.x = deg_to_rad(90.0)
	_root.add_child(instance)
