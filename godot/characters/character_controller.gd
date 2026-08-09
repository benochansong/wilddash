class_name WildDashCharacterController
extends CharacterBody3D

signal skill_requested(animal_id: StringName)
signal held_item_changed(item_id: StringName)
signal finished_race(rank: int)
signal arena_action_requested
signal animal_configured(animal_id: StringName)
signal chimera_configured(loadout: WildDashChimeraLoadout)

enum MovementMode {
	RACE,
	ARENA,
}

const CHIMERA_VISUAL_SCENE: PackedScene = preload("res://chimera/chimera_visual.tscn")

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
var chimera_loadout: WildDashChimeraLoadout
var current_speed := 0.0
var skill_cooldown_remaining := 0.0
var finished := false
var finish_rank := 0
var _held_item: StringName = &""
var _knockback_velocity := Vector3.ZERO
var _skill_impulse_velocity := Vector3.ZERO
var _performance_lod_level := 0
var _skill_effect_remaining := 0.0
var _skill_speed_multiplier := 1.0
var _skill_acceleration_multiplier := 1.0
var _skill_turn_multiplier := 1.0
var _skill_jump_multiplier := 1.0
var _skill_knockback_multiplier := 1.0
var _skill_collision_retention_multiplier := 1.0
var _collision_evade_remaining := 0.0
var _stampede_hit_ids: Dictionary = {}
var _hit_reaction_cooldown := 0.0
var _visual: WildDashCharacterVisual
var _skill_definition_override: WildDashAnimalDefinition

# Persistent character/chimera traits. Skill multipliers are intentionally
# separate so E/X cooldown abilities never share state with Q/B items.
var _passive_pickup_radius_multiplier := 1.0
var _passive_acceleration_multiplier := 1.0
var _passive_turn_multiplier := 1.0
var _passive_jump_multiplier := 1.0
var _passive_knockback_received_multiplier := 1.0
var _passive_knockback_decay_multiplier := 1.0
var _collision_speed_retention := 0.92

@onready var _collision_shape := get_node_or_null("CollisionShape3D") as CollisionShape3D
@onready var _visual_slot := get_node_or_null("VisualSlot") as Node3D

func _ready() -> void:
	add_to_group("wilddash_racer")
	_apply_animal_definition()
	floor_snap_length = 0.35
	floor_max_angle = deg_to_rad(52.0)
	collision_layer = 2
	_refresh_collision_mask()
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

	current_speed = move_toward(current_speed, target_speed, acceleration * get_active_acceleration_scale() * delta)
	rotate_y(-steer * turn_speed * get_active_handling_scale() * delta)

	if InputManager.consume_jump() and is_on_floor():
		velocity.y = jump_velocity * _passive_jump_multiplier * _skill_jump_multiplier
	if InputManager.consume_skill():
		try_use_skill(Vector2(steer, -1.0))
	if InputManager.consume_item():
		ItemSystem.use_held_item(self)

	_apply_gravity(delta)
	var forward := -global_transform.basis.z.normalized()
	velocity.x = forward.x * current_speed + _knockback_velocity.x + _skill_impulse_velocity.x
	velocity.z = forward.z * current_speed + _knockback_velocity.z + _skill_impulse_velocity.z
	move_and_slide()
	resolve_skill_contacts()

	if has_blocking_collision():
		current_speed = maxf(cruise_speed * 0.55, current_speed * get_collision_speed_retention())
		_trigger_hit_visual()
	decay_knockback(delta)
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
	var desired := Vector3(move_axis.x, 0.0, move_axis.y) * desired_speed + _knockback_velocity + _skill_impulse_velocity
	velocity.x = move_toward(velocity.x, desired.x, arena_acceleration * get_active_acceleration_scale() * delta)
	velocity.z = move_toward(velocity.z, desired.z, arena_acceleration * get_active_acceleration_scale() * delta)
	if move_axis.length_squared() > 0.01:
		var desired_yaw := atan2(-move_axis.x, -move_axis.y)
		rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(turn_speed * get_active_handling_scale() * delta, 0.0, 1.0))
	if InputManager.consume_jump():
		if is_on_floor():
			velocity.y = jump_velocity * 0.78 * _passive_jump_multiplier * _skill_jump_multiplier
		arena_action_requested.emit()
	if InputManager.consume_skill():
		try_use_skill(move_axis)
		arena_action_requested.emit()

	_apply_gravity(delta)
	move_and_slide()
	resolve_skill_contacts()
	if has_blocking_collision():
		current_speed *= get_collision_speed_retention()
		_trigger_hit_visual()
	current_speed = Vector2(velocity.x, velocity.z).length()
	decay_knockback(delta)
	_sync_visual()

