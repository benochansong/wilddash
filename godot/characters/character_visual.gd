class_name WildDashCharacterVisual
extends Node3D

## Stable visual contract between gameplay and imported 3D character assets.
## CharacterController never talks to Skeleton3D, AnimationPlayer, or GLB nodes directly.
## Placeholder scenes can use lightweight procedural motion until production rigs arrive.
## RC5 character-detail pass also keeps facial geometry behind this contract so
## gameplay code remains independent from eyes/nose/mouth implementation details.

@export var animation_player_path: NodePath
@export var animation_tree_path: NodePath
@export var procedural_root_path: NodePath
@export var procedural_placeholder := false
@export var idle_speed_threshold := 0.35
@export var default_action_lock_seconds := 0.45
@export var run_cycle_speed := 10.0
@export var run_bob_height := 0.10
@export var idle_bob_height := 0.045

var _animation_player: AnimationPlayer
var _animation_tree: AnimationTree
var _state_machine: AnimationNodeStateMachinePlayback
var _current_state: StringName = &""
var _action_lock_until_ms := 0
var _lod_level := 0
var _lod_tick := 0
var _procedural_root: Node3D
var _procedural_base_position := Vector3.ZERO
var _procedural_base_rotation := Vector3.ZERO
var _procedural_base_scale := Vector3.ONE
var _face_detail: WildDashCharacterFaceDetail

func _ready() -> void:
	_animation_player = _resolve_animation_player()
	_animation_tree = _resolve_animation_tree()
	if _animation_tree:
		var playback: Variant = _animation_tree.get("parameters/playback")
		if playback is AnimationNodeStateMachinePlayback:
			_state_machine = playback
	_resolve_procedural_root()
	_resolve_face_detail()
	set_lod_level(_lod_level)
	play_state(&"Idle")

func _process(_delta: float) -> void:
	if not procedural_placeholder or _procedural_root == null:
		return
	_animate_placeholder(Time.get_ticks_msec() * 0.001)

func set_lod_level(level: int) -> void:
	_lod_level = clampi(level, 0, 2)
	_lod_tick = 0
	if _face_detail:
		_face_detail.set_detail_lod(_lod_level)

func update_locomotion(speed: float, grounded: bool) -> void:
	_lod_tick += 1
	var update_every := 1
	if _lod_level == 1:
		update_every = 3
	elif _lod_level >= 2:
		update_every = 8
	if _lod_tick % update_every != 0:
		return
	if Time.get_ticks_msec() < _action_lock_until_ms:
		return
	if not grounded:
		play_state(&"Jump")
	elif absf(speed) > idle_speed_threshold:
		play_state(&"Run")
	else:
		play_state(&"Idle")

func play_action(action: StringName, lock_seconds := -1.0) -> void:
	var seconds := default_action_lock_seconds if lock_seconds < 0.0 else lock_seconds
	_action_lock_until_ms = Time.get_ticks_msec() + int(seconds * 1000.0)
	play_state(action, true)

func play_result(won: bool) -> void:
	play_action(&"Win" if won else &"Lose", 2.0)

func play_state(state: StringName, force := false) -> void:
	if not force and _current_state == state:
		return
	_current_state = state

	if _state_machine:
		_state_machine.travel(String(state))
		return

	if _animation_player and _animation_player.has_animation(state):
		_animation_player.play(state)

func get_current_state() -> StringName:
	return _current_state

func _resolve_animation_player() -> AnimationPlayer:
	if not animation_player_path.is_empty():
		return get_node_or_null(animation_player_path) as AnimationPlayer
	return find_child("AnimationPlayer", true, false) as AnimationPlayer

func _resolve_animation_tree() -> AnimationTree:
	if not animation_tree_path.is_empty():
		return get_node_or_null(animation_tree_path) as AnimationTree
	return find_child("AnimationTree", true, false) as AnimationTree

func _resolve_face_detail() -> void:
	_face_detail = find_child("FaceDetail", true, false) as WildDashCharacterFaceDetail

func _resolve_procedural_root() -> void:
	if not procedural_placeholder:
		return
	if not procedural_root_path.is_empty():
		_procedural_root = get_node_or_null(procedural_root_path) as Node3D
	if _procedural_root == null:
		_procedural_root = find_child("ImportedModel", true, false) as Node3D
	if _procedural_root:
		_procedural_base_position = _procedural_root.position
		_procedural_base_rotation = _procedural_root.rotation
		_procedural_base_scale = _procedural_root.scale

func _animate_placeholder(time_seconds: float) -> void:
	var offset := Vector3.ZERO
	var rotation_offset := Vector3.ZERO
	var scale_multiplier := 1.0
	match _current_state:
		&"Idle":
			offset.y = sin(time_seconds * 2.4) * idle_bob_height
			rotation_offset.z = sin(time_seconds * 1.7) * 0.025
		&"Run":
			var cycle := time_seconds * run_cycle_speed
			offset.y = absf(sin(cycle)) * run_bob_height
			rotation_offset.z = sin(cycle) * 0.075
			rotation_offset.x = cos(cycle * 0.5) * 0.035
		&"Jump":
			rotation_offset.x = -0.16
			offset.y = 0.08
		&"Hit":
			rotation_offset.z = sin(time_seconds * 28.0) * 0.22
			scale_multiplier = 0.96
		&"Skill":
			rotation_offset.y = sin(time_seconds * 16.0) * 0.13
			scale_multiplier = 1.0 + absf(sin(time_seconds * 12.0)) * 0.08
		&"Win":
			offset.y = absf(sin(time_seconds * 5.5)) * 0.22
			rotation_offset.y = sin(time_seconds * 3.5) * 0.28
		&"Lose":
			offset.y = -0.10
			rotation_offset.x = 0.28
		_:
			pass
	_procedural_root.position = _procedural_base_position + offset
	_procedural_root.rotation = _procedural_base_rotation + rotation_offset
	_procedural_root.scale = _procedural_base_scale * scale_multiplier
