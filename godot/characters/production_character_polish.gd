class_name WildDashProductionCharacterPolish
extends Node3D

## RC7 production-art bridge shared by all 12 racers.
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
		&"bear":
			_build_bear()
		&"panda":
			_build_panda()
		&"fox":
			_build_fox()
		&"deer":
			_build_deer()
		&"wolf":
			_build_wolf()
		&"monkey":
			_build_monkey()
		&"boar":
			_build_boar()
		&"raccoon":
			_build_raccoon()
		_:
			_build_dog()

func _build_dog() -> void:
	var cream := _material(Color(1.0, 0.86, 0.62, 1.0), 0.78)
	var orange := _material(Color(1.0, 0.42, 0.16, 1.0), 0.72)
	var teal := _material(Color(0.08, 0.76, 0.78, 1.0), 0.48)
	var dark := _material(Color(0.16, 0.09, 0.06, 1.0), 0.70)
	var blush := _material(Color(1.0, 0.50, 0.45, 0.86), 0.74)
	_add_ellipsoid("ChestBib", Vector3(0, 0.92, -0.39), Vector3(0.31, 0.34, 0.12), cream)
	_add_band("Collar", Vector3(0, 1.13, -0.32), Vector3(0.43, 0.075, 0.39), teal)
	_add_box("CollarTag", Vector3(0, 1.04, -0.73), Vector3(0.16, 0.16, 0.055), orange, Vector3(0, 0, 0.20))
	for x in [-0.33, 0.33]:
		_add_band("PawCuff", Vector3(x, 0.23, -0.38), Vector3(0.14, 0.09, 0.14), cream)
		_add_band("PawCuff", Vector3(x, 0.23, 0.42), Vector3(0.14, 0.09, 0.14), cream)
	_add_ellipsoid("BackMark", Vector3(0, 1.02, 0.40), Vector3(0.29, 0.17, 0.08), dark)
	_add_ellipsoid("TailTip", Vector3(0, 1.28, 1.09), Vector3(0.12, 0.16, 0.12), cream)
	_add_cheeks(Vector3(0.25, 1.07, -1.09), Vector3(0.07, 0.045, 0.025), blush)
	_add_box("SidePanelL", Vector3(-0.43, 0.92, 0.05), Vector3(0.055, 0.30, 0.34), teal, Vector3(0.0, 0.0, -0.12))
	_add_box("SidePanelR", Vector3(0.43, 0.92, 0.05), Vector3(0.055, 0.30, 0.34), teal, Vector3(0.0, 0.0, 0.12))
	_add_ellipsoid("HeroBadge", Vector3(0, 0.96, -0.56), Vector3(0.095, 0.095, 0.035), orange)

func _build_rabbit() -> void:
	var white := _material(Color(1.0, 0.91, 0.95, 1.0), 0.78)
	var coral := _material(Color(1.0, 0.36, 0.56, 1.0), 0.68)
	var mint := _material(Color(0.26, 0.86, 0.68, 1.0), 0.52)
	var berry := _material(Color(0.60, 0.18, 0.45, 1.0), 0.68)
	_add_ellipsoid("ChestBib", Vector3(0, 0.80, -0.34), Vector3(0.27, 0.31, 0.11), white)
	for x in [-0.18, 0.18]:
		_add_capsule("InnerEar", Vector3(x, 1.73, -0.58), 0.055, 0.62, coral, Vector3(0.04, 0, 0))
	for x in [-0.29, 0.29]:
		_add_ellipsoid("HindPaw", Vector3(x, 0.17, 0.40), Vector3(0.17, 0.09, 0.24), white)
	_add_band("RunnerBand", Vector3(0, 0.94, -0.19), Vector3(0.39, 0.055, 0.33), mint)
	_add_box("RunnerBadge", Vector3(0, 0.91, -0.54), Vector3(0.13, 0.16, 0.045), coral, Vector3(0, 0, -0.10))
	_add_cheeks(Vector3(0.22, 1.04, -0.89), Vector3(0.065, 0.040, 0.024), coral)
	_add_ellipsoid("ForeheadBlaze", Vector3(0, 1.35, -0.83), Vector3(0.10, 0.16, 0.035), white)
	_add_box("ShoulderStripeL", Vector3(-0.36, 0.84, -0.02), Vector3(0.045, 0.28, 0.28), berry, Vector3(0.0, 0.0, -0.12))
	_add_box("ShoulderStripeR", Vector3(0.36, 0.84, -0.02), Vector3(0.045, 0.28, 0.28), berry, Vector3(0.0, 0.0, 0.12))

