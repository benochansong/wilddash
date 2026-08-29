class_name WildDashMangroveTitanController
extends Node3D

## Environmental boss for WILD TIDE. The Titan never has HP: it changes the
## racing space through telegraphed hazards that affect players and AI equally.

const TAIL_BASE_PROGRESS: float = 0.35
const WAVE_BASE_PROGRESS: float = 0.43
const VINE_BASE_PROGRESS: float = 0.51
const TELEGRAPH_SECONDS: float = 1.15
const VINE_TELEGRAPH_SECONDS: float = 1.00
const JUMP_CLEARANCE: float = 1.65
const TAIL_RADIUS: float = 11.0
const WAVE_RADIUS: float = 12.5
const VINE_RADIUS: float = 4.6

var _track: Node3D
var _route_points: Array[Vector3] = []
var _titan_root: Node3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _tail_trigger: float = TAIL_BASE_PROGRESS
var _wave_trigger: float = WAVE_BASE_PROGRESS
var _vine_trigger: float = VINE_BASE_PROGRESS
var _awakened: bool = false
var _tail_done: bool = false
var _wave_done: bool = false
var _vine_done: bool = false
var _shortcut_open: bool = false
var _hazard_type: StringName = &""
var _hazard_center: Vector3 = Vector3.ZERO
var _hazard_serial: int = 0
var _bootstrapped: bool = false

func _ready() -> void:
	_rng.seed = 330731
	call_deferred("_bootstrap")

func _bootstrap() -> void:
	for _attempt: int in range(40):
		var parent_node: Node = get_parent()
		if parent_node != null:
			_track = parent_node.get_node_or_null("NeonHarborWorldTrack") as Node3D
		if _track != null and _track.has_method("get_route_points"):
			break
		await get_tree().physics_frame
	if _track == null or not _track.has_method("get_route_points"):
		return
	var route_value: Variant = _track.call("get_route_points")
	if route_value is Array:
		for value: Variant in route_value:
			if value is Vector3:
				_route_points.append(value)
	if _route_points.size() < 17:
		return

	_tail_trigger += _rng.randf_range(-0.012, 0.012)
	_wave_trigger += _rng.randf_range(-0.012, 0.012)
	_vine_trigger += _rng.randf_range(-0.012, 0.012)
	_build_titan_visual()
	_bootstrapped = true
	print("MANGROVE TITAN READY tail=%.3f wave=%.3f vine=%.3f telegraph=true race_hazard=true" % [
		_tail_trigger, _wave_trigger, _vine_trigger,
	])

func _process(_delta: float) -> void:
	if not _bootstrapped or not RaceManager.active:
		return
	var player: WildDashCharacterController = _get_player()
	if player == null or player.finished:
		return
	var progress: float = RaceManager.get_progress_percent(player) / 100.0
	if not _awakened and progress >= _tail_trigger - 0.035:
		_awakened = true
		_awaken_sequence()
	if not _tail_done and progress >= _tail_trigger:
		_tail_done = true
		_tail_sweep_sequence()
	if not _wave_done and progress >= _wave_trigger:
		_wave_done = true
		_wave_sequence()
	if not _vine_done and progress >= _vine_trigger:
		_vine_done = true
		_vine_smash_sequence()

func get_active_hazard() -> StringName:
	return _hazard_type

func get_active_hazard_center() -> Vector3:
	return _hazard_center

func get_hazard_serial() -> int:
	return _hazard_serial

func is_shortcut_open() -> bool:
	return _shortcut_open

func _awaken_sequence() -> void:
	_show_hud("MANGROVE TITAN AWAKENS!")
	AudioManager.play_sfx_id("monster_roar", 1.0)
	_try_camera_shake(0.22)
	if _titan_root != null:
		var original_scale: Vector3 = _titan_root.scale
		_titan_root.scale = original_scale * 0.78
		var tween: Tween = _titan_root.create_tween()
		tween.tween_property(_titan_root, "scale", original_scale * 1.10, 0.38).set_trans(Tween.TRANS_BACK)
		tween.tween_property(_titan_root, "scale", original_scale, 0.52)
	print("ROUND3 EVENT type=TITAN_AWAKEN progress=%.1f" % RaceManager.get_progress_percent(_get_player()))

