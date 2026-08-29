class_name WildCurrentSwimPresentation
extends Node

## Round 5-only direct swimming presentation.
## Gameplay movement remains owned by WildCurrentSwimmer/Phase2. This layer only
## changes visuals so racers read as animals swimming through water, never as
## riders standing on wake/splash boards.

const SURFACE_IMMERSION: float = 0.58
const LARGE_ANIMAL_IMMERSION: float = 0.46
const DIVE_EXTRA_IMMERSION: float = 0.18
const BASE_SWIM_PITCH: float = -0.19
const BURST_SWIM_PITCH: float = -0.27
const DIVE_SWIM_PITCH: float = -0.34
const MAX_STROKE_ROLL: float = 0.075
const MAX_TURN_ROLL: float = 0.08

var _presentations: Dictionary = {}
var _elapsed: float = 0.0

func _ready() -> void:
	print("r5_direct_swim_presentation_ready rideable_mesh=false particle_wake=true body_in_water=true")

func _process(delta: float) -> void:
	_elapsed += delta
	_sync_racers()
	_update_presentations()

func _exit_tree() -> void:
	for key in _presentations.keys():
		var entry: Dictionary = _presentations.get(key, {})
		var slot := entry.get("slot") as Node3D
		if slot == null or not is_instance_valid(slot):
			continue
		slot.position = entry.get("base_position", slot.position)
		slot.rotation = entry.get("base_rotation", slot.rotation)

func _sync_racers() -> void:
	for racer_node in get_tree().get_nodes_in_group("wilddash_racer"):
		var racer := racer_node as WildDashCharacterController
		if racer == null or not is_instance_valid(racer):
			continue
		var id := racer.get_instance_id()
		if not _presentations.has(id):
			_register_racer(racer)
		_strip_board_like_feedback(racer)

func _register_racer(racer: WildDashCharacterController) -> void:
	var slot := racer.get_node_or_null("VisualSlot") as Node3D
	if slot == null:
		return
	var wake := _make_particles("SwimWakeParticles", Vector3(0.0, -0.24, 1.0), Vector3(0.0, 0.10, 1.0), 18, 0.62, Color(0.76, 0.95, 1.0, 0.52), 0.20)
	var splash := _make_particles("StrokeSplashParticles", Vector3(0.0, -0.28, -0.18), Vector3(0.0, 1.0, 0.25), 12, 0.34, Color(0.90, 0.98, 1.0, 0.70), 0.16)
	var bubbles := _make_particles("DiveBubbleParticles", Vector3(0.0, -0.12, 0.45), Vector3(0.0, 1.0, 0.25), 10, 0.55, Color(0.76, 0.93, 1.0, 0.52), 0.12)
	racer.add_child(wake)
	racer.add_child(splash)
	racer.add_child(bubbles)
	wake.emitting = false
	splash.emitting = false
	bubbles.emitting = false
	_presentations[racer.get_instance_id()] = {
		"racer": racer,
		"slot": slot,
		"base_position": slot.position,
		"base_rotation": slot.rotation,
		"wake": wake,
		"splash": splash,
		"bubbles": bubbles,
		"phase": float(racer.get_instance_id() % 19) * 0.47,
	}
	print("r5_direct_swimmer_visual racer=%s animal=%s board=false body_submerged=true" % [
		RaceManager.get_racer_label(racer), String(racer.animal_id),
	])

