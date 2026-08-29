class_name WildDashStormBomb
extends Node3D

## Telegraphed Round 5 leader strike.
## The warning marker follows the targeted leader for a short window before the
## strike resolves through ItemSystem, leaving Bubble Shield as a real counter.

const WARNING_SECONDS: float = 1.25
const SLOW_DURATION: float = 1.02
const SLOW_MULTIPLIER: float = 0.48
const KNOCKBACK: float = 6.0

var source_racer: WildDashCharacterController
var target_racer: WildDashCharacterController
var _elapsed: float = 0.0
var _armed: bool = false
var _warning_disc: CSGCylinder3D
var _warning_beacon: CSGCylinder3D

func configure(source: WildDashCharacterController, target: WildDashCharacterController) -> void:
	source_racer = source
	target_racer = target
	_armed = source_racer != null and target_racer != null
	_build_warning_visual()
	if _armed:
		print("r5_storm_bomb_warning source=%s target=%s target_rank=1 warning=%.2f shield_counter=true" % [
			RaceManager.get_racer_label(source_racer), RaceManager.get_racer_label(target_racer), WARNING_SECONDS,
		])
		AudioManager.play_sfx_id("item", 1.0)

func _process(delta: float) -> void:
	if not _armed:
		queue_free()
		return
	if source_racer == null or not is_instance_valid(source_racer) or target_racer == null or not is_instance_valid(target_racer) or target_racer.finished:
		queue_free()
		return
	_elapsed += delta
	global_position = Vector3(target_racer.global_position.x, 0.04, target_racer.global_position.z)
	var pulse := 0.88 + sin(_elapsed * 15.0) * 0.12
	if _warning_disc != null:
		_warning_disc.scale = Vector3(pulse, 1.0, pulse)
	if _warning_beacon != null:
		_warning_beacon.scale.y = 0.85 + pulse * 0.18
	if _elapsed >= WARNING_SECONDS:
		_resolve_strike()

func _resolve_strike() -> void:
	if target_racer == null or not is_instance_valid(target_racer):
		queue_free()
		return
	var resolved := ItemSystem.apply_attack(
		target_racer,
		source_racer,
		&"storm_bomb",
		SLOW_DURATION,
		SLOW_MULTIPLIER,
		KNOCKBACK
	)
	if resolved:
		var visual := target_racer.get_visual()
		if visual != null:
			visual.play_action(&"Hit", 0.34)
		AudioManager.play_sfx_id("splash", 1.0)
	print("r5_storm_bomb_strike source=%s target=%s resolved=%s slow=%.2f knockback=%.1f warning=%.2f shield_counter=true" % [
		RaceManager.get_racer_label(source_racer), RaceManager.get_racer_label(target_racer), str(resolved), SLOW_MULTIPLIER, KNOCKBACK, WARNING_SECONDS,
	])
	queue_free()

func _build_warning_visual() -> void:
	_warning_disc = CSGCylinder3D.new()
	_warning_disc.name = "StormBombWarningDisc"
	_warning_disc.radius = 3.2
	_warning_disc.height = 0.05
	_warning_disc.sides = 24
	_warning_disc.use_collision = false
	var disc_material := StandardMaterial3D.new()
	disc_material.albedo_color = Color(1.0, 0.45, 0.08, 0.58)
	disc_material.emission_enabled = true
	disc_material.emission = Color(0.75, 0.18, 0.02)
	disc_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_warning_disc.material = disc_material
	add_child(_warning_disc)

	_warning_beacon = CSGCylinder3D.new()
	_warning_beacon.name = "StormBombWarningBeacon"
	_warning_beacon.position = Vector3(0.0, 3.1, 0.0)
	_warning_beacon.radius = 0.18
	_warning_beacon.height = 6.2
	_warning_beacon.sides = 10
	_warning_beacon.use_collision = false
	var beacon_material := StandardMaterial3D.new()
	beacon_material.albedo_color = Color(1.0, 0.82, 0.18, 0.72)
	beacon_material.emission_enabled = true
	beacon_material.emission = Color(0.95, 0.52, 0.08)
	beacon_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_warning_beacon.material = beacon_material
	add_child(_warning_beacon)
