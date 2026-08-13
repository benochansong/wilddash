class_name WildDashGrandPrixTunnelFailsafe
extends Node

const TUNNEL_START_ROUTE_INDEX := 25
const TUNNEL_END_ROUTE_INDEX := 26
const TUNNEL_WIDTH := 12.0
const END_EXTENSION_METERS := 24.0
const EDGE_PADDING := 0.42
const SPEED_RETENTION_ON_CORRECTION := 0.84

var _a := Vector3.ZERO
var _b := Vector3.ZERO
var _configured := false
var _corrections := 0

func _ready() -> void:
	# Existing racing feel runs at 100 and the primary environment collision
	# controller at 120. This final safety pass runs after both.
	process_priority = 180
	call_deferred("_configure_after_track_ready")

func _configure_after_track_ready() -> void:
	for _frame in range(5):
		await get_tree().physics_frame
	var track := _find_grand_prix_track()
	if track == null:
		push_warning("RC7 TUNNEL FAILSAFE: Grand Prix track not found")
		return
	var route: Array[Vector3] = track.get_route_points()
	if route.size() <= TUNNEL_END_ROUTE_INDEX:
		push_warning("RC7 TUNNEL FAILSAFE: route does not contain tunnel indices")
		return
	_a = route[TUNNEL_START_ROUTE_INDEX]
	_b = route[TUNNEL_END_ROUTE_INDEX]
	_configured = true
	print("RC7 TUNNEL FAILSAFE READY width=%.2f extension=%.1fm padding=%.2f" % [
		TUNNEL_WIDTH, END_EXTENSION_METERS, EDGE_PADDING,
	])

func _physics_process(_delta: float) -> void:
	if not _configured or not RaceManager.active:
		return
	for candidate in RaceManager.racers:
		if candidate is WildDashCharacterController:
			_enforce_corridor(candidate as WildDashCharacterController)

func _enforce_corridor(racer: WildDashCharacterController) -> void:
	if racer == null or racer.finished:
		return
	var ab := _b - _a
	var length_squared := ab.length_squared()
	if length_squared <= 0.001:
		return
	var length := sqrt(length_squared)
	var raw_t := (racer.global_position - _a).dot(ab) / length_squared
	var extension_t := END_EXTENSION_METERS / length
	if raw_t < -extension_t or raw_t > 1.0 + extension_t:
		return

	var centerline := _a.lerp(_b, clampf(raw_t, 0.0, 1.0))
	if absf(racer.global_position.y - centerline.y) > 6.5:
		return
	var planar := _b - _a
	planar.y = 0.0
	if planar.length_squared() <= 0.001:
		return
	planar = planar.normalized()
	var right := Vector3(-planar.z, 0.0, planar.x)
	var lateral := (racer.global_position - centerline).dot(right)
	var allowed := maxf(1.0, TUNNEL_WIDTH * 0.5 - _collision_radius(racer) - EDGE_PADDING)
	if absf(lateral) <= allowed:
		return

	var side := signf(lateral)
	var excess := lateral - side * allowed
	racer.global_position -= right * excess
	var outward := right * side
	var outward_velocity := racer.velocity.dot(outward)
	if outward_velocity > 0.0:
		racer.velocity -= outward * outward_velocity
	racer.current_speed *= SPEED_RETENTION_ON_CORRECTION
	_corrections += 1
	if _corrections <= 10 or OS.has_environment("WILDDASH_DEBUG_COLLISION"):
		print("RC7 TUNNEL SECONDARY BLOCK racer=%s lateral=%.2f allowed=%.2f correction=%.2f" % [
			racer.name, lateral, allowed, absf(excess),
		])

func _collision_radius(racer: WildDashCharacterController) -> float:
	var shape := racer.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if shape != null and shape.shape is CapsuleShape3D:
		return (shape.shape as CapsuleShape3D).radius
	return 0.62

func _find_grand_prix_track() -> WildDashGrandPrixTrack:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child is WildDashGrandPrixTrack:
			return child as WildDashGrandPrixTrack
	return null
