extends Node3D

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const CORE_ANIMALS: Array[StringName] = [&"dog", &"rabbit", &"elephant", &"cat"]
const REQUIRED_STATES: Array[StringName] = [&"Idle", &"Run", &"Jump", &"Hit", &"Skill", &"Win", &"Lose"]
const ALLOWED_SKILLS: Array[StringName] = [&"rally_dash", &"spring_leap", &"stampede", &"shadow_step"]

func _ready() -> void:
	var failures: Array[String] = []
	var playable := WildDashAnimalCatalog.playable_ids()
	var chimera := WildDashAnimalCatalog.chimera_ids()
	var race_roster := WildDashAnimalCatalog.race_roster_ids()
	var legacy_npc := WildDashAnimalCatalog.npc_ids()
	var seen_visual_paths: Dictionary = {}
	var seen_balance_signatures: Dictionary = {}

	if playable.size() != 12:
		failures.append("Expected 12 playable animals, got %d" % playable.size())
	if chimera.size() != 4:
		failures.append("Chimera pool must remain four core animals")
	if race_roster.size() != 12:
		failures.append("Expected 12 species in race roster, got %d" % race_roster.size())
	if legacy_npc.size() != 8:
		failures.append("Expected eight legacy NPC visual species, got %d" % legacy_npc.size())

	for index in range(playable.size()):
		var animal_id: StringName = playable[index]
		var definition := WildDashAnimalCatalog.get_definition(animal_id)
		if definition == null:
			failures.append("%s: definition missing" % animal_id)
			continue
		if not ALLOWED_SKILLS.has(definition.skill_id):
			failures.append("%s: unsupported skill id %s" % [animal_id, definition.skill_id])
		if definition.role.begins_with("NPC"):
			failures.append("%s: stale NPC-only role label" % animal_id)
		if definition.max_speed < 13.0 or definition.max_speed > 15.0:
			failures.append("%s: max speed outside RC8 envelope" % animal_id)
		if definition.acceleration < 18.0 or definition.acceleration > 29.0:
			failures.append("%s: acceleration outside RC8 envelope" % animal_id)
		if definition.turn_speed < 1.60 or definition.turn_speed > 2.80:
			failures.append("%s: handling outside RC8 envelope" % animal_id)
		if definition.jump_velocity < 6.0 or definition.jump_velocity > 9.5:
			failures.append("%s: jump outside RC8 envelope" % animal_id)
		if definition.collision_radius < 0.48 or definition.collision_radius > 0.82:
			failures.append("%s: collision radius outside RC8 envelope" % animal_id)

		var visual_path := definition.visual_scene.resource_path if definition.visual_scene != null else ""
		if visual_path.is_empty():
			failures.append("%s: visual scene missing" % animal_id)
		elif seen_visual_paths.has(visual_path):
			failures.append("%s: visual scene is not unique" % animal_id)
		seen_visual_paths[visual_path] = true

		var signature := "%.2f|%.2f|%.2f|%.2f|%.2f|%s" % [
			definition.max_speed, definition.acceleration, definition.turn_speed,
			definition.jump_velocity, definition.arena_move_speed, definition.skill_name,
		]
		if seen_balance_signatures.has(signature):
			failures.append("%s: gameplay signature duplicates %s" % [animal_id, seen_balance_signatures[signature]])
		seen_balance_signatures[signature] = String(animal_id)

		var racer := RACER_SCENE.instantiate() as WildDashCharacterController
		if racer == null:
			failures.append("%s: racer scene failed" % animal_id)
			continue
		racer.is_player = false
		racer.movement_mode = WildDashCharacterController.MovementMode.ARENA
		racer.animal_id = animal_id
		racer.position = Vector3(float(index % 6) * 2.8, 0.2, float(index / 6) * 4.0)
		add_child(racer)
		await get_tree().physics_frame

		if racer.get_animal_definition() == null:
			failures.append("%s: controller definition missing" % animal_id)
		if not is_equal_approx(racer.max_speed, definition.max_speed):
			failures.append("%s: max speed mismatch" % animal_id)
		if not is_equal_approx(racer.jump_velocity, definition.jump_velocity):
			failures.append("%s: jump mismatch" % animal_id)
		var collision := racer.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var capsule := collision.shape as CapsuleShape3D if collision != null else null
		if capsule == null:
			failures.append("%s: capsule collision missing" % animal_id)
		else:
			if not is_equal_approx(capsule.radius, definition.collision_radius):
				failures.append("%s: collision radius mismatch" % animal_id)
			if not is_equal_approx(capsule.height, definition.collision_height):
				failures.append("%s: collision height mismatch" % animal_id)

		var visual := racer.get_visual()
		if visual == null:
			failures.append("%s: visual missing" % animal_id)
		elif CORE_ANIMALS.has(animal_id):
			for state: StringName in REQUIRED_STATES:
				visual.play_state(state, true)
				if visual.get_current_state() != state:
					failures.append("%s: animation state %s unavailable" % [animal_id, state])

		if not racer.try_use_skill():
			failures.append("%s: skill did not activate" % animal_id)
		elif not is_equal_approx(racer.skill_cooldown_remaining, definition.skill_cooldown):
			failures.append("%s: skill cooldown mismatch" % animal_id)

		print("RC8 CHARACTER PROFILE id=%s role=%s max=%.1f accel=%.1f handling=%.2f jump=%.1f arena=%.1f radius=%.2f skill=%s" % [
			animal_id, definition.role, definition.max_speed, definition.acceleration, definition.turn_speed,
			definition.jump_velocity, definition.arena_move_speed, definition.collision_radius, definition.skill_name,
		])

	for index in range(race_roster.size()):
		if WildDashAnimalCatalog.get_race_npc_id(index) != race_roster[index]:
			failures.append("Race roster sequence mismatch at slot %d" % index)

	if failures.is_empty():
		print("RC8 CHARACTER SYSTEM PASS playable=12 unique_profiles=12 chimera_core=4 skills=4")
		get_tree().quit(0)
		return
	for failure: String in failures:
		push_error("RC8 CHARACTER SYSTEM FAIL " + failure)
	get_tree().quit(1)
