class_name WildDashRiverTorpedo
extends Node3D

## Round 5 anti-leader homing water projectile.
## It seeks the current leader target selected on use and resolves through the
## shared ItemSystem so Bubble Shield and hit protection remain authoritative.

const SPEED: float = 52.0
const TURN_RESPONSE: float = 5.8
const HIT_RADIUS: float = 2.55
const MAX_LIFETIME: float = 7.0
const SLOW_DURATION: float = 0.92
const SLOW_MULTIPLIER: float = 0.54
const KNOCKBACK: float = 7.2

var source_racer: WildDashCharacterController
var target_racer: WildDashCharacterController
var _velocity: Vector3 = Vector3.ZERO
var _elapsed: float = 0.0
var _armed: bool = false

func configure(source: WildDashCharacterController, target: WildDashCharacterController) -> void:
	source_racer = source
	target_racer = target
	_armed = source_racer != null and target_racer != null
	_build_visual()
	if _armed:
		var initial_direction := target_racer.global_position - source_racer.global_position
		initial_direction.y = 0.0
		_velocity = (Vector3.FORWARD if initial_direction.length_squared() <= 0.001 else initial_direction.normalized()) * SPEED
		print("r5_river_torpedo_launch source=%s target=%s target_rank=1 speed=%.1f shield_counter=true" % [
			RaceManager.get_racer_label(source_racer), RaceManager.get_racer_label(target_racer), SPEED,
		])
		AudioManager.play_sfx_id("skill", 1.0)

func _process(delta: float) -> void:
	if not _armed:
		queue_free()
		return
	_elapsed += delta
	if _elapsed >= MAX_LIFETIME:
		print("r5_river_torpedo_expire target=%s lifetime=%.1f" % [_target_label(), MAX_LIFETIME])
		queue_free()
		return
	if source_racer == null or not is_instance_valid(source_racer):
		queue_free()
		return
	if target_racer == null or not is_instance_valid(target_racer) or target_racer.finished:
		queue_free()
		return

	var aim_point := target_racer.global_position + Vector3(0.0, 0.28, 0.0)
	var to_target := aim_point - global_position
	if to_target.length() <= HIT_RADIUS:
		_resolve_hit()
		return
	var desired := to_target.normalized() * SPEED
	_velocity = _velocity.lerp(desired, clampf(TURN_RESPONSE * delta, 0.0, 1.0))
	if _velocity.length_squared() > 0.001:
		_velocity = _velocity.normalized() * SPEED
	global_position += _velocity * delta
	if _velocity.length_squared() > 0.001:
		look_at(global_position + _velocity.normalized(), Vector3.UP)

func _resolve_hit() -> void:
	if target_racer == null or not is_instance_valid(target_racer):
		queue_free()
		return
	var resolved := ItemSystem.apply_attack(
		target_racer,
		source_racer,
		&"river_torpedo",
		SLOW_DURATION,
		SLOW_MULTIPLIER,
		KNOCKBACK
	)
	if resolved:
		var visual := target_racer.get_visual()
		if visual != null:
			visual.play_action(&"Hit", 0.30)
		AudioManager.play_sfx_id("splash", 1.0)
	print("r5_river_torpedo_hit source=%s target=%s resolved=%s slow=%.2f knockback=%.1f shield_counter=true" % [
		RaceManager.get_racer_label(source_racer), _target_label(), str(resolved), SLOW_MULTIPLIER, KNOCKBACK,
	])
	queue_free()

func _build_visual() -> void:
	var body := CSGSphere3D.new()
	body.name = "RiverTorpedoBody"
	body.radius = 0.42
	body.radial_segments = 12
	body.rings = 6
	body.use_collision = false
	var body_material := StandardMaterial3D.new()
	body_material.albedo_color = Color(0.95, 0.22, 0.10)
	body_material.emission_enabled = true
	body_material.emission = Color(0.65, 0.08, 0.02)
	body.material = body_material
	add_child(body)

	var wake := CSGBox3D.new()
	wake.name = "TorpedoWake"
	wake.position = Vector3(0.0, -0.08, 0.85)
	wake.size = Vector3(0.20, 0.08, 1.65)
	wake.use_collision = false
	var wake_material := StandardMaterial3D.new()
	wake_material.albedo_color = Color(0.76, 0.96, 1.0, 0.70)
	wake_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	wake.material = wake_material
	add_child(wake)

func _target_label() -> String:
	if target_racer != null and is_instance_valid(target_racer):
		return RaceManager.get_racer_label(target_racer)
	return "unknown"