func _build_cat() -> void:
	var lavender := _material(Color(0.88, 0.70, 1.0, 1.0), 0.72)
	var plum := _material(Color(0.18, 0.06, 0.26, 1.0), 0.66)
	var gold := _material(Color(1.0, 0.66, 0.16, 1.0), 0.46)
	var pink := _material(Color(1.0, 0.42, 0.62, 1.0), 0.64)
	_add_ellipsoid("ChestPatch", Vector3(0, 0.77, -0.33), Vector3(0.24, 0.28, 0.09), lavender)
	for side in [-1.0, 1.0]:
		_add_box("EarInset", Vector3(side * 0.22, 1.43, -0.56), Vector3(0.105, 0.19, 0.055), lavender, Vector3(0.10, -side * 0.15, side * 0.42))
	for z in [-0.20, 0.04, 0.28]:
		_add_box("BackStripe", Vector3(0, 0.98, z), Vector3(0.54, 0.055, 0.10), plum, Vector3(0.06, 0, 0))
	_add_band("Collar", Vector3(0, 1.01, -0.32), Vector3(0.36, 0.055, 0.33), gold)
	_add_ellipsoid("Bell", Vector3(0, 0.96, -0.69), Vector3(0.075, 0.075, 0.055), gold)
	_add_ellipsoid("TailTip", Vector3(0.26, 1.46, 1.08), Vector3(0.10, 0.15, 0.10), lavender)
	_add_cheeks(Vector3(0.22, 0.99, -0.92), Vector3(0.055, 0.035, 0.022), pink)
	_add_box("RacePanelL", Vector3(-0.32, 0.79, 0.07), Vector3(0.045, 0.27, 0.32), gold, Vector3(0.0, 0.0, -0.10))
	_add_box("RacePanelR", Vector3(0.32, 0.79, 0.07), Vector3(0.045, 0.27, 0.32), gold, Vector3(0.0, 0.0, 0.10))
	_add_ellipsoid("HeroBadge", Vector3(0, 0.82, -0.52), Vector3(0.085, 0.085, 0.030), pink)

func _build_elephant() -> void:
	var ear_inner := _material(Color(0.62, 0.62, 0.86, 1.0), 0.80)
	var ivory := _material(Color(1.0, 0.92, 0.72, 1.0), 0.66)
	var cyan := _material(Color(0.12, 0.74, 0.88, 1.0), 0.50)
	var navy := _material(Color(0.18, 0.24, 0.42, 1.0), 0.72)
	var coral := _material(Color(1.0, 0.46, 0.40, 1.0), 0.66)
	for side in [-1.0, 1.0]:
		_add_ellipsoid("EarInset", Vector3(side * 0.57, 1.43, -0.70), Vector3(0.055, 0.32, 0.25), ear_inner)
	for x in [-0.46, 0.46]:
		for z in [-0.38, 0.48]:
			_add_band("FootCuff", Vector3(x, 0.20, z), Vector3(0.19, 0.10, 0.19), ivory)
	_add_band("RaceHarness", Vector3(0, 1.09, 0.12), Vector3(0.66, 0.075, 0.54), cyan)
	_add_box("HarnessBadge", Vector3(0, 1.09, -0.51), Vector3(0.21, 0.20, 0.06), navy, Vector3(0, 0, 0.08))
	_add_ellipsoid("ForeheadMark", Vector3(0, 1.63, -1.16), Vector3(0.17, 0.10, 0.055), cyan)
	_add_cheeks(Vector3(0.28, 1.27, -1.28), Vector3(0.07, 0.045, 0.024), coral)
	_add_box("HarnessWingL", Vector3(-0.58, 1.10, 0.10), Vector3(0.055, 0.34, 0.42), navy, Vector3(0.0, 0.0, -0.08))
	_add_box("HarnessWingR", Vector3(0.58, 1.10, 0.10), Vector3(0.055, 0.34, 0.42), navy, Vector3(0.0, 0.0, 0.08))
	_add_ellipsoid("TrunkTipAccent", Vector3(0, 0.62, -1.22), Vector3(0.11, 0.08, 0.06), ivory)

