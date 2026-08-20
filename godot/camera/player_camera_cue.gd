class_name WildDashPlayerCameraCue
extends Node

## Read-only camera cues for the local racer. No gameplay timing or movement is
## modified; this only requests restrained offsets from the existing ChaseCamera.

var _racer: WildDashCharacterController
var _last_grounded := true
var _progress_clock := 0.0
var _final_focus_requested := false

func _ready() -> void:
	_racer = get_parent() as WildDashCharacterController
	if _racer == null or not _racer.is_player or DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_last_grounded = _racer.is_on_floor()

func _process(delta: float) -> void:
	if _racer == null:
		return
	var grounded := _racer.is_on_floor()
	if _last_grounded and not grounded:
		var camera := get_viewport().get_camera_3d()
		if camera != null and camera.has_method("add_game_feel_impulse"):
			camera.call("add_game_feel_impulse", Vector3.UP, 0.035)
	_last_grounded = grounded
	_update_final_focus(delta)

func _update_final_focus(delta: float) -> void:
	if _final_focus_requested or _racer.finished or _racer.movement_mode != WildDashCharacterController.MovementMode.RACE or not RaceManager.active:
		return
	_progress_clock -= delta
	if _progress_clock > 0.0:
		return
	_progress_clock = 0.14
	if RaceManager.get_progress_percent(_racer) < 94.0:
		return
	var count := RaceManager.get_route_point_count()
	if count <= 0:
		return
	var finish_target := RaceManager.get_route_point(count - 1) + Vector3.UP * 1.5
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.has_method("request_target_focus"):
		camera.call("request_target_focus", finish_target, 0.85)
		_final_focus_requested = true
