extends "res://tracks/grand_prix_v2_track.gd"

## Runtime safety wrapper for the V2 procedural ribbon road.
##
## The V2 road uses ConcavePolygonShape3D collision generated from a thin
## ArrayMesh ribbon. Concave collision is one-sided by default, which can let a
## racer cross the sheet if the contact starts on the back side. Make every V2
## road trimesh two-sided and give the starting grid extra vertical clearance so
## racers settle onto the road instead of beginning on the collision boundary.

const START_GRID_SAFE_LIFT: float = 0.75

func _ready() -> void:
	super._ready()
	var updated: int = _enable_two_sided_road_collision(self)
	print("GRAND PRIX V2 START SAFETY READY two_sided_road_shapes=%d start_lift=%.2fm" % [
		updated,
		START_GRID_SAFE_LIFT,
	])

func get_start_position() -> Vector3:
	var start: Vector3 = super.get_start_position()
	start.y += START_GRID_SAFE_LIFT
	return start

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
