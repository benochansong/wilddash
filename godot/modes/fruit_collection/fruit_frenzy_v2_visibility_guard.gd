extends Node

## Round 2 composite-fruit visibility guard.
## The active flags are the Source of Truth. Do not trust only the parent visual's
## visible flag because V2 fruit silhouettes are composed from child meshes.
## Recursively mirror gameplay state onto the whole visual tree every frame.

var _mode: Node

func _ready() -> void:
	process_priority = 1000
	_mode = get_parent()
	print("FRUIT FRENZY V2 VISIBILITY GUARD READY state_driven=true recursive=true")

func _process(_delta: float) -> void:
	if _mode == null:
		return
	var fruits_value: Variant = _mode.get("fruits")
	var fruit_active_value: Variant = _mode.get("fruit_active")
	var spill_fruits_value: Variant = _mode.get("spill_fruits")
	var spill_active_value: Variant = _mode.get("spill_active")
	_sync_indexed_collection(fruits_value, fruit_active_value)
	_sync_indexed_collection(spill_fruits_value, spill_active_value)
	var golden: Variant = _mode.get("_golden_fruit")
	var golden_active_value: Variant = _mode.get("_golden_active")
	var golden_active: bool = bool(golden_active_value)
	_sync_tree(golden, golden_active)

func _sync_indexed_collection(nodes_value: Variant, active_value: Variant) -> void:
	if not nodes_value is Array or not active_value is Array:
		return
	var nodes: Array = nodes_value
	var active: Array = active_value
	var count: int = mini(nodes.size(), active.size())
	for i: int in range(count):
		var node_value: Variant = nodes[i]
		var active_flag: bool = bool(active[i])
		_sync_tree(node_value, active_flag)

func _sync_tree(value: Variant, target_visible: bool) -> void:
	if not value is Node:
		return
	var node: Node = value as Node
	if node is GeometryInstance3D:
		var visual: GeometryInstance3D = node as GeometryInstance3D
		if visual.visible != target_visible:
			visual.visible = target_visible
	for child: Node in node.get_children():
		_sync_tree(child, target_visible)
