extends Node

## AI Battle spectator camera shared by all campaign rounds.
## It never changes racer gameplay state; it only owns the active camera and a
## compact overlay while the persistent GameManager spectator flag is enabled.

const SPECTATOR_META: StringName = &"wilddash_spectator_mode"
const AUTO_SWITCH_SECONDS: float = 7.5
const FOLLOW_DISTANCE: float = 9.5
const FOLLOW_HEIGHT: float = 5.8
const LOOK_HEIGHT: float = 1.15
const POSITION_SMOOTHING: float = 5.8
const FOV: float = 68.0

var _mode_root: Node
var _targets: Array[WildDashCharacterController] = []
var _target_index: int = 0
var _auto_switch_elapsed: float = 0.0
var _camera: Camera3D
var _label: Label
var _last_target_id: int = 0

func configure(mode_root: Node, racer_values: Array) -> void:
	_mode_root = mode_root
	_targets.clear()
	for value: Variant in racer_values:
		var racer := value as WildDashCharacterController
		if racer != null and is_instance_valid(racer):
			_targets.append(racer)
	if _targets.is_empty():
		push_warning("SPECTATOR MODE no racers available")
		return

	var previous_camera: Camera3D = get_viewport().get_camera_3d()
	if previous_camera != null:
		previous_camera.current = false

	_camera = Camera3D.new()
	_camera.name = "SpectatorCamera"
	_camera.fov = FOV
	_camera.current = true
	mode_root.add_child(_camera)

	_build_overlay(mode_root)
	_target_index = 0
	_focus_current(true)
	print("SPECTATOR MODE READY racers=%d auto_switch=%.1fs manual=LEFT_RIGHT" % [_targets.size(), AUTO_SWITCH_SECONDS])

func _process(delta: float) -> void:
	if not _spectator_enabled() or _camera == null or _targets.is_empty():
		return
	var target := _current_target()
	if target == null:
		_cycle_target(1, true)
		return

	_auto_switch_elapsed += delta
	if _auto_switch_elapsed >= AUTO_SWITCH_SECONDS:
		_auto_switch_elapsed = 0.0
		_cycle_target(1, true)
		target = _current_target()
		if target == null:
			return

	var forward := -target.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	var focus := target.global_position + Vector3.UP * LOOK_HEIGHT
	var desired := target.global_position - forward * FOLLOW_DISTANCE + Vector3.UP * FOLLOW_HEIGHT
	_camera.global_position = _camera.global_position.lerp(desired, clampf(delta * POSITION_SMOOTHING, 0.0, 1.0))
	_camera.look_at(focus, Vector3.UP)
	_update_overlay(target)

func _unhandled_key_input(event: InputEvent) -> void:
	if not _spectator_enabled() or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_LEFT:
			_cycle_target(-1, false)
			get_viewport().set_input_as_handled()
		KEY_RIGHT, KEY_TAB:
			_cycle_target(1, false)
			get_viewport().set_input_as_handled()

func _cycle_target(direction: int, automatic: bool) -> void:
	if _targets.is_empty():
		return
	var start_index: int = _target_index
	for step: int in range(1, _targets.size() + 1):
		var candidate_index: int = posmod(start_index + direction * step, _targets.size())
		var candidate: WildDashCharacterController = _targets[candidate_index]
		if _is_watchable(candidate):
			_target_index = candidate_index
			_auto_switch_elapsed = 0.0
			_focus_current(false)
			print("SPECTATOR TARGET SWITCH index=%d racer=%s automatic=%s" % [
				_target_index,
				RaceManager.get_racer_label(candidate),
				str(automatic),
			])
			return

func _focus_current(snap_camera: bool) -> void:
	var target := _current_target()
	if target == null:
		return
	var target_id: int = target.get_instance_id()
	if target_id != _last_target_id:
		_last_target_id = target_id
		_update_overlay(target)
	if not snap_camera or _camera == null:
		return
	var forward := -target.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() <= 0.001:
		forward = Vector3.FORWARD
	else:
		forward = forward.normalized()
	_camera.global_position = target.global_position - forward * FOLLOW_DISTANCE + Vector3.UP * FOLLOW_HEIGHT
	_camera.look_at(target.global_position + Vector3.UP * LOOK_HEIGHT, Vector3.UP)

func _current_target() -> WildDashCharacterController:
	if _targets.is_empty():
		return null
	_target_index = clampi(_target_index, 0, _targets.size() - 1)
	var target: WildDashCharacterController = _targets[_target_index]
	if _is_watchable(target):
		return target
	return null

func _is_watchable(racer: WildDashCharacterController) -> bool:
	return racer != null and is_instance_valid(racer) and racer.visible and not racer.finished

func _spectator_enabled() -> bool:
	return bool(GameManager.get_meta(SPECTATOR_META, false))

func _build_overlay(mode_root: Node) -> void:
	var layer := CanvasLayer.new()
	layer.name = "SpectatorOverlay"
	layer.layer = 90
	mode_root.add_child(layer)

	var panel := ColorRect.new()
	panel.name = "SpectatorBanner"
	panel.position = Vector2(18.0, 18.0)
	panel.size = Vector2(650.0, 48.0)
	panel.color = Color(0.015, 0.025, 0.05, 0.82)
	layer.add_child(panel)

	_label = Label.new()
	_label.position = Vector2(14.0, 8.0)
	_label.size = Vector2(620.0, 34.0)
	_label.add_theme_font_size_override("font_size", 20)
	_label.add_theme_color_override("font_color", Color(0.40, 0.90, 1.0))
	panel.add_child(_label)

func _update_overlay(target: WildDashCharacterController) -> void:
	if _label == null or target == null:
		return
	var detail := ""
	if target.movement_mode == WildDashCharacterController.MovementMode.RACE and RaceManager.racers.has(target):
		detail = " · RANK %d/%d" % [RaceManager.get_rank(target), RaceManager.racers.size()]
	_label.text = "SPECTATOR MODE · WATCHING %s%s · ← → SWITCH · AUTO %.0fs" % [
		target.get_display_name().to_upper(), detail, AUTO_SWITCH_SECONDS,
	]
