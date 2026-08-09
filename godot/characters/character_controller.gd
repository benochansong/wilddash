class_name WildDashCharacterController
extends CharacterBody3D

signal skill_requested(animal_id: StringName)
signal held_item_changed(item_id: StringName)
signal finished_race(rank: int)
signal arena_action_requested
signal animal_configured(animal_id: StringName)

enum MovementMode {
	RACE,
	ARENA,
}

@export var is_player := true
@export var animal_id: StringName = &"dog"
@export var movement_mode: MovementMode = MovementMode.RACE

# Runtime values are populated from WildDashAnimalDefinition. They remain
# public because AI/mode code reads them directly.
@export var max_speed := 14.5
@export var cruise_speed := 8.8
@export var acceleration := 24.0
@export var turn_speed := 2.15
@export var jump_velocity := 7.5
@export var gravity := 22.0
@export var arena_move_speed := 9.5
@export var arena_acceleration := 28.0
@export var knockback_decay := 16.0

var animal_definition: WildDashAnimalDefinition
var current_speed := 0.0
var skill_cooldown_remaining := 0.0
var finished := false
var finish_rank := 0
var _held_item: StringName = &""
var _knockback_velocity := Vector3.ZERO
var _performance_lod_level := 0
var _skill_effect_remaining := 0.0
var _skill_speed_multiplier := 1.0
var _skill_turn_multiplier := 1.0
var _skill_jump_multiplier := 1.0
var _skill_knockback_multiplier := 1.0
var _hit_reaction_cooldown := 0.0
var _visual: WildDashCharacterVisual

@onready var _collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var _visual_slot := get_node_or_null("VisualSlot") as Node3D

func _ready() -> void:
	_apply_animal_definition()
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(52.0)
	if movement_mode == MovementMode.RACE:
		RaceManager.register_racer(self)

func _exit_tree() -> void:
	if movement_mode == MovementMode.RACE:
		RaceManager.unregister_racer(self)

func _physics_process(delta: float) -> void:
	skill_cooldown_remaining = maxf(0.0, skill_cooldown_remaining - delta)
	_hit_reaction_cooldown = maxf(0.0, _hit_reaction_cooldown - delta)
	_update_skill_effect(delta)
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
	target_speed *= _skill_speed_multiplier

	current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	rotate_y(-steer * turn_speed * _skill_turn_multiplier * delta)

	if InputManager.consume_jump() and is_on_floor():
		velocity.y = jump_velocity * _skill_jump_multiplier
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
		_trigger_hit_visual()
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
	var desired_speed := arena_move_speed * _skill_speed_multiplier
	var desired := Vector3(move_axis.x, 0.0, move_axis.y) * desired_speed + _knockback_velocity
	velocity.x = move_toward(velocity.x, desired.x, arena_acceleration * delta)
	velocity.z = move_toward(velocity.z, desired.z, arena_acceleration * delta)
	if move_axis.length_squared() > 0.01:
		var desired_yaw := atan2(-move_axis.x, -move_axis.y)
		rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(turn_speed * _skill_turn_multiplier * delta, 0.0, 1.0))
	if InputManager.consume_jump():
		if is_on_floor():
			velocity.y = jump_velocity * 0.78 * _skill_jump_multiplier
		arena_action_requested.emit()
	if InputManager.consume_skill():
		try_use_skill()
		arena_action_requested.emit()

	_apply_gravity(delta)
	move_and_slide()
	if has_blocking_collision():
		_trigger_hit_visual()
	current_speed = Vector2(velocity.x, velocity.z).length()
	decay_knockback(delta)
	_sync_visual()

func configure_animal(id: StringName) -> void:
	animal_id = id if WildDashAnimalCatalog.is_valid(id) else &"dog"
	if is_inside_tree():
		_apply_animal_definition()

func get_animal_definition() -> WildDashAnimalDefinition:
	return animal_definition

func get_visual() -> WildDashCharacterVisual:
	return _visual

func get_camera_profile() -> Dictionary:
	if animal_definition == null:
		return {
			"follow_distance": 9.5,
			"follow_height": 5.2,
			"look_ahead": 4.5,
			"smoothing": 7.0,
			"fov": 70.0,
		}
	return animal_definition.camera_profile()