func _build_bear() -> void:
	var cream := _material(Color(0.92, 0.78, 0.60, 1.0), 0.82)
	var honey := _material(Color(1.0, 0.61, 0.16, 1.0), 0.58)
	var teal := _material(Color(0.10, 0.70, 0.72, 1.0), 0.52)
	var brown := _material(Color(0.30, 0.18, 0.12, 1.0), 0.76)
	_add_ellipsoid("BellyPatch", Vector3(0, 0.88, -0.43), Vector3(0.38, 0.38, 0.12), cream)
	_add_ellipsoid("EarInsetL", Vector3(-0.34, 1.56, -0.80), Vector3(0.105, 0.105, 0.035), cream)
	_add_ellipsoid("EarInsetR", Vector3(0.34, 1.56, -0.80), Vector3(0.105, 0.105, 0.035), cream)
	_add_band("RaceSash", Vector3(0, 1.02, -0.02), Vector3(0.58, 0.065, 0.49), teal)
	_add_ellipsoid("ChestMedal", Vector3(0, 0.99, -0.58), Vector3(0.10, 0.10, 0.035), honey)
	for x in [-0.32, 0.32]:
		_add_band("PawCuff", Vector3(x, 0.23, -0.38), Vector3(0.14, 0.09, 0.14), honey)
	_add_box("BackStripe", Vector3(0, 1.13, 0.36), Vector3(0.54, 0.07, 0.12), brown, Vector3(0.08, 0, 0))

func _build_panda() -> void:
	var white := _material(Color(0.96, 0.94, 0.88, 1.0), 0.80)
	var ink := _material(Color(0.08, 0.09, 0.11, 1.0), 0.70)
	var mint := _material(Color(0.22, 0.82, 0.72, 1.0), 0.50)
	var lemon := _material(Color(1.0, 0.78, 0.22, 1.0), 0.56)
	_add_ellipsoid("BellyPatch", Vector3(0, 0.88, -0.44), Vector3(0.36, 0.36, 0.12), white)
	_add_band("RaceSash", Vector3(0, 1.01, -0.04), Vector3(0.56, 0.064, 0.48), mint)
	_add_box("BambooBadge", Vector3(0, 0.98, -0.59), Vector3(0.16, 0.19, 0.05), lemon, Vector3(0, 0, 0.10))
	for x in [-0.32, 0.32]:
		_add_band("PawCuff", Vector3(x, 0.23, -0.38), Vector3(0.14, 0.09, 0.14), ink)
	_add_ellipsoid("HeadHighlight", Vector3(0, 1.49, -0.92), Vector3(0.16, 0.09, 0.035), white)

func _build_fox() -> void:
	var cream := _material(Color(1.0, 0.86, 0.68, 1.0), 0.78)
	var charcoal := _material(Color(0.18, 0.12, 0.12, 1.0), 0.72)
	var cyan := _material(Color(0.12, 0.78, 0.86, 1.0), 0.48)
	var orange := _material(Color(1.0, 0.47, 0.12, 1.0), 0.64)
	_add_ellipsoid("ChestFluff", Vector3(0, 0.89, -0.43), Vector3(0.31, 0.35, 0.11), cream)
	for side in [-1.0, 1.0]:
		_add_box("EarInset", Vector3(side * 0.27, 1.62, -0.75), Vector3(0.09, 0.18, 0.045), cream, Vector3(0.08, 0.0, side * 0.15))
	_add_band("SpeedBand", Vector3(0, 1.00, -0.06), Vector3(0.46, 0.055, 0.41), cyan)
	_add_ellipsoid("SpeedBadge", Vector3(0, 0.98, -0.58), Vector3(0.085, 0.085, 0.03), orange)
	for x in [-0.32, 0.32]:
		_add_band("PawSock", Vector3(x, 0.22, -0.38), Vector3(0.13, 0.085, 0.13), charcoal)

func _build_deer() -> void:
	var cream := _material(Color(0.94, 0.83, 0.66, 1.0), 0.82)
	var mint := _material(Color(0.40, 0.82, 0.62, 1.0), 0.54)
	var forest := _material(Color(0.18, 0.34, 0.25, 1.0), 0.68)
	_add_ellipsoid("ChestPatch", Vector3(0, 0.91, -0.41), Vector3(0.29, 0.34, 0.10), cream)
	_add_band("TrailBand", Vector3(0, 1.02, -0.05), Vector3(0.43, 0.055, 0.38), mint)
	_add_ellipsoid("TrailBadge", Vector3(0, 0.99, -0.56), Vector3(0.08, 0.08, 0.03), forest)
	for x in [-0.22, 0.22]:
		for z in [0.04, 0.26, 0.48]:
			_add_ellipsoid("BackSpot", Vector3(x, 1.19, z), Vector3(0.045, 0.035, 0.022), cream)
	for x in [-0.32, 0.32]:
		_add_band("HoofCuff", Vector3(x, 0.20, -0.38), Vector3(0.13, 0.08, 0.13), forest)

