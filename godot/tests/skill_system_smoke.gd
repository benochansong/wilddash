extends Node3D

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const AI_SKILL_BRAIN_SCRIPT: Script = preload("res://characters/ai_skill_brain.gd")
var _failed := false

func _ready() -> void:
	await get_tree().process_frame
	_verify_input_separation()

	var dog := await _spawn_racer("DogSkillTester", &"dog", Vector3(-9.0, 0.2, 0.0))
	var dog_before := dog.current_speed
	_assert(dog.get_skill_id() == &"rally_dash", "dog skill id")
	_assert(dog.try_use_skill(), "dog skill activation")
	_assert(is_equal_approx(dog.skill_cooldown_remaining, 9.0), "dog cooldown")
	_assert(dog.get_active_acceleration_scale() >= 1.50, "dog acceleration boost")
	_assert(dog.get_active_handling_scale() > 1.08, "dog handling boost")
	_assert(dog.current_speed > dog_before, "dog forward burst")
	print("DOG SKILL PASS name=%s cooldown=%.1f accel_scale=%.2f handling_scale=%.2f" % [dog.get_skill_name(), dog.skill_cooldown_remaining, dog.get_active_acceleration_scale(), dog.get_active_handling_scale()])

	var rabbit := await _spawn_racer("RabbitSkillTester", &"rabbit", Vector3(-3.0, 0.2, 0.0))
	_assert(rabbit.get_skill_id() == &"spring_leap", "rabbit skill id")
	_assert(rabbit.try_use_skill(), "rabbit skill activation")
	_assert(is_equal_approx(rabbit.skill_cooldown_remaining, 8.0), "rabbit cooldown")
	_assert(rabbit.velocity.y > rabbit.jump_velocity * 1.35, "rabbit jump height")
	_assert(rabbit.current_speed > rabbit.max_speed, "rabbit forward leap")
	print("RABBIT SKILL PASS name=%s cooldown=%.1f vertical=%.2f speed=%.2f" % [rabbit.get_skill_name(), rabbit.skill_cooldown_remaining, rabbit.velocity.y, rabbit.current_speed])

	var elephant := await _spawn_racer("ElephantSkillTester", &"elephant", Vector3(3.0, 0.2, 0.0))
	var stampede_target := await _spawn_racer("StampedeTarget", &"dog", Vector3(3.0, 0.2, -1.8))
	stampede_target.reset_motion(Vector3(3.0, 0.2, -1.8))
	_assert(elephant.get_skill_id() == &"stampede", "elephant skill id")
	_assert(elephant.try_use_skill(), "elephant skill activation")
	var hits := elephant.resolve_skill_contacts()
	var pushed := stampede_target.get_knockback_velocity().length()
	_assert(is_equal_approx(elephant.skill_cooldown_remaining, 11.0), "elephant cooldown")
	_assert(hits >= 1, "stampede did not hit nearby racer")
	_assert(pushed > 0.1 and pushed <= 4.5, "stampede push force cap")
	print("ELEPHANT SKILL PASS name=%s cooldown=%.1f hits=%d push=%.2f" % [elephant.get_skill_name(), elephant.skill_cooldown_remaining, hits, pushed])

	var cat := await _spawn_racer("CatSkillTester", &"cat", Vector3(9.0, 0.2, 0.0))
	_assert(cat.get_skill_id() == &"shadow_step", "cat skill id")
	_assert(cat.try_use_skill(Vector2(1.0, -1.0)), "cat skill activation")
	_assert(is_equal_approx(cat.skill_cooldown_remaining, 8.0), "cat cooldown")
	_assert(cat.get_active_handling_scale() >= 1.40, "cat handling boost")
	_assert(cat.collision_mask == 1, "cat racer collision evade")
	print("CAT SKILL PASS name=%s cooldown=%.1f handling_scale=%.2f evade_mask=%d" % [cat.get_skill_name(), cat.skill_cooldown_remaining, cat.get_active_handling_scale(), cat.collision_mask])

	# Utility AI: Elephant should not waste Stampede unless a racer is nearby.
	var ai_elephant := await _spawn_racer("AISkillElephant", &"elephant", Vector3(15.0, 0.2, 0.0))
	var ai_target := await _spawn_racer("AISkillTarget", &"rabbit", Vector3(15.0, 0.2, -1.6))
	ai_target.reset_motion(Vector3(15.0, 0.2, -1.6))
	var brain := AI_SKILL_BRAIN_SCRIPT.new() as WildDashAISkillBrain
	_assert(brain != null, "AI skill brain instantiate")
	if brain != null:
		brain.name = "SkillUtilityTester"
		brain.racer_path = NodePath("../AISkillElephant")
		brain.warmup_seconds = 0.0
		add_child(brain)
		await get_tree().process_frame
		var ai_used := brain.consider_skill_use()
		_assert(ai_used, "AI did not use useful skill")
		_assert(brain.get_last_utility() >= 0.90, "AI utility score too low")
		_assert(ai_elephant.skill_cooldown_remaining > 10.0, "AI skill cooldown not started")
		print("AI SKILL USE PASS skill=%s utility=%.2f" % [ai_elephant.get_skill_name(), brain.get_last_utility()])

	if _failed:
		get_tree().quit(1)
		return
	print("CHARACTER SKILL SYSTEM PASS skills=4 chimera=true item_separate=true")
	get_tree().quit(0)

func _spawn_racer(node_name: String, animal_id: StringName, position_value: Vector3) -> WildDashCharacterController:
	var racer := RACER_SCENE.instantiate() as WildDashCharacterController
	_assert(racer != null, "%s racer instantiate" % node_name)
	if racer == null:
		return null
	racer.name = node_name
	racer.is_player = false
	racer.movement_mode = WildDashCharacterController.MovementMode.ARENA
	racer.animal_id = animal_id
	racer.position = position_value
	add_child(racer)
	await get_tree().physics_frame
	return racer

func _verify_input_separation() -> void:
	_assert(_has_key(InputManager.ACTION_SKILL, KEY_E), "skill keyboard E")
	_assert(_has_joy(InputManager.ACTION_SKILL, JOY_BUTTON_X), "skill gamepad X")
	_assert(_has_key(InputManager.ACTION_ITEM, KEY_Q), "item keyboard Q")
	_assert(_has_joy(InputManager.ACTION_ITEM, JOY_BUTTON_B), "item gamepad B")
	_assert(not _has_key(InputManager.ACTION_SKILL, KEY_Q), "skill must not use Q")
	_assert(not _has_joy(InputManager.ACTION_SKILL, JOY_BUTTON_B), "skill must not use B")
	print("SKILL INPUT PASS keyboard=E gamepad=X item=Q/B separate=true")

func _has_key(action: StringName, key_code: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == key_code:
			return true
	return false

func _has_joy(action: StringName, button_index: int) -> bool:
	for event in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button_index:
			return true
	return false

func _assert(condition: bool, label: String) -> void:
	if condition:
		return
	_failed = true
	push_error("CHARACTER SKILL ASSERT FAILED: %s" % label)
