extends Node

const LANDING_PROTECTION_SECONDS: float = 0.30
const LANDING_KNOCKBACK_CAP: float = 1.85
const AIRBORNE_KNOCKBACK_CAP: float = 3.10
const LIGHT_GROUND_CAP: float = 4.00
const MEDIUM_GROUND_CAP: float = 4.25
const HEAVY_GROUND_CAP: float = 4.55
const LOG_INTERVAL_SECONDS: float = 1.2

const LIGHT_IDS: Array[StringName] = [&"rabbit", &"cat", &"fox"]
const HEAVY_IDS: Array[StringName] = [&"boar", &"bear", &"crocodile", &"elephant"]

var _landing_protection: Dictionary = {}
var _was_on_floor: Dictionary = {}
var _last_log_at: Dictionary = {}
var _configured: bool = false

func configure() -> void:
	_configured = true
	print("LOGSPIRE COMBAT SAFETY READY landing_protection=%.2fs airborne_cap=%.2f edge_knockback_clamp=true body_check_preserved=true item_disruption_preserved=true" % [
		LANDING_PROTECTION_SECONDS, AIRBORNE_KNOCKBACK_CAP,
	])

func _physics_process(delta: float) -> void:
	if not _configured or not RaceManager.active:
		return
	for racer_value: Variant in RaceManager.racers:
		var racer := racer_value as WildDashCharacterController
		if racer == null or racer.finished:
			continue
		_update_racer_safety(racer, delta)

func _update_racer_safety(racer: WildDashCharacterController, delta: float) -> void:
	var id: int = racer.get_instance_id()
	var on_floor: bool = racer.is_on_floor()
	var was_floor: bool = bool(_was_on_floor.get(id, on_floor))
	if on_floor and not was_floor:
		_landing_protection[id] = LANDING_PROTECTION_SECONDS
		_play_wood_land(racer)
	_was_on_floor[id] = on_floor

	var protection: float = maxf(0.0, float(_landing_protection.get(id, 0.0)) - delta)
	_landing_protection[id] = protection
	var knockback: Vector3 = racer.get_knockback_velocity()
	var planar := Vector3(knockback.x, 0.0, knockback.z)
	var magnitude: float = planar.length()
	if magnitude <= 0.001:
		return

	var cap: float = _ground_cap_for(racer)
	var reason := "ground"
	if protection > 0.0:
		cap = LANDING_KNOCKBACK_CAP
		reason = "landing_protection"
	elif not on_floor:
		cap = AIRBORNE_KNOCKBACK_CAP
		reason = "airborne_edge"

	if magnitude <= cap:
		return
	var clamped := planar.normalized() * cap
	clamped.y = knockback.y
	racer.set("_knockback_velocity", clamped)
	_log_clamp(racer, magnitude, cap, reason)

func _ground_cap_for(racer: WildDashCharacterController) -> float:
	if racer == null:
		return MEDIUM_GROUND_CAP
	if LIGHT_IDS.has(racer.animal_id):
		return LIGHT_GROUND_CAP
	if HEAVY_IDS.has(racer.animal_id):
		return HEAVY_GROUND_CAP
	return MEDIUM_GROUND_CAP

func _log_clamp(racer: WildDashCharacterController, before: float, after: float, reason: String) -> void:
	var id: int = racer.get_instance_id()
	var now: float = Time.get_ticks_msec() * 0.001
	var previous: float = float(_last_log_at.get(id, -100.0))
	if now - previous < LOG_INTERVAL_SECONDS:
		return
	_last_log_at[id] = now
	print("LOGSPIRE COMBAT CLAMP racer=%s reason=%s knockback=%.2f->%.2f instant_fall_guard=true" % [
		RaceManager.get_racer_label(racer), reason, before, after,
	])

func _play_wood_land(racer: WildDashCharacterController) -> void:
	if racer == null or not racer.is_player or DisplayServer.get_name() == "headless":
		return
	var library_value: Variant = AudioManager.get("_sfx_library")
	if library_value is Dictionary and (library_value as Dictionary).has("wood_land"):
		AudioManager.play_sfx_id("wood_land", 0.38)
	else:
		AudioManager.play_sfx_id("hit", 0.18)