func configure_animal(id: StringName) -> void:
	chimera_loadout = null
	_skill_definition_override = null
	animal_id = id if WildDashAnimalCatalog.is_valid(id) else &"dog"
	_clear_skill_runtime()
	if is_inside_tree():
		_apply_animal_definition()

func configure_chimera(value: WildDashChimeraLoadout) -> void:
	chimera_loadout = value.duplicate_loadout() if value != null else WildDashChimeraSystem.default_loadout()
	chimera_loadout.normalize()
	var head_definition := WildDashAnimalCatalog.get_definition(chimera_loadout.head_id)
	var body_definition := WildDashAnimalCatalog.get_definition(chimera_loadout.body_id)
	var tail_definition := WildDashAnimalCatalog.get_definition(chimera_loadout.tail_id)
	if head_definition == null or body_definition == null or tail_definition == null:
		return

	# BODY remains the physical chassis so collision dimensions and baseline
	# movement stay readable, but its gameplay bonus is a restrained passive.
	# HEAD owns the exact source-animal active skill; TAIL adds only utility.
	animal_id = body_definition.animal_id
	animal_definition = body_definition
	_skill_definition_override = head_definition
	_clear_skill_runtime()
	_apply_definition_values(body_definition)
	_apply_chimera_profiles()
	_apply_collision_profile()
	_install_chimera_visual()
	chimera_configured.emit(chimera_loadout.duplicate_loadout())

func is_chimera() -> bool:
	return chimera_loadout != null

func get_chimera_loadout() -> WildDashChimeraLoadout:
	return null if chimera_loadout == null else chimera_loadout.duplicate_loadout()

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
	if chimera_loadout != null:
		return "Chimera"
	return String(animal_id).capitalize() if animal_definition == null else animal_definition.display_name

func get_skill_name() -> String:
	var definition := _get_active_skill_definition()
	return "SKILL" if definition == null else definition.skill_name

func get_skill_id() -> StringName:
	var definition := _get_active_skill_definition()
	return &"" if definition == null else definition.skill_id

func get_skill_cooldown() -> float:
	var definition := _get_active_skill_definition()
	return 0.0 if definition == null else definition.skill_cooldown

func get_skill_icon_text() -> String:
	match get_skill_id():
		&"rally_dash": return ">>"
		&"spring_leap": return "^"
		&"stampede": return "!!"
		&"shadow_step": return "<>"
		_: return "*"

func get_passive_name() -> String:
	if chimera_loadout == null:
		return ""
	return str(WildDashChimeraSystem.body_passive_profile(chimera_loadout.body_id).get("name", ""))

func get_utility_name() -> String:
	if chimera_loadout == null:
		return ""
	return str(WildDashChimeraSystem.tail_utility_profile(chimera_loadout.tail_id).get("name", ""))

func get_interaction_radius(base_radius: float) -> float:
	return base_radius * _passive_pickup_radius_multiplier

func get_active_speed_scale() -> float:
	return _skill_speed_multiplier

func get_active_acceleration_scale() -> float:
	return _passive_acceleration_multiplier * _skill_acceleration_multiplier

func get_active_handling_scale() -> float:
	return _passive_turn_multiplier * _skill_turn_multiplier

func get_collision_speed_retention() -> float:
	return clampf(_collision_speed_retention * _skill_collision_retention_multiplier, 0.78, 0.99)

func get_stat_profile() -> Dictionary:
	return {
		"speed": max_speed,
		"acceleration": acceleration * _passive_acceleration_multiplier,
		"handling": turn_speed * _passive_turn_multiplier,
		"mass": clampf(knockback_decay / 16.0 / _passive_knockback_received_multiplier, 0.75, 1.45),
		"jump": jump_velocity * _passive_jump_multiplier,
		"knockback_resistance": clampf(1.0 - _passive_knockback_received_multiplier + 0.5, 0.0, 1.0),
	}

func has_blocking_collision() -> bool:
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision.get_normal().y < 0.55:
			return true
	return false

func set_performance_lod(level: int) -> void:
	_performance_lod_level = clampi(level, 0, 2)
	collision_layer = 2
	_refresh_collision_mask()
	if _visual:
		_visual.set_lod_level(_performance_lod_level)

func get_performance_lod() -> int:
	return _performance_lod_level

func apply_knockback(direction: Vector3, strength: float) -> void:
	var planar := Vector3(direction.x, 0.0, direction.z)
	if planar.length_squared() <= 0.0001:
		return
	_knockback_velocity += planar.normalized() * strength * _passive_knockback_received_multiplier * _skill_knockback_multiplier

