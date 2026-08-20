extends "res://modes/logspire_leap/logspire_ladder_system_v2.gd"

## Easier ladder capture for water recovery.
## Racers that visibly reach a ladder should attach immediately instead of
## circling around a narrow 2.15m trigger.

const EASY_ATTACH_RADIUS: float = 4.25
const LADDER_LABEL_VISIBILITY: float = 42.0
const LADDER_BEACON_VISIBILITY: float = 52.0

func configure(world: Node, graph: Node, water_heights: Dictionary) -> void:
	super(world, graph, water_heights)
	for i: int in range(_ladders.size()):
		var ladder: Dictionary = _ladders[i]
		ladder["attach_radius"] = EASY_ATTACH_RADIUS
		_ladders[i] = ladder
		var ladder_id: String = String(ladder.get("id", &""))
		var root := get_node_or_null(ladder_id) as Node3D
		if root == null:
			continue
		var label := root.get_node_or_null("ClimbLabel") as Label3D
		if label != null:
			label.visibility_range_end = LADDER_LABEL_VISIBILITY
		var beacon := root.get_node_or_null("OrangeBeacon") as MeshInstance3D
		if beacon != null:
			beacon.visibility_range_end = LADDER_BEACON_VISIBILITY
			if beacon.mesh is SphereMesh:
				var sphere := beacon.mesh as SphereMesh
				sphere.radial_segments = 12
				sphere.rings = 6
	print("LOGSPIRE LADDER EASY ATTACH READY ladders=%d radius=%.2fm label_cull=%.0fm" % [
		_ladders.size(), EASY_ATTACH_RADIUS, LADDER_LABEL_VISIBILITY,
	])
