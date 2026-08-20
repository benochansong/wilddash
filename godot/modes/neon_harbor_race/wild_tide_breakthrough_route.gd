class_name WildDashWildTideBreakthroughRoute
extends Node3D

## Optional rough-side shortcut. It never blocks the authoritative race road.
## Elephant can smash through reliably; Boar can also break it at higher speed.

var _route_points: Array[Vector3] = []
var _barrier: CSGBox3D
var _bootstrapped: bool = false

func _ready() -> void:
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	var track: Node = null
	for _attempt: int in range(40):
		var parent_node: Node = get_parent()
		if parent_node != null:
			track = parent_node.get_node_or_null("NeonHarborWorldTrack")
		if track != null and track.has_method("get_route_points"):
			break
		await get_tree().physics_frame
	if track == null:
		return
	var route_value: Variant = track.call("get_route_points")
	if route_value is Array:
		for value: Variant in route_value:
			if value is Vector3:
				_route_points.append(value)
	if _route_points.size() < 16:
		return
	_build_route()
	_bootstrapped = true
	print("WILD TIDE BREAKTHROUGH READY elephant=true boar=true main_route_unblocked=true")

func _physics_process(_delta: float) -> void:
	if not _bootstrapped or _barrier == null or not is_instance_valid(_barrier):
		return
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		var required_speed: float = INF
		if racer.animal_id == &"elephant":
			required_speed = 6.5
		elif racer.animal_id == &"boar":
			required_speed = 9.0
		if racer.current_speed < required_speed:
			continue
		if racer.global_position.distance_to(_barrier.global_position) <= 3.4:
			_show_hud("%s BREAKTHROUGH!" % String(racer.animal_id).to_upper())
			AudioManager.play_sfx_id("tree_break", 1.0)
			_spawn_break_fx(_barrier.global_position)
			_barrier.queue_free()
			print("ROUTE STATE breakthrough=open animal=%s speed=%.1f" % [String(racer.animal_id), racer.current_speed])
			return

func _build_route() -> void:
	var a: Vector3 = _route_points[13]
	var b: Vector3 = _route_points[15]
	var direction: Vector3 = b - a
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	direction = direction.normalized()
	var right: Vector3 = Vector3(-direction.z, 0.0, direction.x)
	var start: Vector3 = a - right * 6.3 + Vector3.UP * 0.15
	var finish: Vector3 = b - right * 6.3 + Vector3.UP * 0.15
	var platform: CSGBox3D = CSGBox3D.new()
	platform.name = "RoughBreakthroughLane"
	platform.size = Vector3(5.2, 0.42, maxf(2.0, start.distance_to(finish)))
	platform.use_collision = true
	platform.position = start.lerp(finish, 0.5)
	platform.look_at(finish, Vector3.UP)
	var ground_material: StandardMaterial3D = StandardMaterial3D.new()
	ground_material.albedo_color = Color(0.20, 0.12, 0.055)
	ground_material.roughness = 0.96
	ground_material.emission_enabled = true
	ground_material.emission = Color(0.65, 0.32, 0.05) * 0.12
	platform.material = ground_material
	add_child(platform)

	_barrier = CSGBox3D.new()
	_barrier.name = "BreakthroughMangroveGate"
	_barrier.size = Vector3(5.0, 3.4, 1.2)
	_barrier.use_collision = true
	_barrier.position = start.lerp(finish, 0.52) + Vector3.UP * 1.7
	_barrier.look_at(finish, Vector3.UP)
	var barrier_material: StandardMaterial3D = StandardMaterial3D.new()
	barrier_material.albedo_color = Color(0.28, 0.14, 0.045)
	barrier_material.roughness = 0.92
	barrier_material.emission_enabled = true
	barrier_material.emission = Color(1.0, 0.38, 0.02) * 0.22
	_barrier.material = barrier_material
	_barrier.add_to_group("wild_tide_breakable")
	add_child(_barrier)

func _spawn_break_fx(center: Vector3) -> void:
	for i: int in range(5):
		var chunk: CSGBox3D = CSGBox3D.new()
		chunk.size = Vector3(0.34, 0.34, 0.70)
		chunk.use_collision = false
		chunk.position = center + Vector3(float(i - 2) * 0.55, 0.5 + float(i % 2) * 0.4, 0.0)
		var material: StandardMaterial3D = StandardMaterial3D.new()
		material.albedo_color = Color(0.32, 0.17, 0.06)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.42, 0.04) * 0.18
		chunk.material = material
		add_child(chunk)
		var tween: Tween = chunk.create_tween()
		tween.set_parallel(true)
		tween.tween_property(chunk, "position:y", chunk.position.y + 1.6, 0.28)
		tween.tween_property(chunk, "scale", Vector3.ONE * 0.15, 0.36)
		tween.chain().tween_callback(Callable(chunk, "queue_free"))

func _show_hud(text: String) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var hud_value: Variant = parent_node.get("hud")
	var mode_hud: WildDashModeHUD = hud_value as WildDashModeHUD
	if mode_hud != null:
		mode_hud.set_message(text)
