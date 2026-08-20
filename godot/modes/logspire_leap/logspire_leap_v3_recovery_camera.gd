extends "res://modes/logspire_leap/logspire_leap_v2_item_precision.gd"

## Round 3-only camera swap. Other rounds continue to use the shared chase
## camera unchanged. The recovery adapter exposes free water yaw and target
## focus while preserving the normal Logspire race camera profile.

const RECOVERY_CHASE_CAMERA_SCRIPT: Script = preload("res://modes/logspire_leap/logspire_recovery_chase_camera.gd")

func _ready() -> void:
	await super()
	if DisplayServer.get_name() == "headless" or player == null:
		return
	var existing := get_node_or_null("ChaseCamera") as Camera3D
	if existing != null:
		existing.current = false
		existing.name = "ChaseCameraLegacy"
		existing.queue_free()
	var camera := RECOVERY_CHASE_CAMERA_SCRIPT.new() as Camera3D
	if camera == null:
		return
	camera.name = "ChaseCamera"
	camera.current = true
	add_child(camera)
	camera.call("set_target", player)
	camera.set("follow_distance", 10.8)
	camera.set("follow_height", 6.7)
	camera.set("look_ahead", 7.2)
	camera.fov = 75.0
	print("LOGSPIRE RECOVERY CAMERA READY camera_relative_swim=true free_yaw=true target_focus=true round3_only=true")
