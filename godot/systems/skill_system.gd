extends Node

signal skill_used(character: Node, skill_id: StringName)
signal skill_hit(source: Node, target: Node, skill_id: StringName)

const RALLY_DASH: StringName = &"rally_dash"
const SPRING_LEAP: StringName = &"spring_leap"
const STAMPEDE: StringName = &"stampede"
const SHADOW_STEP: StringName = &"shadow_step"

const SKILL_IDS: Array[StringName] = [
	RALLY_DASH,
	SPRING_LEAP,
	STAMPEDE,
	SHADOW_STEP,
]

func is_valid_skill(skill_id: StringName) -> bool:
	return SKILL_IDS.has(skill_id)

func notify_skill_used(character: Node, skill_id: StringName) -> void:
	if character == null or not is_valid_skill(skill_id):
		return
	skill_used.emit(character, skill_id)
	print("CHARACTER SKILL USE racer=%s skill=%s" % [_label(character), String(skill_id)])

func resolve_stampede_hits(
	source: WildDashCharacterController,
	already_hit: Dictionary,
	radius := 2.35,
	push_strength := 4.2,
) -> int:
	if source == null:
		return 0
	var hits := 0
	for node in get_tree().get_nodes_in_group("wilddash_racer"):
		if not node is WildDashCharacterController:
			continue
		var target := node as WildDashCharacterController
		if target == source or not is_instance_valid(target) or target.finished:
			continue
		var target_id := target.get_instance_id()
		if already_hit.has(target_id):
			continue
		var offset := target.global_position - source.global_position
		offset.y = 0.0
		if offset.length_squared() > radius * radius or offset.length_squared() <= 0.001:
			continue
		var forward := -source.global_transform.basis.z.normalized()
		if forward.dot(offset.normalized()) < -0.15:
			continue
		already_hit[target_id] = true
		target.apply_knockback(offset.normalized(), minf(push_strength, 4.5))
		target.current_speed *= 0.90
		skill_hit.emit(source, target, STAMPEDE)
		print("STAMPEDE HIT source=%s target=%s strength=%.2f" % [_label(source), _label(target), minf(push_strength, 4.5)])
		hits += 1
	return hits

func count_nearby_racers(source: WildDashCharacterController, radius: float) -> int:
	if source == null:
		return 0
	var count := 0
	for node in get_tree().get_nodes_in_group("wilddash_racer"):
		if not node is WildDashCharacterController:
			continue
		var target := node as WildDashCharacterController
		if target == source or not is_instance_valid(target) or target.finished:
			continue
		var offset := target.global_position - source.global_position
		offset.y = 0.0
		if offset.length_squared() <= radius * radius:
			count += 1
	return count

func _label(character: Node) -> String:
	if character is WildDashCharacterController:
		return (character as WildDashCharacterController).get_display_name()
	return character.name if character != null else "Unknown"