func _update_presentations() -> void:
	for key in _presentations.keys():
		var entry: Dictionary = _presentations.get(key, {})
		var racer := entry.get("racer") as WildDashCharacterController
		var slot := entry.get("slot") as Node3D
		if racer == null or slot == null or not is_instance_valid(racer) or not is_instance_valid(slot):
			continue
		var driver := _find_swim_driver(racer)
		var diving := driver != null and driver.has_method("is_diving") and bool(driver.call("is_diving"))
		var bursting := driver != null and driver.has_method("is_bursting") and bool(driver.call("is_bursting"))
		var speed_ratio := clampf(racer.current_speed / 13.5, 0.0, 1.0)
		var phase := float(entry.get("phase", 0.0))
		var cadence := lerpf(4.8, 8.2, speed_ratio)
		var stroke := sin(_elapsed * cadence + phase)
		var bob := sin(_elapsed * cadence * 2.0 + phase) * 0.035 * speed_ratio
		var lateral_speed := racer.global_transform.basis.x.dot(racer.velocity)
		var turn_roll := clampf(lateral_speed / 12.0, -1.0, 1.0) * MAX_TURN_ROLL

		var base_position: Vector3 = entry.get("base_position", Vector3.ZERO)
		var base_rotation: Vector3 = entry.get("base_rotation", Vector3.ZERO)
		var immersion := _immersion_for_animal(racer.animal_id)
		var pitch := BASE_SWIM_PITCH
		if bursting:
			pitch = BURST_SWIM_PITCH
		if diving:
			pitch = DIVE_SWIM_PITCH
			immersion += DIVE_EXTRA_IMMERSION

		slot.position = base_position + Vector3(0.0, -immersion + bob, 0.0)
		slot.rotation = base_rotation + Vector3(
			pitch + stroke * 0.018 * speed_ratio,
			0.0,
			stroke * MAX_STROKE_ROLL * speed_ratio - turn_roll,
		)

		var visual := racer.get_visual()
		if visual != null:
			# The shared controller reports airborne in water, which otherwise selects
			# Jump. In Round 5 the existing Run cycle is repurposed as a lightweight
			# stroke cycle until dedicated swim clips are authored.
			if racer.finished:
				visual.play_state(&"Idle")
			else:
				visual.play_state(&"Run")

		var wake := entry.get("wake") as GPUParticles3D
		var splash := entry.get("splash") as GPUParticles3D
		var bubbles := entry.get("bubbles") as GPUParticles3D
		if wake != null:
			wake.emitting = racer.current_speed > 3.6 and not diving
			wake.amount = 28 if bursting else 18
		if splash != null:
			splash.emitting = racer.current_speed > 4.4 and not diving
			splash.amount = 20 if bursting else 12
		if bubbles != null:
			bubbles.emitting = diving

func _strip_board_like_feedback(racer: WildDashCharacterController) -> void:
	var legacy := racer.get_node_or_null("Round5SwimFeedback")
	if legacy == null:
		return
	for child_name in ["WakeTrail", "SurfaceSplash"]:
		var mesh_instance := legacy.get_node_or_null(child_name) as MeshInstance3D
		if mesh_instance != null and mesh_instance.mesh != null:
			mesh_instance.mesh = null
			mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			print("r5_ride_visual_removed racer=%s node=%s board_mesh=false" % [
				RaceManager.get_racer_label(racer), child_name,
			])

func _find_swim_driver(racer: WildDashCharacterController) -> Node:
	var race_root := get_parent()
	if race_root == null:
		return null
	return race_root.get_node_or_null("%sSwimDriver" % racer.name)

func _immersion_for_animal(animal_id: StringName) -> float:
	if animal_id in [&"bear", &"elephant", &"boar"]:
		return LARGE_ANIMAL_IMMERSION
	return SURFACE_IMMERSION

func _make_particles(
	name_text: String,
	local_position: Vector3,
	direction_value: Vector3,
	amount_value: int,
	lifetime_value: float,
	color_value: Color,
	size_value: float,
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = name_text
	particles.position = local_position
	particles.amount = amount_value
	particles.lifetime = lifetime_value
	particles.local_coords = false
	particles.preprocess = 0.15

	var process_material := ParticleProcessMaterial.new()
	process_material.direction = direction_value.normalized()
	process_material.spread = 32.0
	process_material.initial_velocity_min = 0.65
	process_material.initial_velocity_max = 1.75
	process_material.gravity = Vector3(0.0, 0.45, 0.0)
	process_material.color = color_value
	particles.process_material = process_material

	var quad := QuadMesh.new()
	quad.size = Vector2(size_value, size_value)
	var material := StandardMaterial3D.new()
	material.albedo_color = color_value
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad.material = material
	particles.draw_pass_1 = quad
	return particles
