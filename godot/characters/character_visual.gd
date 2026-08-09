class_name WildDashCharacterVisual
extends Node3D

## Stable visual contract between gameplay and imported 3D character assets.
## CharacterController never talks to Skeleton3D, AnimationPlayer, or GLB nodes directly.

@export var animation_player_path: NodePath
@export var animation_tree_path: NodePath
@export var idle_speed_threshold := 0.35
@export var default_action_lock_seconds := 0.45

var _animation_player: AnimationPlayer
var _animation_tree: AnimationTree
var _state_machine: AnimationNodeStateMachinePlayback
var _current_state: StringName = &""
var _action_lock_until_ms := 0
var _lod_level := 0
var _lod_tick := 0

func _ready() -> void:
	_animation_player = _resolve_animation_player()
	_animation_tree = _resolve_animation_tree()
	if _animation_tree:
		var playback: Variant = _animation_tree.get("parameters/playback")
		if playback is AnimationNodeStateMachinePlayback:
			_state_machine = playback
	play_state(&"Idle")

func set_lod_level(level: int) -> void:
	_lod_level = clampi(level, 0, 2)
	_lod_tick = 0

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

func _resolve_animation_player() -> AnimationPlayer:
	if not animation_player_path.is_empty():
		return get_node_or_null(animation_player_path) as AnimationPlayer
	return find_child("AnimationPlayer", true, false) as AnimationPlayer

func _resolve_animation_tree() -> AnimationTree:
	if not animation_tree_path.is_empty():
		return get_node_or_null(animation_tree_path) as AnimationTree
	return find_child("AnimationTree", true, false) as AnimationTree
