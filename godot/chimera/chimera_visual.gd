class_name WildDashChimeraVisual
extends WildDashCharacterVisual

## Lightweight modular preview/runtime visual. Production GLB parts can replace the
## generated meshes later without changing CharacterController or ChimeraSystem.

var loadout: WildDashChimeraLoadout
var _model_root: Node3D
var _head_anchor: Node3D
var _body_anchor: Node3D
var _tail_anchor: Node3D
var _pattern_anchor: Node3D

func _ready() -> void:
	procedural_placeholder = true
	_build_scaffold()
	if loadout == null:
		loadout = WildDashChimeraSystem.default_loadout()
	_rebuild_parts()
	super._ready()

func configure_loadout(value: WildDashChimeraLoadout) -> void:
	loadout = value.duplicate_loadout() if value != null else WildDashChimeraSystem.default_loadout()
	if is_inside_tree():
		_rebuild_parts()

func get_loadout() -> WildDashChimeraLoadout:
	return loadout

func _build_scaffold() -> void:
	_model_root = Node3D.new()
	_model_root.name = "ImportedModel"
	add_child(_model_root)
	procedural_root_path = NodePath("ImportedModel")

	var skeleton := Skeleton3D.new()
	skeleton.name = "Skeleton3D"
	_model_root.add_child(skeleton)

	_head_anchor = Node3D.new()
	_head_anchor.name = "HeadSlot"
	_model_root.add_child(_head_anchor)
	_body_anchor = Node3D.new()
	_body_anchor.name = "BodySlot"
	_model_root.add_child(_body_anchor)
	_tail_anchor = Node3D.new()
	_tail_anchor.name = "TailSlot"
	_model_root.add_child(_tail_anchor)
	_pattern_anchor = Node3D.new()
	_pattern_anchor.name = "PatternSlot"
	_model_root.add_child(_pattern_anchor)

	var animation_player := AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	_model_root.add_child(animation_player)

func _rebuild_parts() -> void:
	if _model_root == null or loadout == null:
		return
	loadout.normalize()
	_clear_anchor(_head_anchor)
	_clear_anchor(_body_anchor)
	_clear_anchor(_tail_anchor)
	_clear_anchor(_pattern_anchor)
	_build_body(loadout.body_id)
	_build_head(loadout.head_id)
	_build_tail(loadout.tail_id)
	_build_pattern(loadout.pattern_id)

func _build_body(source: StringName) -> void:
	var definition := WildDashAnimalCatalog.get_definition(source)
	var color := WildDashChimeraSystem.palette_color(loadout.palette_id, definition.accent_color)
	var scale := Vector3(1.0, 1.0, 1.0)
	match source:
		&"rabbit": scale = Vector3(0.88, 0.92, 1.02)
		&"elephant": scale = Vector3(1.25, 1.14, 1.30)
		&"cat": scale = Vector3(0.86, 0.90, 1.16)
		_: scale = Vector3(1.0, 1.0, 1.08)
	var body := _mesh_instance(_capsule_mesh(0.58, 1.25), color)
	body.name = "%sBody" % String(source).capitalize()
	body.position = Vector3(0.0, 0.92, 0.05)
	body.scale = scale
	_body_anchor.add_child(body)

	for x in [-0.36, 0.36]:
		for z in [-0.34, 0.34]:
			var leg := _mesh_instance(_capsule_mesh(0.13, 0.62), color.darkened(0.08))
			leg.position = Vector3(x * scale.x, 0.40, z * scale.z)
			_body_anchor.add_child(leg)

