class_name WildDashCharacterController
extends CharacterBody3D

signal skill_requested(animal_id: StringName)
signal held_item_changed(item_id: StringName)
signal finished_race(rank: int)
signal arena_action_requested

enum MovementMode {
	RACE,
	ARENA,
}

@export var is_player := true
@export var animal_id: StringName = &"dog"
@export var movement_mode: MovementMode = MovementMode.RACE
@export var max_speed := 14.5
@export var cruise_speed := 8.8
@export var acceleration := 24.0
@export var turn_speed := 2.15
@export var jump_velocity := 7.5
@export var gravity := 22.0
@export var arena_move_speed := 9.5
@export var arena_acceleration := 28.0
@export var knockback_decay := 16.0

var current_speed := 0.0
var skill_cooldown_remaining := 0.0
var finished := false
var finish_rank := 0
var _held_item: StringName = &""
var _knockback_velocity := Vector3.ZERO
var _performance_lod_level := 0

@onready var _visual := get_node_or_null("VisualModel") as WildDashCharacterVisual

func _ready() -> void:
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(52.0)
	if movement_mode == MovementMode.RACE:
		RaceManager.register_racer(self)

func _exit_tree() -> void:
	if movement_mode == MovementMode.RACE:
		RaceManager.unregister_racer(self)

func _physics_process(delta: float) -> void:
	skill_cooldown_remaining = maxf(0.0, skill_cooldown_remaining - delta)
	if movement_mode == MovementMode.ARENA:
		_process_arena_player(delta)
		return

	if finished:
		_apply_finish_coast(delta)
		_sync_visual()
		return

	if not RaceManager.active:
		_settle_before_start(delta)
		_sync_visual()
		return

	if not is_player:
		_sync_visual()
		return

	var steer := InputManager.get_steer_axis()
	var throttle := InputManager.get_throttle_axis()
	var target_speed := cruise_speed
	if throttle > 0.05:
		target_speed = max_speed
	elif throttle < -0.05:
		target_speed = max_speed * 0.25

	current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	rotate_y(-steer * turn_speed * delta)

	if InputManager.consume_jump() and is_on_floor():
		velocity.y = jump_velocity
	if InputManager.consume_skill():
		try_use_skill()
	if InputManager.consume_item():
		ItemSystem.use_held_item(self)

	_apply_gravity(delta)
	var forward := -global_transform.basis.z.normalized()
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed
	move_and_slide()

	if has_blocking_collision():
		current_speed = maxf(cruise_speed * 0.55, current_speed * 0.92)
	_sync_visual()

func _process_arena_player(delta: float) -> void:
	if not GameManager.round_active:
		_settle_before_start(delta)
		_sync_visual()
		return
	if not is_player:
		_sync_visual()
		return

	var move_axis: Vector2 = InputManager.get_move_vector()
	var desired := Vector3(move_axis.x, 0.0, move_axis.y) * arena_move_speed + _knockback_velocity
	velocity.x = move_toward(velocity.x, desired.x, arena_acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, arena_acceleration * delta)
	if InputManager.consume_jump() or InputManager.consume_skill():
		arena_action_requested.emit()

	_apply_gravity(delta)
	move_and_slide()
	current_speed = Vector2(velocity.x, velocity.z).length()
	decay_knockback(delta)
	_sync_visual()

func has_blocking_collision() -> bool:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision.get_normal().y < 0.55:
			return true
	return false

func set_performance_lod(level: int) -> void:
	_performance_lod_level = clampi(level, 0, 2)
	# Layer 1 is world/track. Layer 2 is racers. Near racers keep crowd
	# collision; mid/far racers collide only with the world to reduce pair cost.
	collision_layer = 2
	collision_mask = 3 if _performance_lod_level == 0 else 1
	if _visual:
		_visual.set_lod_level(_performance_lod_level)

func get_performance_lod() -> int:
	return _performance_lod_level

func apply_knockback(direction: Vector3, strength: float) -> void:
	var planar := Vector3(direction.x, 0.0, direction.z)
	if planar.length_squared() <= 0.0001:
		return
	_knockback_velocity += planar.normalized() * strength

func get_knockback_velocity() -> Vector3:
	return _knockback_velocity

func decay_knockback(delta: float) -> void:
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, knockback_decay * delta)

func reset_motion(target_position: Vector3) -> void:
	global_position = target_position
	velocity = Vector3.ZERO
	_knockback_velocity = Vector3.ZERO
	current_speed = 0.0
	finished = false
	finish_rank = 0

func set_finished(rank: int) -> void:
	if finished:
		return
	finished = true
	finish_rank = rank
	finished_race.emit(rank)
	if _visual:
		_visual.play_result(rank == 1)

func try_use_skill() -> bool:
	if skill_cooldown_remaining > 0.0:
		return false
	skill_cooldown_remaining = _cooldown_for_animal(animal_id)
	if _visual:
		_visual.play_action(&"Skill")
	skill_requested.emit(animal_id)
	return true

func set_held_item(item_id: StringName) -> void:
	_held_item = item_id
	held_item_changed.emit(item_id)

func get_held_item() -> StringName:
	return _held_item

func _settle_before_start(delta: float) -> void:
	current_speed = move_toward(current_speed, 0.0, acceleration * delta)
	velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
	_apply_gravity(delta)
	move_and_slide()

func _apply_finish_coast(delta: float) -> void:
	current_speed = move_toward(current_speed, 0.0, acceleration * 0.7 * delta)
	var forward := -global_transform.basis.z.normalized()
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed
	_apply_gravity(delta)
	move_and_slide()

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

func _sync_visual() -> void:
	if _visual:
		_visual.update_locomotion(current_speed, is_on_floor())

func _cooldown_for_animal(id: StringName) -> float:
	match id:
		&"rabbit": return 8.0
		&"elephant": return 10.0
		&"cat": return 9.0
		_: return 12.0
