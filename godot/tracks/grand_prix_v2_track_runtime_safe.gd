extends "res://tracks/grand_prix_v2_track.gd"

## Runtime safety wrapper for the V2 procedural ribbon road.
##
## The V2 road begins exactly at route point 0 while the inherited 4-column
## starting grid places later rows behind that point. Without geometry behind
## the start line those racers can begin over empty space. V3.0 therefore adds
## a small start apron with a primitive BoxShape collision before racers spawn.
## The apron is aligned to the first route tangent, extends well behind the line
## for 18-racer grids, and overlaps the first metres of the ribbon. The normal
## ribbon collision remains authoritative once racers leave the grid.

const START_GRID_SAFE_LIFT: float = 0.12
const START_APRON_BACK_LENGTH: float = 22.0
const START_APRON_FORWARD_OVERLAP: float = 8.0
const START_APRON_EXTRA_WIDTH: float = 2.0
const START_APRON_THICKNESS: float = 0.60

var _start_apron_body: StaticBody3D

func _ready() -> void:
	super._ready()
	var updated: int = _enable_two_sided_road_collision(self)
	var apron_ready: bool = _build_start_apron()
	print("GRAND PRIX V3.0 START SAFETY READY two_sided_road_shapes=%d start_lift=%.2fm apron=%s back=%.1fm forward_overlap=%.1fm" % [
		updated,
		START_GRID_SAFE_LIFT,
		str(apron_ready),
		START_APRON_BACK_LENGTH,
		START_APRON_FORWARD_OVERLAP,
	])

func get_start_position() -> Vector3:
	var start: Vector3 = super.get_start_position()
	start.y += START_GRID_SAFE_LIFT
	return start

func _build_start_apron() -> bool:
	var route: Array[Vector3] = get_route_points()
	if route.size() < 2:
		push_warning("GrandPrixV3StartSafety: route unavailable for start apron")
		return false

	var start: Vector3 = route[0]
	var forward: Vector3 = route[1] - route[0]
	forward.y = 0.0
	if forward.length_squared() <= 0.0001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right: Vector3 = Vector3(-forward.z, 0.0, forward.x)

	var road_width: float = get_v2_width_for_segment(0)
	var shoulder_width: float = get_v2_shoulder_width_for_segment(0)
	var apron_width: float = road_width + shoulder_width * 2.0 + START_APRON_EXTRA_WIDTH * 2.0
	var apron_length: float = START_APRON_BACK_LENGTH + START_APRON_FORWARD_OVERLAP
	var signed_center_offset: float = (START_APRON_FORWARD_OVERLAP - START_APRON_BACK_LENGTH) * 0.5
	var top_y: float = start.y + ROAD_SURFACE_LIFT - 0.015
	var center: Vector3 = start + forward * signed_center_offset
	center.y = top_y - START_APRON_THICKNESS * 0.5

	_start_apron_body = StaticBody3D.new()
	_start_apron_body.name = "V30StartGridSafetyApron"
	_start_apron_body.collision_layer = 1
	_start_apron_body.collision_mask = 0
	add_child(_start_apron_body)

	# Box local Z follows the route axis (sign does not matter for a box). Use a
	# right-handed basis so visual and collision transforms remain identical.
	_start_apron_body.global_transform = Transform3D(Basis(right, Vector3.UP, -forward), center)

	var collision: CollisionShape3D = CollisionShape3D.new()
	collision.name = "StartGridSafetyCollision"
	var shape: BoxShape3D = BoxShape3D.new()
	shape.size = Vector3(apron_width, START_APRON_THICKNESS, apron_length)
	collision.shape = shape
	_start_apron_body.add_child(collision)

	var visual: MeshInstance3D = MeshInstance3D.new()
	visual.name = "StartGridSafetyVisual"
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(apron_width, START_APRON_THICKNESS, apron_length)
	visual.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.15, 0.18, 0.17)
	material.roughness = 0.94
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_start_apron_body.add_child(visual)

	print("GRAND PRIX V3.0 START APRON width=%.1fm length=%.1fm top_y=%.3f center=%s first_forward=%s" % [
		apron_width,
		apron_length,
		top_y,
		str(center),
		str(forward),
	])
	return true

func _enable_two_sided_road_collision(root: Node) -> int:
	if root == null:
		return 0
	var updated: int = 0
	for child: Node in root.get_children():
		if child is CollisionShape3D:
			var collision: CollisionShape3D = child as CollisionShape3D
			if collision.shape is ConcavePolygonShape3D:
				var concave: ConcavePolygonShape3D = collision.shape as ConcavePolygonShape3D
				concave.set_backface_collision_enabled(true)
				updated += 1
		updated += _enable_two_sided_road_collision(child)
	return updated
