extends "res://modes/push_out/wild_rumble_round4_mode.gd"

## Round 4 control-safety wrapper.
## Arena movement is world-space: left/right map to X and forward/back map to Z.
## The previous Titan Crown camera rotated behind the player's facing direction,
## so the screen rotated around fixed world-space input and made arrow keys look
## reversed (left could appear right, down could appear forward).
##
## Keep the camera dynamically following the player position, but lock its arena
## heading to the canonical +Z viewing side. This preserves the intended mapping:
##   Left/A  -> screen left
##   Right/D -> screen right
##   Up/W    -> screen forward/up
##   Down/S  -> screen back/down
## Player facing can still rotate freely for combat; the camera no longer rotates
## the control frame underneath the player.

const ROUND4_CAMERA_WORLD_BACK := Vector3(0.0, 0.0, 1.0)

func _create_round4_dynamic_camera() -> void:
	var old_camera := get_node_or_null("WildRumblePhase1Camera") as Camera3D
	if old_camera != null:
		old_camera.current = false

	_round4_dynamic_camera = Camera3D.new()
	_round4_dynamic_camera.name = "TitanCrownFollowCamera"
	_round4_dynamic_camera.fov = 62.0
	_round4_dynamic_camera.current = true
	add_child(_round4_dynamic_camera)

	if player != null:
		_round4_dynamic_camera.global_position = (
			player.global_position
			+ ROUND4_CAMERA_WORLD_BACK * CAMERA_DISTANCE
			+ Vector3.UP * CAMERA_HEIGHT
		)
		_round4_dynamic_camera.look_at(player.global_position + Vector3.UP * 1.1, Vector3.UP)

	print("WILD RUMBLE ROUND4 CONTROLS READY camera_heading_locked=true arrows_screen_relative=true")

func _update_round4_dynamic_camera(delta: float) -> void:
	if _round4_dynamic_camera == null or player == null or not is_instance_valid(player):
		return

	# Position follows the player, heading does not follow player rotation.
	# That keeps the world-space arena input aligned with the screen at all times.
	var desired_position := (
		player.global_position
		+ ROUND4_CAMERA_WORLD_BACK * CAMERA_DISTANCE
		+ Vector3.UP * CAMERA_HEIGHT
	)
	var smoothing := clampf(CAMERA_SMOOTHING * delta, 0.0, 1.0)
	_round4_dynamic_camera.global_position = _round4_dynamic_camera.global_position.lerp(desired_position, smoothing)

	if _round4_camera_shake_remaining > 0.0:
		_round4_camera_shake_remaining = maxf(0.0, _round4_camera_shake_remaining - delta)
		_round4_camera_shake_phase += delta * 52.0
		var shake := Vector3(
			sin(_round4_camera_shake_phase),
			cos(_round4_camera_shake_phase * 1.31),
			0.0
		) * 0.16
		_round4_dynamic_camera.global_position += shake * clampf(
			_round4_camera_shake_remaining / 0.18,
			0.0,
			1.0
		)

	# Do not rotate toward relics/crown here. Objective-biased look-at was another
	# source of changing screen directions. Objective information remains in HUD
	# and world indicators while movement stays predictable.
	_round4_dynamic_camera.look_at(player.global_position + Vector3.UP * 1.1, Vector3.UP)
