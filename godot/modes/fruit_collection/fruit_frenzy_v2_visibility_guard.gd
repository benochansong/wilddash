extends Node

## Round 2 composite-fruit visibility guard.
## V2 fruit silhouettes are child MeshInstance3D parts. The legacy pickup pool
## toggles the parent MeshInstance3D visibility, which does not reliably hide
## those visual children. Mirror the pool's active/visible state onto every
## fruit part so collected fruit cannot remain as a ghost visual.

var _mode: Node

func _ready() -> void:
	process_priority = 110
	_mode = get_parent()
	print("FRUIT FRENZY V2 VISIBILITY GUARD READY composite_children_synced=true")

func _process(_delta: float) -> void:
	if _mode == null:
		return
	_sync_collection(_mode.get("fruits"))
	_sync_collection(_mode.get("spill_fruits"))
	_sync_single(_mode.get("_golden_fruit"))

func _sync_collection(value: Variant) -> void:
	if not value is Array:
		return
	for entry: Variant in value:
		_sync_single(entry)

func _sync_single(value: Variant) -> void:
	if not value is MeshInstance3D:
		return
	var fruit := value as MeshInstance3D
	var target_visible: bool = fruit.visible
	for child: Node in fruit.get_children():
		if child is GeometryInstance3D:
			var visual := child as GeometryInstance3D
			if visual.visible != target_visible:
				visual.visible = target_visible
