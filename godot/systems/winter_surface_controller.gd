class_name WildDashWinterSurfaceController
extends Node

@export var deep_snow_recovery := 14.0
@export var deep_snow_max_speed_ratio := 0.76
@export var report_interval := 1.25

var _racer: WildDashCharacterController
var _track: WildDashSnowpeakWinterTrack
var _feel: WildDashRacingFeelController
var _surface: StringName = &"normal_snow"
var _last_reported_surface: StringName = &""
var _report_elapsed := 0.0

func _ready() -> void:
	process_priority = 95

func _physics_process(delta: float) -> void:
	_resolve_nodes()
	if _racer == null or _track == null:
		return
	var profile := _track.get_surface_profile_at(_racer.global_position)
	_surface = StringName(profile.get("surface", &"normal_snow"))
	var slip_multiplier := float(profile.get("slip_multiplier", 1.0))
	if _feel != null:
		_feel.set_surface_slip_multiplier(slip_multiplier)

	if _racer.is_player and _racer.movement_mode == WildDashCharacterController.MovementMode.RACE and RaceManager.active:
		var speed_multiplier := float(profile.get("speed_multiplier", 1.0))
		if speed_multiplier < 0.999:
			var target_cap := _racer.max_speed * minf(deep_snow_max_speed_ratio, speed_multiplier)
			if _racer.current_speed > target_cap:
				_racer.current_speed = move_toward(_racer.current_speed, target_cap, deep_snow_recovery * delta)

	_report_elapsed += delta
	if _surface != _last_reported_surface and _report_elapsed >= 0.20:
		_last_reported_surface = _surface
		_report_elapsed = 0.0
		print("SNOWPEAK SURFACE player=%s surface=%s slip=%.2f" % [_racer.name, _surface, slip_multiplier])

func get_current_surface() -> StringName:
	return _surface

func _resolve_nodes() -> void:
	if _racer == null or not is_instance_valid(_racer):
		_racer = get_parent().get_node_or_null("Player") as WildDashCharacterController
	if _track == null or not is_instance_valid(_track):
		_track = get_parent().get_node_or_null("SnowpeakWorldTrack") as WildDashSnowpeakWinterTrack
	if _feel == null or not is_instance_valid(_feel):
		_feel = get_parent().get_node_or_null("RacingFeelController") as WildDashRacingFeelController