func get_knockback_velocity() -> Vector3:
	return _knockback_velocity

func decay_knockback(delta: float) -> void:
	_knockback_velocity = _knockback_velocity.move_toward(Vector3.ZERO, knockback_decay * _passive_knockback_decay_multiplier * delta)

func reset_motion(target_position: Vector3) -> void:
	global_position = target_position
	velocity = Vector3.ZERO
	_knockback_velocity = Vector3.ZERO
	_skill_impulse_velocity = Vector3.ZERO
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

func try_use_skill(direction_hint := Vector2.ZERO) -> bool:
	if skill_cooldown_remaining > 0.0:
		return false
	var definition := _get_active_skill_definition()
	if definition == null or not SkillSystem.is_valid_skill(definition.skill_id):
		return false

	skill_cooldown_remaining = definition.skill_cooldown
	_start_skill_effect(definition)
	var forward := -global_transform.basis.z.normalized()
	var right := global_transform.basis.x.normalized()

	match definition.skill_id:
		&"spring_leap":
			velocity.y = maxf(velocity.y, jump_velocity * _passive_jump_multiplier * definition.skill_jump_multiplier)
			current_speed = maxf(current_speed, max_speed * 1.10)
			_skill_impulse_velocity += forward * definition.skill_forward_impulse
		&"rally_dash":
			current_speed = maxf(current_speed, max_speed * 1.06)
			_skill_impulse_velocity += forward * definition.skill_forward_impulse
		&"stampede":
			current_speed = maxf(current_speed, max_speed * 1.08)
			_knockback_velocity *= 0.35
			_skill_impulse_velocity += forward * definition.skill_forward_impulse
			_stampede_hit_ids.clear()
		&"shadow_step":
			var lateral := clampf(direction_hint.x, -1.0, 1.0)
			if absf(lateral) < 0.22:
				lateral = 0.0
			_skill_impulse_velocity += forward * definition.skill_forward_impulse
			_skill_impulse_velocity += right * lateral * definition.skill_lateral_impulse
			current_speed = maxf(current_speed, cruise_speed)
			_collision_evade_remaining = maxf(_collision_evade_remaining, definition.skill_evade_duration)
			_refresh_collision_mask()
		_:
			return false

	if _visual:
		_visual.play_action(&"Skill", minf(0.7, definition.skill_duration))
	SkillSystem.notify_skill_used(self, definition.skill_id)
	skill_requested.emit(definition.animal_id)
	return true

func resolve_skill_contacts() -> int:
	var definition := _get_active_skill_definition()
	if definition == null or definition.skill_id != &"stampede" or _skill_effect_remaining <= 0.0:
		return 0
	return SkillSystem.resolve_stampede_hits(self, _stampede_hit_ids, 2.35, minf(definition.skill_push_strength, 4.5))

func set_held_item(item_id: StringName) -> void:
	_held_item = item_id
	held_item_changed.emit(item_id)

func get_held_item() -> StringName:
	return _held_item

func _apply_animal_definition() -> void:
	animal_definition = WildDashAnimalCatalog.get_definition(animal_id)
	if animal_definition == null:
		return
	chimera_loadout = null
	_skill_definition_override = null
	_reset_passive_modifiers()
	animal_id = animal_definition.animal_id
	_apply_definition_values(animal_definition)
	_apply_collision_profile()
	_install_visual()
	animal_configured.emit(animal_id)

func _apply_definition_values(definition: WildDashAnimalDefinition) -> void:
	max_speed = definition.max_speed
	cruise_speed = definition.cruise_speed
	acceleration = definition.acceleration
	turn_speed = definition.turn_speed
	jump_velocity = definition.jump_velocity
	gravity = definition.gravity
	arena_move_speed = definition.arena_move_speed
	arena_acceleration = definition.arena_acceleration
	knockback_decay = definition.knockback_decay

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
	_clear_visual_slot()
	var visual_instance := animal_definition.visual_scene.instantiate()
	if visual_instance == null:
		push_error("Failed to instantiate visual for %s" % animal_id)
		return
	visual_instance.name = "VisualModel"
	_visual_slot.add_child(visual_instance)
	_visual = visual_instance as WildDashCharacterVisual
	if _visual:
		_visual.set_lod_level(_performance_lod_level)

func _install_chimera_visual() -> void:
	if _visual_slot == null or chimera_loadout == null:
		return
	_clear_visual_slot()
	var visual_instance := CHIMERA_VISUAL_SCENE.instantiate() as WildDashChimeraVisual
	if visual_instance == null:
		push_error("Failed to instantiate chimera visual")
		return
	visual_instance.name = "VisualModel"
	visual_instance.configure_loadout(chimera_loadout)
	_visual_slot.add_child(visual_instance)
	_visual = visual_instance
	_visual.set_lod_level(_performance_lod_level)