func get_display_name() -> String:
	return String(animal_id).capitalize() if animal_definition == null else animal_definition.display_name

func get_skill_name() -> String:
	return "Skill" if animal_definition == null else animal_definition.skill_name

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
	_knockback_velocity += planar.normalized() * strength * _skill_knockback_multiplier

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
	var definition := animal_definition
	if definition == null:
		definition = WildDashAnimalCatalog.get_definition(animal_id)
	if definition == null:
		return false

	skill_cooldown_remaining = definition.skill_cooldown
	_start_skill_effect(definition)
	match definition.skill_id:
		&"leap":
			if is_on_floor():
				velocity.y = jump_velocity * definition.skill_jump_multiplier
			current_speed = maxf(current_speed, cruise_speed * 1.15)
		&"dash":
			current_speed = maxf(current_speed, cruise_speed * 1.08)
		&"guard":
			_knockback_velocity *= 0.45
		&"evasion":
			current_speed = maxf(current_speed, cruise_speed)
		_:
			pass
	if _visual:
		_visual.play_action(&"Skill", minf(0.7, definition.skill_duration))
	skill_requested.emit(animal_id)
	return true

func set_held_item(item_id: StringName) -> void:
	_held_item = item_id
	held_item_changed.emit(item_id)

func get_held_item() -> StringName:
	return _held_item

func _apply_animal_definition() -> void:
	animal_definition = WildDashAnimalCatalog.get_definition(animal_id)
	if animal_definition == null:
		return
	animal_id = animal_definition.animal_id
	max_speed = animal_definition.max_speed
	cruise_speed = animal_definition.cruise_speed
	acceleration = animal_definition.acceleration
	turn_speed = animal_definition.turn_speed
	jump_velocity = animal_definition.jump_velocity
	gravity = animal_definition.gravity
	arena_move_speed = animal_definition.arena_move_speed
	arena_acceleration = animal_definition.arena_acceleration
	knockback_decay = animal_definition.knockback_decay
	_apply_collision_profile()
	_install_visual()
	animal_configured.emit(animal_id)

func _apply_collision_profile() -> void:
	if _collision_shape == null or animal_definition == null:
		return
	var capsule := CapsuleShape3D.new()
	capsule.radius = animal_definition.collision_radius
	capsule.height = maxf(animal_definition.collision_height, animal_definition.collision_radius * 2.0)
	_collision_shape.shape = capsule
	_collision_shape.position.y = animal_definition.collision_center_y

func _install_visual() -> void:
	if _visual_slot == null or animal_definition == null or animal_definition.visual_scene == null:
		return
	for child in _visual_slot.get_children():
		_visual_slot.remove_child(child)
		child.queue_free()
	var visual_instance := animal_definition.visual_scene.instantiate()
	if visual_instance == null:
		push_error("Failed to instantiate visual for %s" % animal_id)
		return
	visual_instance.name = "VisualModel"
	_visual_slot.add_child(visual_instance)
	_visual = visual_instance as WildDashCharacterVisual
	if _visual:
		_visual.set_lod_level(_performance_lod_level)

func _start_skill_effect(definition: WildDashAnimalDefinition) -> void:
	_skill_effect_remaining = maxf(0.0, definition.skill_duration)
	_skill_speed_multiplier = definition.skill_speed_multiplier
	_skill_turn_multiplier = definition.skill_turn_multiplier
	_skill_jump_multiplier = definition.skill_jump_multiplier
	_skill_knockback_multiplier = definition.skill_knockback_multiplier

func _update_skill_effect(delta: float) -> void:
	if _skill_effect_remaining <= 0.0:
		return
	_skill_effect_remaining = maxf(0.0, _skill_effect_remaining - delta)
	if _skill_effect_remaining <= 0.0:
		_skill_speed_multiplier = 1.0
		_skill_turn_multiplier = 1.0
		_skill_jump_multiplier = 1.0
		_skill_knockback_multiplier = 1.0

func _trigger_hit_visual() -> void:
	if _visual == null or _hit_reaction_cooldown > 0.0:
		return
	_hit_reaction_cooldown = 0.35
	_visual.play_action(&"Hit", 0.18)

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
