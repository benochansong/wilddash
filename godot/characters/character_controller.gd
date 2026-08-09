class_name WildDashCharacterController
extends CharacterBody3D

signal skill_requested(animal_id: StringName)
signal held_item_changed(item_id: StringName)

@export var is_player := true
@export var animal_id: StringName = &"dog"
@export var max_speed := 14.0
@export var cruise_speed := 8.0
@export var acceleration := 24.0
@export var turn_speed := 1.9
@export var jump_velocity := 7.5
@export var gravity := 22.0

var current_speed := 0.0
var skill_cooldown_remaining := 0.0
var _held_item: StringName = &""

@onready var _visual := get_node_or_null("VisualModel") as WildDashCharacterVisual

func _ready() -> void:
	RaceManager.register_racer(self)

func _exit_tree() -> void:
	RaceManager.unregister_racer(self)

func _physics_process(delta: float) -> void:
	skill_cooldown_remaining = maxf(0.0, skill_cooldown_remaining - delta)
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

	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	var forward := -global_transform.basis.z.normalized()
	velocity.x = forward.x * current_speed
	velocity.z = forward.z * current_speed
	move_and_slide()
	_sync_visual()

func try_use_skill() -> bool:
	if skill_cooldown_remaining > 0.0:
		return false
	skill_cooldown_remaining = _cooldown_for_animal(animal_id)
	if _visual:
		_visual.play_action(&"Skill")
	# Effects are intentionally not implemented in the scaffold. The signal is
	# the seam for dog/rabbit/elephant/cat skill scenes or systems later.
	skill_requested.emit(animal_id)
	return true

func set_held_item(item_id: StringName) -> void:
	_held_item = item_id
	held_item_changed.emit(item_id)

func get_held_item() -> StringName:
	return _held_item

func _sync_visual() -> void:
	if _visual:
		_visual.update_locomotion(current_speed, is_on_floor())

func _cooldown_for_animal(id: StringName) -> float:
	match id:
		&"rabbit": return 8.0
		&"elephant": return 10.0
		&"cat": return 9.0
		_: return 12.0
