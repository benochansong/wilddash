class_name WildDashCombatV2FX
extends RefCounted

## Lightweight procedural feedback shared by Round 2 and Round 4. No particle
## systems or textures are allocated; short-lived primitive meshes keep the party
## combat readable on the GL compatibility renderer.

static func spawn_impact(parent: Node, position: Vector3, kind: StringName, scale_factor: float = 1.0) -> void:
	if parent == null:
		return
	var root: Node3D = Node3D.new()
	root.name = "CombatV2FX_%s_%d" % [String(kind), Time.get_ticks_msec()]
	parent.add_child(root)
	root.global_position = position

	var mesh_node: MeshInstance3D = MeshInstance3D.new()
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 0.34 * scale_factor
	mesh.height = 0.68 * scale_factor
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh_node.mesh = mesh
	mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = _kind_color(kind)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_node.material_override = material
	root.add_child(mesh_node)
	_expire(parent, root, 0.24)

static func spawn_trail(parent: Node, position: Vector3, direction: Vector3, kind: StringName, scale_factor: float = 1.0) -> void:
	if parent == null:
		return
	var root: Node3D = Node3D.new()
	root.name = "CombatV2Trail_%s_%d" % [String(kind), Time.get_ticks_msec()]
	parent.add_child(root)
	root.global_position = position
	var line: MeshInstance3D = MeshInstance3D.new()
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.16 * scale_factor, 0.16 * scale_factor, 1.8 * scale_factor)
	line.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = _kind_color(kind)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line.material_override = material
	root.add_child(line)
	var facing: Vector3 = direction
	facing.y = 0.0
	if facing.length_squared() > 0.001:
		root.look_at(root.global_position + facing.normalized(), Vector3.UP)
	_expire(parent, root, 0.20)

static func _kind_color(kind: StringName) -> Color:
	match kind:
		&"push": return Color(0.95, 0.82, 0.42, 0.58)
		&"charge": return Color(0.88, 0.53, 0.22, 0.62)
		&"stomp": return Color(0.90, 0.94, 1.0, 0.58)
		&"ambush": return Color(0.65, 0.90, 1.0, 0.62)
		&"water": return Color(0.20, 0.72, 1.0, 0.62)
		&"control": return Color(0.62, 0.82, 0.30, 0.58)
		_: return Color(1.0, 0.72, 0.28, 0.58)

static func _expire(parent: Node, node: Node, seconds: float) -> void:
	if parent == null or node == null:
		return
	var tree: SceneTree = parent.get_tree()
	if tree == null:
		return
	await tree.create_timer(seconds).timeout
	if is_instance_valid(node):
		node.queue_free()