func _tail_sweep_sequence() -> void:
	var segment_index: int = 10
	var center: Vector3 = _segment_center(segment_index)
	_begin_hazard(&"tail_sweep", center)
	_show_hud("TAIL SWEEP!  JUMP OR MOVE ASIDE")
	AudioManager.play_sfx_id("monster_roar", 0.72)
	var warning: Node3D = _create_warning_bar(center, segment_index, Color(1.0, 0.12, 0.08, 0.50), 20.0, 5.0)
	await get_tree().create_timer(TELEGRAPH_SECONDS).timeout
	if warning != null and is_instance_valid(warning):
		warning.queue_free()
	var hits: int = _apply_radius_hazard(center, TAIL_RADIUS, 0.82, 0.78, 4.2, JUMP_CLEARANCE, &"titan_tail")
	_spawn_impact_ring(center, Color(1.0, 0.32, 0.08), 10.0)
	AudioManager.play_sfx_id("tree_break", 0.82)
	_try_camera_shake(0.16)
	_end_hazard()
	print("TITAN ATTACK type=TAIL_SWEEP segment=%d targets=%d telegraph=%.2f" % [segment_index, hits, TELEGRAPH_SECONDS])

func _wave_sequence() -> void:
	var segment_index: int = 12
	var center: Vector3 = _segment_center(segment_index)
	_begin_hazard(&"water_wave", center)
	_show_hud("WAVE INCOMING!  JUMP / HIGH ROUTE")
	AudioManager.play_sfx_id("wave", 0.95)
	var warning: Node3D = _create_warning_bar(center, segment_index, Color(0.05, 0.72, 1.0, 0.52), 22.0, 6.0)
	await get_tree().create_timer(TELEGRAPH_SECONDS).timeout
	if warning != null and is_instance_valid(warning):
		warning.queue_free()
	var hits: int = 0
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		if racer.global_position.distance_to(center) > WAVE_RADIUS:
			continue
		if racer.global_position.y > center.y + JUMP_CLEARANCE:
			continue
		var knockback_scale: float = WildDashTerrainAbilitySystem.get_wave_knockback_multiplier(racer.animal_id)
		if ItemSystem.apply_attack(racer, self, &"titan_wave", 0.72, 0.82, 4.6 * knockback_scale):
			hits += 1
			if racer.animal_id == &"crocodile":
				racer.current_speed = minf(racer.max_speed * 1.10, racer.current_speed + 1.8)
	_spawn_impact_ring(center, Color(0.05, 0.70, 1.0), 12.0)
	AudioManager.play_sfx_id("splash", 1.0)
	_try_camera_shake(0.18)
	_end_hazard()
	print("TITAN ATTACK type=WATER_SLAM segment=%d targets=%d crocodile_resist=true" % [segment_index, hits])

func _vine_smash_sequence() -> void:
	var segment_index: int = 14
	var center: Vector3 = _segment_center(segment_index)
	_begin_hazard(&"vine_smash", center)
	_show_hud("VINE SMASH!  WATCH THE WARNING MARKERS")
	AudioManager.play_sfx_id("monster_roar", 0.62)
	var tangent: Vector3 = _segment_direction(segment_index)
	var right: Vector3 = Vector3(-tangent.z, 0.0, tangent.x)
	var markers: Array[Node3D] = []
	var impact_centers: Array[Vector3] = [center - right * 5.0, center, center + right * 5.0]
	for impact_center: Vector3 in impact_centers:
		markers.append(_create_warning_disc(impact_center, VINE_RADIUS, Color(1.0, 0.12, 0.48, 0.52)))
	await get_tree().create_timer(VINE_TELEGRAPH_SECONDS).timeout
	for marker: Node3D in markers:
		if marker != null and is_instance_valid(marker):
			marker.queue_free()
	var hits: int = 0
	for impact_center: Vector3 in impact_centers:
		hits += _apply_radius_hazard(impact_center, VINE_RADIUS, 0.65, 0.80, 3.6, 2.1, &"titan_vine")
		_spawn_impact_ring(impact_center, Color(1.0, 0.10, 0.46), 4.8)
	AudioManager.play_sfx_id("tree_break", 1.0)
	_try_camera_shake(0.14)
	_open_jungle_shortcut()
	_end_hazard()
	print("TITAN ATTACK type=VINE_SMASH segment=%d targets=%d shortcut_open=true" % [segment_index, hits])

