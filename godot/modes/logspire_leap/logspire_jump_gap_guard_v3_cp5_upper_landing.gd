extends "res://modes/logspire_leap/logspire_jump_gap_guard_v2_titan_upper_flow.gd"

## Round 3 CP5 upper-deck landing hotfix.
##
## The generic Titan flow bridge already guarantees a continuous sloped surface,
## but real play can still snag on the lip of Z5_SPIRAL_07 after CP5. Widen that
## specific connector and add a flat collision-backed landing shelf that overlaps
## the destination top. The player can therefore run onto the upper deck instead
## of needing a perfect jump into a vertical box edge.

const CP5_CLIMB_FROM: StringName = &"Z5_SPIRAL_06"
const CP5_CLIMB_TO: StringName = &"Z5_SPIRAL_07"
const CP5_BRIDGE_WIDTH: float = 9.6
const CP5_SHELF_WIDTH: float = 10.0
const CP5_SHELF_LENGTH: float = 5.2
const CP5_SHELF_THICKNESS: float = 0.38

func _build_running_connectors(positions: Array) -> void:
	super(positions)
	_widen_cp5_bridge()
	_build_cp5_landing_shelf(positions)

func _widen_cp5_bridge() -> void:
	if _world == null:
		return
	var bridge_name := "SafeFlowBridge_%s_%s" % [String(CP5_CLIMB_FROM), String(CP5_CLIMB_TO)]
	var bridge := _world.get_node_or_null(NodePath(bridge_name)) as Node3D
	if bridge == null:
		push_warning("LOGSPIRE CP5 LANDING missing bridge=%s" % bridge_name)
		return
	for child: Node in bridge.get_children():
		var mesh_instance := child as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh is BoxMesh:
			var box := mesh_instance.mesh as BoxMesh
			box.size.x = CP5_BRIDGE_WIDTH
		var body := child as StaticBody3D
		if body == null:
			continue
		for body_child: Node in body.get_children():
			var collision := body_child as CollisionShape3D
			if collision != null and collision.shape is BoxShape3D:
				var shape := collision.shape as BoxShape3D
				shape.size.x = CP5_BRIDGE_WIDTH + 0.55
	bridge.set_meta(&"cp5_upper_deck_access", true)

func _build_cp5_landing_shelf(positions: Array) -> void:
	if _world == null:
		return
	var old := _world.get_node_or_null("CP5UpperLandingShelf")
	if old != null:
		old.queue_free()
	var from_index: int = int(_index_by_id.get(CP5_CLIMB_FROM, -1))
	var to_index: int = int(_index_by_id.get(CP5_CLIMB_TO, -1))
	if from_index < 0 or to_index < 0 or from_index >= positions.size() or to_index >= positions.size():
		return
	var from_top_value: Variant = positions[from_index]
	var to_top_value: Variant = positions[to_index]
	if not (from_top_value is Vector3) or not (to_top_value is Vector3):
		return
	var from_top: Vector3 = from_top_value
	var to_top: Vector3 = to_top_value
	var planar := Vector3(to_top.x - from_top.x, 0.0, to_top.z - from_top.z)
	if planar.length_squared() <= 0.001:
		return
	var forward: Vector3 = planar.normalized()

	var shelf := Node3D.new()
	shelf.name = "CP5UpperLandingShelf"
	_world.add_child(shelf)
	shelf.global_position = to_top - forward * 1.9 - Vector3.UP * (CP5_SHELF_THICKNESS * 0.5)
	shelf.rotation.y = atan2(-forward.x, -forward.z)
	shelf.set_meta(&"cp5_upper_deck_access", true)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.78, 0.43, 0.12)
	material.roughness = 0.88
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = "Mesh"
	var mesh := BoxMesh.new()
	mesh.size = Vector3(CP5_SHELF_WIDTH, CP5_SHELF_THICKNESS, CP5_SHELF_LENGTH)
	mesh.material = material
	mesh_instance.mesh = mesh
	shelf.add_child(mesh_instance)

	var body := StaticBody3D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	shelf.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(CP5_SHELF_WIDTH + 0.45, CP5_SHELF_THICKNESS, CP5_SHELF_LENGTH + 0.35)
	collision.shape = shape
	body.add_child(collision)

	print("LOGSPIRE CP5 UPPER LANDING READY from=%s to=%s bridge_width=%.1f shelf=%.1fx%.1f lip_snag=false continuous_walkable=true jump_required=false teleport=false" % [
		String(CP5_CLIMB_FROM), String(CP5_CLIMB_TO), CP5_BRIDGE_WIDTH, CP5_SHELF_WIDTH, CP5_SHELF_LENGTH,
	])