func _clear_visual_slot() -> void:
	for child in _visual_slot.get_children():
		_visual_slot.remove_child(child)
		child.queue_free()
	_visual = null

func _apply_chimera_profiles() -> void:
	_reset_passive_modifiers()
	if chimera_loadout == null:
		return
	var body_passive := WildDashChimeraSystem.body_passive_profile(chimera_loadout.body_id)
	var tail_utility := WildDashChimeraSystem.tail_utility_profile(chimera_loadout.tail_id)
	_passive_acceleration_multiplier = float(body_passive.get("acceleration_multiplier", 1.0)) * float(tail_utility.get("acceleration_multiplier", 1.0))
	_passive_turn_multiplier = float(body_passive.get("turn_multiplier", 1.0)) * float(tail_utility.get("turn_multiplier", 1.0))
	_passive_jump_multiplier = float(tail_utility.get("jump_multiplier", 1.0))
	_passive_knockback_received_multiplier = float(body_passive.get("knockback_received_multiplier", 1.0))
	_passive_knockback_decay_multiplier = float(tail_utility.get("knockback_decay_multiplier", 1.0))
	_passive_pickup_radius_multiplier = float(tail_utility.get("pickup_radius_multiplier", 1.0))
	_collision_speed_retention = clampf(0.92 * float(body_passive.get("collision_retention_multiplier", 1.0)), 0.84, 0.98)

func _reset_passive_modifiers() -> void:
	_passive_pickup_radius_multiplier = 1.0
	_passive_acceleration_multiplier = 1.0
	_passive_turn_multiplier = 1.0
	_passive_jump_multiplier = 1.0
	_passive_knockback_received_multiplier = 1.0
	_passive_knockback_decay_multiplier = 1.0
	_collision_speed_retention = 0.92

func _get_active_skill_definition() -> WildDashAnimalDefinition:
	if _skill_definition_override != null:
		return _skill_definition_override
	if animal_definition != null:
		return animal_definition
	return WildDashAnimalCatalog.get_definition(animal_id)

func _start_skill_effect(definition: WildDashAnimalDefinition) -> void:
	_skill_effect_remaining = maxf(0.0, definition.skill_duration)
	_skill_speed_multiplier = definition.skill_speed_multiplier
	_skill_acceleration_multiplier = definition.skill_acceleration_multiplier
	_skill_turn_multiplier = definition.skill_turn_multiplier
	_skill_jump_multiplier = definition.skill_jump_multiplier
	_skill_knockback_multiplier = definition.skill_knockback_multiplier
	_skill_collision_retention_multiplier = definition.skill_collision_retention_multiplier

func _update_skill_effect(delta: float) -> void:
	_skill_impulse_velocity = _skill_impulse_velocity.move_toward(Vector3.ZERO, 25.0 * delta)
	if _collision_evade_remaining > 0.0:
		_collision_evade_remaining = maxf(0.0, _collision_evade_remaining - delta)
		if _collision_evade_remaining <= 0.0:
			_refresh_collision_mask()

	if _skill_effect_remaining <= 0.0:
		return
	_skill_effect_remaining = maxf(0.0, _skill_effect_remaining - delta)
	if _skill_effect_remaining <= 0.0:
		_skill_speed_multiplier = 1.0
		_skill_acceleration_multiplier = 1.0
		_skill_turn_multiplier = 1.0
		_skill_jump_multiplier = 1.0
		_skill_knockback_multiplier = 1.0
		_skill_collision_retention_multiplier = 1.0
		_stampede_hit_ids.clear()

func _clear_skill_runtime() -> void:
	skill_cooldown_remaining = 0.0
	_skill_effect_remaining = 0.0
	_skill_speed_multiplier = 1.0
	_skill_acceleration_multiplier = 1.0
	_skill_turn_multiplier = 1.0
	_skill_jump_multiplier = 1.0
	_skill_knockback_multiplier = 1.0
	_skill_collision_retention_multiplier = 1.0
	_skill_impulse_velocity = Vector3.ZERO
	_collision_evade_remaining = 0.0
	_stampede_hit_ids.clear()
	if is_inside_tree():
		_refresh_collision_mask()

func _refresh_collision_mask() -> void:
	# Layer 1 = track/world, layer 2 = racers. Shadow Step temporarily keeps
	# world collision while ignoring racer bodies for 0.4 seconds.
	if _collision_evade_remaining > 0.0:
		collision_mask = 1
	else:
		collision_mask = 3 if _performance_lod_level == 0 else 1

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