func _build_head(source: StringName) -> void:
	var definition := WildDashAnimalCatalog.get_definition(source)
	var color := definition.accent_color
	var head := _mesh_instance(_sphere_mesh(0.48), color)
	head.name = "%sHead" % String(source).capitalize()
	head.position = Vector3(0.0, 1.62, -0.35)
	_head_anchor.add_child(head)

	match source:
		&"rabbit":
			for x in [-0.22, 0.22]:
				var ear := _mesh_instance(_capsule_mesh(0.12, 0.92), color.lightened(0.08))
				ear.position = Vector3(x, 2.22, -0.30)
				_head_anchor.add_child(ear)
		&"elephant":
			var trunk := _mesh_instance(_capsule_mesh(0.12, 0.95), color.darkened(0.12))
			trunk.position = Vector3(0.0, 1.22, -0.74)
			trunk.rotation.x = deg_to_rad(18.0)
			_head_anchor.add_child(trunk)
			for x in [-0.48, 0.48]:
				var ear := _mesh_instance(_sphere_mesh(0.34), color.lightened(0.05))
				ear.position = Vector3(x, 1.67, -0.30)
				ear.scale = Vector3(0.45, 1.0, 0.22)
				_head_anchor.add_child(ear)
		&"cat":
			for x in [-0.24, 0.24]:
				var ear := _mesh_instance(_cone_mesh(0.18, 0.42), color.lightened(0.08))
				ear.position = Vector3(x, 2.02, -0.34)
				_head_anchor.add_child(ear)
		_:
			for x in [-0.30, 0.30]:
				var ear := _mesh_instance(_sphere_mesh(0.20), color.darkened(0.08))
				ear.position = Vector3(x, 1.90, -0.32)
				ear.scale = Vector3(0.75, 1.0, 0.55)
				_head_anchor.add_child(ear)

func _build_tail(source: StringName) -> void:
	var definition := WildDashAnimalCatalog.get_definition(source)
	var color := definition.accent_color
	match source:
		&"rabbit":
			var tail := _mesh_instance(_sphere_mesh(0.25), color.lightened(0.15))
			tail.position = Vector3(0.0, 0.98, 0.92)
			_tail_anchor.add_child(tail)
		&"elephant":
			var tail := _mesh_instance(_capsule_mesh(0.09, 0.92), color.darkened(0.15))
			tail.position = Vector3(0.0, 0.90, 1.06)
			tail.rotation.x = deg_to_rad(62.0)
			_tail_anchor.add_child(tail)
		&"cat":
			var tail := _mesh_instance(_capsule_mesh(0.10, 1.45), color.darkened(0.12))
			tail.position = Vector3(0.0, 1.16, 1.18)
			tail.rotation.x = deg_to_rad(70.0)
			_tail_anchor.add_child(tail)
		_:
			var tail := _mesh_instance(_capsule_mesh(0.14, 0.72), color.darkened(0.10))
			tail.position = Vector3(0.0, 1.03, 0.96)
			tail.rotation.x = deg_to_rad(58.0)
			_tail_anchor.add_child(tail)

func _build_pattern(pattern: StringName) -> void:
	if pattern == &"plain":
		return
	var accent := WildDashAnimalCatalog.get_definition(loadout.head_id).accent_color.lightened(0.12)
	if pattern == &"stripe":
		var stripe := _mesh_instance(_box_mesh(Vector3(0.16, 0.08, 1.08)), accent)
		stripe.position = Vector3(0.0, 1.38, 0.10)
		_pattern_anchor.add_child(stripe)
	elif pattern == &"spots":
		for x in [-0.28, 0.28]:
			var spot := _mesh_instance(_sphere_mesh(0.13), accent)
			spot.position = Vector3(x, 1.18, 0.48)
			spot.scale = Vector3(1.0, 0.28, 0.65)
			_pattern_anchor.add_child(spot)
	elif pattern == &"split":
		var plate := _mesh_instance(_box_mesh(Vector3(0.62, 0.04, 0.95)), accent)
		plate.position = Vector3(-0.30, 1.25, 0.12)
		_pattern_anchor.add_child(plate)

func _clear_anchor(anchor: Node3D) -> void:
	if anchor == null:
		return
	for child in anchor.get_children():
		anchor.remove_child(child)
		child.queue_free()

func _mesh_instance(mesh: Mesh, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.78
	instance.material_override = material
	return instance

func _sphere_mesh(radius: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return mesh

func _capsule_mesh(radius: float, height: float) -> CapsuleMesh:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0)
	mesh.radial_segments = 12
	mesh.rings = 4
	return mesh

func _cone_mesh(radius: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	return mesh

func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh
