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
	_sync_indexed_collection(_mode.get("fruits"), _mode.get("fruit_active"))
	_sync_indexed_collection(_mode.get("spill_fruits"), _mode.get("spill_active"))
	var golden := _mode.get("_golden_fruit")
	var golden_active: bool = bool(_mode.get("_golden_active"))
	_sync_tree(golden, golden_active)

func _sync_indexed_collection(nodes_value: Variant, active_value: Variant) -> void:
	if not nodes_value is Array or not active_value is Array:
		return
	var nodes: Array = nodes_value
	var active: Array = active_value
	var count := mini(nodes.size(), active.size())
	for i in range(count):
		_sync_tree(nodes[i], bool(active[i]))

func _sync_tree(value: Variant, target_visible: bool) -> void:
	if not value is Node:
		return
	var node := value as Node
	if node is GeometryInstance3D:
		var visual := node as GeometryInstance3D
		if visual.visible != target_visible:
			visual.visible = target_visible
	for child: Node in node.get_children():
		_sync_tree(child, target_visible)