func _build_wolf() -> void:
	var silver := _material(Color(0.78, 0.82, 0.84, 1.0), 0.78)
	var navy := _material(Color(0.12, 0.20, 0.30, 1.0), 0.68)
	var cyan := _material(Color(0.18, 0.72, 0.88, 1.0), 0.50)
	_add_ellipsoid("ChestMane", Vector3(0, 0.91, -0.43), Vector3(0.31, 0.37, 0.11), silver)
	_add_band("ScoutBand", Vector3(0, 1.03, -0.05), Vector3(0.46, 0.055, 0.40), cyan)
	_add_box("ScoutBadge", Vector3(0, 1.00, -0.58), Vector3(0.14, 0.17, 0.05), navy, Vector3(0, 0, -0.08))
	for side in [-1.0, 1.0]:
		_add_box("EarInset", Vector3(side * 0.28, 1.64, -0.76), Vector3(0.08, 0.17, 0.04), silver, Vector3(0.08, 0.0, side * 0.12))
	for x in [-0.32, 0.32]:
		_add_band("PawCuff", Vector3(x, 0.22, -0.38), Vector3(0.13, 0.085, 0.13), navy)

func _build_monkey() -> void:
	var tan := _material(Color(0.90, 0.70, 0.48, 1.0), 0.78)
	var mango := _material(Color(1.0, 0.62, 0.18, 1.0), 0.54)
	var aqua := _material(Color(0.14, 0.78, 0.76, 1.0), 0.50)
	var cocoa := _material(Color(0.24, 0.15, 0.11, 1.0), 0.72)
	_add_ellipsoid("BellyPatch", Vector3(0, 0.86, -0.39), Vector3(0.28, 0.31, 0.10), tan)
	_add_band("AdventureBand", Vector3(0, 0.99, -0.02), Vector3(0.41, 0.055, 0.36), mango)
	_add_ellipsoid("AdventureBadge", Vector3(0, 0.96, -0.53), Vector3(0.08, 0.08, 0.03), aqua)
	for x in [-0.32, 0.32]:
		_add_band("WristCuff", Vector3(x, 0.27, -0.38), Vector3(0.12, 0.075, 0.12), aqua)
	_add_band("TailBand", Vector3(0, 1.16, 1.08), Vector3(0.14, 0.045, 0.14), cocoa)

func _build_boar() -> void:
	var cream := _material(Color(0.94, 0.84, 0.66, 1.0), 0.82)
	var coral := _material(Color(0.88, 0.38, 0.36, 1.0), 0.64)
	var orange := _material(Color(1.0, 0.54, 0.16, 1.0), 0.54)
	var dark := _material(Color(0.20, 0.14, 0.13, 1.0), 0.72)
	_add_ellipsoid("ChestPlate", Vector3(0, 0.87, -0.42), Vector3(0.33, 0.31, 0.10), cream)
	_add_band("PowerHarness", Vector3(0, 1.00, -0.01), Vector3(0.56, 0.065, 0.48), orange)
	_add_ellipsoid("PowerBadge", Vector3(0, 0.97, -0.58), Vector3(0.09, 0.09, 0.03), coral)
	_add_box("ForeheadStripe", Vector3(0, 1.47, -1.01), Vector3(0.12, 0.23, 0.04), cream, Vector3(0.10, 0.0, 0.0))
	for x in [-0.32, 0.32]:
		_add_band("HoofCuff", Vector3(x, 0.20, -0.38), Vector3(0.14, 0.08, 0.14), dark)

func _build_raccoon() -> void:
	var cream := _material(Color(0.86, 0.84, 0.78, 1.0), 0.80)
	var violet := _material(Color(0.56, 0.34, 0.82, 1.0), 0.58)
	var teal := _material(Color(0.12, 0.76, 0.76, 1.0), 0.50)
	var ink := _material(Color(0.13, 0.15, 0.18, 1.0), 0.70)
	_add_ellipsoid("ChestPatch", Vector3(0, 0.86, -0.41), Vector3(0.29, 0.31, 0.10), cream)
	_add_band("BanditScarf", Vector3(0, 1.02, -0.05), Vector3(0.44, 0.06, 0.39), violet)
	_add_ellipsoid("ScarfBadge", Vector3(0, 0.99, -0.56), Vector3(0.08, 0.08, 0.03), teal)
	for x in [-0.32, 0.32]:
		_add_band("PawCuff", Vector3(x, 0.21, -0.38), Vector3(0.13, 0.08, 0.13), ink)
	_add_band("TailAccent", Vector3(0, 1.18, 1.28), Vector3(0.14, 0.045, 0.14), teal)

func _add_cheeks(anchor: Vector3, scale: Vector3, material: Material) -> void:
	_add_ellipsoid("CheekL", Vector3(-anchor.x, anchor.y, anchor.z), scale, material)
	_add_ellipsoid("CheekR", Vector3(anchor.x, anchor.y, anchor.z), scale, material)

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
