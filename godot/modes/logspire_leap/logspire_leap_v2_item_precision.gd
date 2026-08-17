extends "res://modes/logspire_leap/logspire_leap.gd"

## Round 3 item pickup correction.
## Keep visible boxes forgiving enough to collect while racing. Prevent a racer
## from sweeping a whole row with a short global pickup lock instead of tiny
## detection volumes. Held items may be replaced so a valid box never feels dead.

const LOGSPIRE_PICKUP_RADIUS_SCALE: float = 0.82
const LOGSPIRE_PICKUP_VERTICAL_SCALE: float = 0.90
const LOGSPIRE_PICKUP_LOCK_MSEC: int = 900
const LOGSPIRE_PICKUP_COLLISION_RADIUS: float = 1.85

func _spawn_item_station(platform_id: StringName, offsets: Array, route_id: StringName, respawn: float) -> void:
	var point_value: Variant = _world.call("get_platform_position", platform_id)
	if not (point_value is Vector3):
		return
	var point: Vector3 = point_value
	var forward_value: Variant = _graph.call("get_platform_forward", platform_id, route_id)
	var forward: Vector3 = forward_value if forward_value is Vector3 else Vector3.FORWARD
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var right := Vector3(-forward.z, 0.0, forward.x)
	for offset_value: Variant in offsets:
		var offset: float = float(offset_value)
		var box := ITEM_BOX_SCENE.instantiate() as WildDashItemBox
		if box == null:
			continue
		box.name = "LogspireItem_%s_%s" % [String(platform_id), str(offset).replace("-", "N").replace(".", "_")]
		box.position = point + right * offset + Vector3.UP * 1.35
		box.respawn_seconds = respawn
		box.configure_pickup_profile(
			LOGSPIRE_PICKUP_RADIUS_SCALE,
			LOGSPIRE_PICKUP_VERTICAL_SCALE,
			LOGSPIRE_PICKUP_LOCK_MSEC,
			true,
			LOGSPIRE_PICKUP_COLLISION_RADIUS
		)
		add_child(box)
		_item_boxes.append(box)

func _ready() -> void:
	await super()
	print("LOGSPIRE ITEM PICKUP READY pickup_scale=%.2f collision_radius=%.2fm anti_sweep_lock=%.2fs replace_allowed=true easy_pickup=true" % [
		LOGSPIRE_PICKUP_RADIUS_SCALE,
		LOGSPIRE_PICKUP_COLLISION_RADIUS,
		float(LOGSPIRE_PICKUP_LOCK_MSEC) / 1000.0,
	])
