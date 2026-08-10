class_name WildDashAISkillBrain
extends Node

@export var racer_path: NodePath
@export var decision_interval := 0.20
@export var warmup_seconds := 1.15

var _racer: WildDashCharacterController
var _elapsed := 0.0
var _warmup_remaining := 0.0
var _last_utility := 0.0

func _ready() -> void:
	_racer = get_node_or_null(racer_path) as WildDashCharacterController
	_warmup_remaining = warmup_seconds

func _physics_process(delta: float) -> void:
	if _racer == null or _racer.finished:
		return
	_warmup_remaining = maxf(0.0, _warmup_remaining - delta)
	if _warmup_remaining > 0.0 or _racer.skill_cooldown_remaining > 0.0:
		return
	if _racer.movement_mode == WildDashCharacterController.MovementMode.RACE:
		if not RaceManager.active:
			return
	elif not GameManager.round_active:
		return
	_elapsed += delta
	if _elapsed < decision_interval:
		return
	_elapsed = 0.0
	consider_skill_use()

func consider_skill_use() -> bool:
	if _racer == null or _racer.skill_cooldown_remaining > 0.0:
		return false
	var skill_id := _racer.get_skill_id()
	var utility := _calculate_utility(skill_id)
	_last_utility = utility
	if utility < 0.72:
		return false
	var hint := _direction_hint(skill_id)
	if skill_id == &"shadow_step" and _racer.movement_mode == WildDashCharacterController.MovementMode.RACE:
		if not _shadow_step_ground_is_safe(hint):
			hint = Vector2(0.0, -1.0)
			if not _shadow_step_ground_is_safe(hint):
				_last_utility = 0.40
				return false
	if not _racer.try_use_skill(hint):
		return false
	print("AI SKILL USE racer=%s skill=%s utility=%.2f" % [_racer.get_display_name(), _racer.get_skill_name(), utility])
	return true

func get_last_utility() -> float:
	return _last_utility

func _calculate_utility(skill_id: StringName) -> float:
	var nearby := SkillSystem.count_nearby_racers(_racer, 3.4)
	var obstacle := _has_obstacle_ahead(6.5)
	var speed_ratio := 0.0 if _racer.max_speed <= 0.01 else _racer.current_speed / _racer.max_speed
	var rank := RaceManager.get_rank(_racer) if _racer.movement_mode == WildDashCharacterController.MovementMode.RACE else 1

	match skill_id:
		&"rally_dash":
			if obstacle:
				return 0.25
			if rank > 1 and speed_ratio >= 0.55:
				return 0.84
			if speed_ratio < 0.72:
				return 0.74
			return 0.58
		&"spring_leap":
			if obstacle:
				return 0.98
			if speed_ratio < 0.60:
				return 0.78
			if _racer.movement_mode == WildDashCharacterController.MovementMode.ARENA and nearby > 0:
				return 0.75
			return 0.45
		&"stampede":
			if nearby >= 2:
				return 1.0
			if nearby == 1:
				return 0.94
			return 0.46
		&"shadow_step":
			if obstacle or _racer.has_blocking_collision():
				return 0.96
			if nearby > 0:
				return 0.84
			if rank > 1 and speed_ratio < 0.76:
				return 0.75
			return 0.50
		_:
			return 0.0

func _direction_hint(skill_id: StringName) -> Vector2:
	if skill_id != &"shadow_step":
		return Vector2(0.0, -1.0)
	var sign_value := -1.0 if (_racer.get_instance_id() % 2) == 0 else 1.0
	if _racer.get_world_3d() == null:
		return Vector2(sign_value, -1.0)
	var origin := _racer.global_position + Vector3.UP * 0.8
	var forward := -_racer.global_transform.basis.z.normalized()
	var right := _racer.global_transform.basis.x.normalized()
	var space := _racer.get_world_3d().direct_space_state
	var left_query := PhysicsRayQueryParameters3D.create(origin, origin + forward * 3.0 - right * 2.5)
	left_query.exclude = [_racer.get_rid()]
	left_query.collision_mask = 1
	var right_query := PhysicsRayQueryParameters3D.create(origin, origin + forward * 3.0 + right * 2.5)
	right_query.exclude = [_racer.get_rid()]
	right_query.collision_mask = 1
	var left_blocked := not space.intersect_ray(left_query).is_empty()
	var right_blocked := not space.intersect_ray(right_query).is_empty()
	if left_blocked and not right_blocked:
		sign_value = 1.0
	elif right_blocked and not left_blocked:
		sign_value = -1.0
	return Vector2(sign_value, -1.0)

func _shadow_step_ground_is_safe(hint: Vector2) -> bool:
	if _racer == null or _racer.get_world_3d() == null:
		return false
	var forward: Vector3 = -_racer.global_transform.basis.z.normalized()
	var right: Vector3 = _racer.global_transform.basis.x.normalized()
	var lateral: float = clampf(hint.x, -1.0, 1.0)
	var offset: Vector3 = forward * 3.2 + right * lateral * 2.5
	for raw_ratio in [0.5, 1.0]:
		var ratio: float = float(raw_ratio)
		var point: Vector3 = _racer.global_position + offset * ratio
		var from: Vector3 = point + Vector3.UP * 2.8
		var to: Vector3 = point + Vector3.DOWN * 5.5
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude = [_racer.get_rid()]
		query.collision_mask = 1
		if _racer.get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true

func _has_obstacle_ahead(distance: float) -> bool:
	if _racer == null or _racer.get_world_3d() == null:
		return false
	var origin := _racer.global_position + Vector3.UP * 0.85
	var forward := -_racer.global_transform.basis.z.normalized()
	var query := PhysicsRayQueryParameters3D.create(origin, origin + forward * distance)
	query.exclude = [_racer.get_rid()]
	query.collision_mask = 1
	return not _racer.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