func _begin_hazard(kind: StringName, center: Vector3) -> void:
	_hazard_type = kind
	_hazard_center = center
	_hazard_serial += 1

func _end_hazard() -> void:
	_hazard_type = &""
	_hazard_center = Vector3.ZERO

func _apply_radius_hazard(
	center: Vector3,
	radius: float,
	duration: float,
	slow_multiplier: float,
	knockback: float,
	jump_clearance: float,
	effect_id: StringName
) -> int:
	var hits: int = 0
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		if racer.global_position.distance_to(center) > radius:
			continue
		if racer.global_position.y > center.y + jump_clearance:
			continue
		if ItemSystem.apply_attack(racer, self, effect_id, duration, slow_multiplier, knockback):
			hits += 1
	return hits

func _open_jungle_shortcut() -> void:
	if _shortcut_open or _route_points.size() < 17:
		return
	_shortcut_open = true
	var root: Node3D = Node3D.new()
	root.name = "TitanFallenMangroveShortcut"
	root.add_to_group("wild_tide_jungle_shortcut")
	add_child(root)
	var a: Vector3 = _route_points[14]
	var b: Vector3 = _route_points[16]
	var direction: Vector3 = b - a
	direction.y = 0.0
	if direction.length_squared() <= 0.001:
		return
	var right: Vector3 = Vector3(-direction.normalized().z, 0.0, direction.normalized().x)
	var start: Vector3 = a + right * 5.4 + Vector3.UP * 0.95
	var finish: Vector3 = b + right * 5.4 + Vector3.UP * 0.95
	var bridge: CSGBox3D = CSGBox3D.new()
	bridge.name = "FallenMangroveBridge"
	bridge.size = Vector3(4.6, 0.72, maxf(2.0, start.distance_to(finish)))
	bridge.use_collision = true
	bridge.position = start.lerp(finish, 0.5)
	bridge.look_at(finish, Vector3.UP)
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.26, 0.13, 0.045)
	material.roughness = 0.92
	material.emission_enabled = true
	material.emission = Color(0.58, 0.36, 0.05) * 0.22
	bridge.material = material
	root.add_child(bridge)
	_show_hud("JUNGLE SHORTCUT OPEN!")
	AudioManager.play_sfx_id("tree_break", 1.0)
	print("ROUTE STATE jungle_shortcut=open start=14 finish=16 titan_created=true")

func _build_titan_visual() -> void:
	_titan_root = Node3D.new()
	_titan_root.name = "MangroveTitan"
	add_child(_titan_root)
	var center: Vector3 = _segment_center(12)
	var tangent: Vector3 = _segment_direction(12)
	var right: Vector3 = Vector3(-tangent.z, 0.0, tangent.x)
	center += right * 22.0 + Vector3.UP * 3.0
	_titan_root.position = center

	var body_material: StandardMaterial3D = StandardMaterial3D.new()
	body_material.albedo_color = Color(0.10, 0.24, 0.10)
	body_material.roughness = 0.82
	body_material.emission_enabled = true
	body_material.emission = Color(0.02, 0.38, 0.08) * 0.28
	for i: int in range(8):
		var section: CSGSphere3D = CSGSphere3D.new()
		section.name = "TitanBody_%02d" % i
		section.radius = 2.3 - float(i) * 0.10
		section.radial_segments = 12
		section.rings = 7
		section.use_collision = false
		section.position = Vector3(-float(i) * 2.4, sin(float(i) * 0.72) * 1.1, -float(i) * 1.7)
		section.scale = Vector3(1.25, 0.82, 1.45)
		section.material = body_material
		_titan_root.add_child(section)
	var head: CSGSphere3D = CSGSphere3D.new()
	head.name = "TitanHead"
	head.radius = 3.1
	head.radial_segments = 14
	head.rings = 8
	head.use_collision = false
	head.scale = Vector3(1.15, 0.92, 1.45)
	head.position = Vector3(2.5, 2.1, 1.1)
	head.material = body_material
	_titan_root.add_child(head)
	var eye_material: StandardMaterial3D = StandardMaterial3D.new()
	eye_material.albedo_color = Color(1.0, 0.16, 0.05)
	eye_material.emission_enabled = true
	eye_material.emission = Color(1.0, 0.04, 0.01) * 2.8
	for side: float in [-1.0, 1.0]:
		var eye: CSGSphere3D = CSGSphere3D.new()
		eye.radius = 0.32
		eye.radial_segments = 8
		eye.rings = 5
		eye.use_collision = false
		eye.position = Vector3(2.95 + side * 0.58, 2.65, 3.35)
		eye.material = eye_material
		_titan_root.add_child(eye)

