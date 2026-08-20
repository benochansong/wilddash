extends "res://modes/logspire_leap/logspire_phase3_director_v5_route_clearance_core.gd"

## Final R3 event-geometry visibility guard.
## The stable Phase3 base keeps the original finale/recovery contract intact.
## This wrapper preserves the V5 route-clearance work while ensuring that a
## large moving tree body is never visible when its gameplay collision is off.

func configure(world: Node, graph: Node) -> void:
	super(world, graph)
	_sync_event_geometry_visibility()

func _physics_process(delta: float) -> void:
	super(delta)
	if not _configured:
		return
	_sync_event_geometry_visibility()

func _sync_event_geometry_visibility() -> void:
	for data: Dictionary in _living_branches:
		var body := data.get("body") as AnimatableBody3D
		if body == null or not is_instance_valid(body):
			continue
		# A collision-free giant branch must never render as a solid wall.
		body.visible = body.collision_layer != 0

	if _last_tree != null and is_instance_valid(_last_tree):
		# The finale tree follows the same invariant: visible means collidable.
		_last_tree.visible = _last_tree.collision_layer != 0
