extends WildDashCharacterVisual

## Lightweight procedural crocodile for the RC9 roster swap. The shape is kept
## intentionally simple/low-poly so it matches the existing prototype animals.

var _materials: Dictionary = {}

func _ready() -> void:
	_build_crocodile()
	super._ready()

func _build_crocodile() -> void:
	var root := get_node_or_null("ImportedModel") as Node3D
	if root == null:
		root = Node3D.new()
		root.name = "ImportedModel"
		add_child(root)

	var green := Color("587b3b")
	var light := Color("9ab36a")
	var dark := Color("263c24")
	var eye := Color("e9c84c")
	var tooth := Color("f1ead3")

	_add_capsule(root, "Body", Vector3(0.0, 0.72, 0.10), Vector3(PI * 0.5, 0.0, 0.0), Vector3(0.62, 0.92, 0.58), green)
	_add_box(root, "Belly", Vector3(0.0, 0.55, -0.06), Vector3(0.72, 0.24, 1.18), light)
	_add_box(root, "Head", Vector3(0.0, 0.86, -0.78), Vector3(0.78, 0.58, 0.72), green)
	_add_box(root, "Snout", Vector3(0.0, 0.76, -1.38), Vector3(0.72, 0.34, 0.76), light)

	for side in [-1.0, 1.0]:
		_add_sphere(root, "Eye_%s" % str(side), Vector3(0.29 * side, 1.10, -0.98), Vector3(0.11, 0.13, 0.10), eye)
		_add_sphere(root, "Pupil_%s" % str(side), Vector3(0.29 * side, 1.11, -1.075), Vector3(0.045, 0.065, 0.035), dark)
		for tooth_index in range(3):
			var x := (0.18 + float(tooth_index) * 0.13) * side
			_add_cone(root, "Tooth_%s_%d" % [str(side), tooth_index], Vector3(x, 0.64, -1.72), Vector3(PI, 0.0, 0.0), Vector3(0.045, 0.10, 0.045), tooth)

	var leg_positions := [
		Vector3(-0.48, 0.38, -0.36), Vector3(0.48, 0.38, -0.36),
		Vector3(-0.48, 0.38, 0.48), Vector3(0.48, 0.38, 0.48),
	]
	for i in range(leg_positions.size()):
		_add_capsule(root, "Leg_%d" % i, leg_positions[i], Vector3(0.0, 0.0, PI * 0.5), Vector3(0.12, 0.32, 0.12), dark)

	_add_capsule(root, "TailA", Vector3(0.0, 0.66, 1.10), Vector3(PI * 0.5, 0.0, 0.0), Vector3(0.34, 0.72, 0.34), green)
	_add_capsule(root, "TailB", Vector3(0.0, 0.61, 1.88), Vector3(PI * 0.5, 0.0, 0.0), Vector3(0.22, 0.62, 0.22), green)
	_add_cone(root, "TailTip", Vector3(0.0, 0.58, 2.56), Vector3(-PI * 0.5, 0.0, 0.0), Vector3(0.18, 0.58, 0.18), green)

	for i in range(5):
		var z := -0.15 + float(i) * 0.38
		_add_cone(root, "BackScale_%d" % i, Vector3(0.0, 1.26, z), Vector3.ZERO, Vector3(0.11, 0.18, 0.11), dark)

func _add_box(root: Node3D, node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add_mesh(root, node_name, mesh, pos, Vector3.ZERO, color)

func _add_sphere(root: Node3D, node_name: String, pos: Vector3, scale_value: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 4
	var node := _add_mesh(root, node_name, mesh, pos, Vector3.ZERO, color)
	node.scale = scale_value

func _add_capsule(root: Node3D, node_name: String, pos: Vector3, rot: Vector3, scale_value: Vector3, color: Color) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh.rings = 2
	var node := _add_mesh(root, node_name, mesh, pos, rot, color)
	node.scale = scale_value

func _add_cone(root: Node3D, node_name: String, pos: Vector3, rot: Vector3, scale_value: Vector3, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	var node := _add_mesh(root, node_name, mesh, pos, rot, color)
	node.scale = scale_value

func _add_mesh(root: Node3D, node_name: String, mesh: PrimitiveMesh, pos: Vector3, rot: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.position = pos
	node.rotation = rot
	node.mesh = mesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.material_override = _material(color)
	root.add_child(node)
	return node

func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(true)
	if _materials.has(key):
		return _materials[key] as StandardMaterial3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	_materials[key] = material
	return material
