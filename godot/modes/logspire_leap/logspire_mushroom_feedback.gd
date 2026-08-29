extends Node

var _world: Node
var _cap: MeshInstance3D
var _area: Area3D
var _configured: bool = false

func configure(world: Node) -> void:
	_world = world
	if _world == null:
		return
	_cap = _world.get_node_or_null("Phase2MushroomVisual") as MeshInstance3D
	_area = _world.get_node_or_null("Phase2MushroomArea") as Area3D
	if _cap == null or _area == null:
		push_warning("LOGSPIRE MUSHROOM FEEDBACK missing visual/area")
		return
	if not _area.body_entered.is_connected(_on_body_entered):
		_area.body_entered.connect(_on_body_entered)
	_configured = true
	print("LOGSPIRE MUSHROOM FEEDBACK READY compression=true rebound=true boing_hook=true")

func _on_body_entered(body: Node3D) -> void:
	if not _configured or _cap == null:
		return
	var racer := body as WildDashCharacterController
	if racer == null or racer.finished:
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_cap, "scale", Vector3(1.08, 0.24, 1.08), 0.07)
	tween.tween_property(_cap, "scale", Vector3(0.96, 0.58, 0.96), 0.11)
	tween.tween_property(_cap, "scale", Vector3(1.0, 0.45, 1.0), 0.10)