func _create_warning_bar(
	center: Vector3,
	segment_index: int,
	color: Color,
	width: float,
	depth: float
) -> Node3D:
	var marker: CSGBox3D = CSGBox3D.new()
	marker.name = "TitanWarningBar"
	marker.size = Vector3(width, 0.06, depth)
	marker.use_collision = false
	marker.position = center + Vector3.UP * 0.20
	var direction: Vector3 = _segment_direction(segment_index)
	marker.look_at(marker.position + direction, Vector3.UP)
	marker.material = _warning_material(color)
	add_child(marker)
	var tween: Tween = marker.create_tween().set_loops()
	tween.tween_property(marker, "scale:y", 2.2, 0.18)
	tween.tween_property(marker, "scale:y", 0.65, 0.18)
	return marker

func _create_warning_disc(center: Vector3, radius: float, color: Color) -> Node3D:
	var marker: CSGCylinder3D = CSGCylinder3D.new()
	marker.name = "TitanWarningDisc"
	marker.radius = radius
	marker.height = 0.05
	marker.sides = 20
	marker.use_collision = false
	marker.position = center + Vector3.UP * 0.21
	marker.material = _warning_material(color)
	add_child(marker)
	var tween: Tween = marker.create_tween().set_loops()
	tween.tween_property(marker, "scale", Vector3(1.08, 1.0, 1.08), 0.22)
	tween.tween_property(marker, "scale", Vector3(0.92, 1.0, 0.92), 0.22)
	return marker

func _spawn_impact_ring(center: Vector3, color: Color, radius: float) -> void:
	var ring: CSGCylinder3D = CSGCylinder3D.new()
	ring.name = "TitanImpactRing"
	ring.radius = 1.0
	ring.height = 0.05
	ring.sides = 20
	ring.use_collision = false
	ring.position = center + Vector3.UP * 0.24
	ring.material = _warning_material(color)
	add_child(ring)
	var tween: Tween = ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.38)
	tween.tween_property(ring, "position:y", ring.position.y + 0.25, 0.38)
	tween.chain().tween_callback(ring.queue_free)

func _warning_material(color: Color) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b) * 1.8
	return material

func _segment_center(segment_index: int) -> Vector3:
	if segment_index < 0 or segment_index >= _route_points.size() - 1:
		return Vector3.ZERO
	return _route_points[segment_index].lerp(_route_points[segment_index + 1], 0.5)

func _segment_direction(segment_index: int) -> Vector3:
	if segment_index < 0 or segment_index >= _route_points.size() - 1:
		return Vector3.FORWARD
	var direction: Vector3 = _route_points[segment_index + 1] - _route_points[segment_index]
	direction.y = 0.0
	return Vector3.FORWARD if direction.length_squared() <= 0.001 else direction.normalized()

func _get_player() -> WildDashCharacterController:
	for racer_value: Variant in RaceManager.racers:
		var racer: WildDashCharacterController = racer_value as WildDashCharacterController
		if racer != null and racer.is_player:
			return racer
	return null

func _show_hud(text: String) -> void:
	var parent_node: Node = get_parent()
	if parent_node == null:
		return
	var hud_value: Variant = parent_node.get("hud")
	var mode_hud: WildDashModeHUD = hud_value as WildDashModeHUD
	if mode_hud != null:
		mode_hud.set_message(text)

func _try_camera_shake(amount: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	if camera.has_method("add_trauma"):
		camera.call("add_trauma", amount)
	elif camera.has_method("shake"):
		camera.call("shake", amount)
