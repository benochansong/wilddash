extends "res://modes/logspire_leap/logspire_ladder_system_v5_traversal_paths.gd"

## Round 3 vine-only recovery cleanup.
## Keep the LadderSystem node and API as a compatibility shim for the inherited
## water-recovery stack, but retire every generated recovery ladder, root stair,
## recovery deck and recovery slope from the production scene.
## Source scripts remain preserved for rollback and later experimentation.

var _retired_recovery_prop_count: int = 0

func configure(world: Node, graph: Node, water_heights: Dictionary) -> void:
	super(world, graph, water_heights)
	_retired_recovery_prop_count = _retire_generated_recovery_props()
	_ladders.clear()
	_root_ramps.clear()
	print("LOGSPIRE VINE ONLY PROP CLEANUP READY ladders=0 root_stairs=0 recovery_decks=0 retired_props=%d source_preserved=true compatibility_node=true" % _retired_recovery_prop_count)

func get_all_ladders() -> Array:
	return []

func get_ladders_for_zone(_zone: int) -> Array:
	return []

func get_root_ramps_for_zone(_zone: int) -> Array:
	return []

func _retire_generated_recovery_props() -> int:
	var retired: int = 0
	for child: Node in get_children():
		_disable_recovery_prop_recursive(child)
		retired += 1
		child.queue_free()
	return retired

func _disable_recovery_prop_recursive(node: Node) -> void:
	if node is Node3D:
		(node as Node3D).visible = false
	if node is StaticBody3D:
		var body := node as StaticBody3D
		body.collision_layer = 0
		body.collision_mask = 0
	if node is CollisionShape3D:
		(node as CollisionShape3D).disabled = true
	for child: Node in node.get_children():
		_disable_recovery_prop_recursive(child)
