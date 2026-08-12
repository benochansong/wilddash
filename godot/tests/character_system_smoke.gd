extends Node3D

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const REQUIRED_STATES: Array[StringName] = [
	&"Idle", &"Run", &"Jump", &"Hit", &"Skill", &"Win", &"Lose",
]

func _ready() -> void:
	var failures: Array[String] = []
	var seen_visual_paths: Dictionary = {}
	var seen_skill_ids: Dictionary = {}

	if WildDashAnimalCatalog.all_ids().size() != 4 or WildDashAnimalCatalog.playable_ids().size() != 4:
		failures.append("Playable roster must remain exactly four animals")

	for index in range(WildDashAnimalCatalog.all_ids().size()):
		var animal_id: StringName = WildDashAnimalCatalog.all_ids()[index]
		var definition := WildDashAnimalCatalog.get_definition(animal_id)
		if definition == null:
			failures.append("%s: definition missing" % animal_id)
			continue

		var racer := RACER_SCENE.instantiate() as WildDashCharacterController
		if racer == null:
			failures.append("%s: racer scene failed" % animal_id)
			continue
		racer.is_player = false
		racer.movement_mode = WildDashCharacterController.MovementMode.ARENA
		racer.animal_id = animal_id
		racer.position = Vector3(float(index) * 3.0, 0.2, 0.0)
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
			failures.append("%s: VisualModel missing" % animal_id)
		else:
			if visual.find_child("Skeleton3D", true, false) == null:
				failures.append("%s: Skeleton3D missing" % animal_id)
			if visual.find_child("AnimationPlayer", true, false) == null:
				failures.append("%s: AnimationPlayer missing" % animal_id)
			for state: StringName in REQUIRED_STATES:
				visual.play_state(state, true)
				if visual.get_current_state() != state:
					failures.append("%s: animation state %s unavailable" % [animal_id, state])

		var visual_path := definition.visual_scene.resource_path
		if seen_visual_paths.has(visual_path):
			failures.append("%s: visual scene is not unique" % animal_id)
		seen_visual_paths[visual_path] = true
		if seen_skill_ids.has(definition.skill_id):
			failures.append("%s: skill id is not unique" % animal_id)
		seen_skill_ids[definition.skill_id] = true

		if not racer.try_use_skill():
			failures.append("%s: skill did not activate" % animal_id)
		elif not is_equal_approx(racer.skill_cooldown_remaining, definition.skill_cooldown):
			failures.append("%s: skill cooldown mismatch" % animal_id)

		var camera_profile := racer.get_camera_profile()
		if not camera_profile.has("follow_distance") or not camera_profile.has("fov"):
			failures.append("%s: camera profile incomplete" % animal_id)

		print("CHARACTER PROFILE id=%s role=%s max=%.1f jump=%.1f radius=%.2f skill=%s cooldown=%.1f" % [
			animal_id, definition.role, definition.max_speed, definition.jump_velocity,
			definition.collision_radius, definition.skill_name, definition.skill_cooldown,
		])

	var npc_ids := WildDashAnimalCatalog.npc_ids()
	var race_roster := WildDashAnimalCatalog.race_roster_ids()
	if npc_ids.size() != 8:
		failures.append("Expected 8 NPC-only animal species, got %d" % npc_ids.size())
	if race_roster.size() != 12:
		failures.append("Expected 12 species in race roster, got %d" % race_roster.size())
	var npc_visual_paths: Dictionary = {}
	var allowed_skills: Array[StringName] = [&"rally_dash", &"spring_leap", &"stampede", &"shadow_step"]
	for index in range(npc_ids.size()):
		var npc_id: StringName = npc_ids[index]
		if WildDashAnimalCatalog.is_playable(npc_id):
			failures.append("%s: NPC leaked into playable roster" % npc_id)
		var definition := WildDashAnimalCatalog.get_definition(npc_id)
		if definition == null or definition.visual_scene == null:
			failures.append("%s: NPC definition/visual missing" % npc_id)
			continue
		if not allowed_skills.has(definition.skill_id):
			failures.append("%s: NPC does not reuse a safe gameplay archetype" % npc_id)
		var visual_path := definition.visual_scene.resource_path
		if npc_visual_paths.has(visual_path):
			failures.append("%s: NPC visual scene is not unique" % npc_id)
		npc_visual_paths[visual_path] = true

		var racer := RACER_SCENE.instantiate() as WildDashCharacterController
		racer.is_player = false
		racer.movement_mode = WildDashCharacterController.MovementMode.ARENA
		racer.animal_id = npc_id
		racer.position = Vector3(float(index) * 2.4, 0.2, 5.0)
		add_child(racer)
		await get_tree().physics_frame
		var visual := racer.get_visual() as WildDashNPCAnimalVisual
		if visual == null:
			failures.append("%s: shared NPC procedural visual missing" % npc_id)
		else:
			if visual.species != npc_id:
				failures.append("%s: visual species mismatch (%s)" % [npc_id, visual.species])
			if visual.find_child("Head", true, false) == null or visual.find_child("Body", true, false) == null:
				failures.append("%s: silhouette body/head missing" % npc_id)
			if visual.find_child("Eye-1.0", true, false) == null and visual.find_child("Eye1.0", true, false) == null:
				# Node names depend on float string formatting; require at least one eye by wildcard.
				if visual.find_child("Eye*", true, false) == null:
					failures.append("%s: face detail missing" % npc_id)
			visual.set_lod_level(2)

	for index in range(mini(12, race_roster.size())):
		if WildDashAnimalCatalog.get_race_npc_id(index) != race_roster[index]:
			failures.append("Race roster sequence mismatch at slot %d" % index)

	if failures.is_empty():
		print("CHARACTER SYSTEM PASS animals=4 states=7")
		print("NPC ROSTER VARIETY PASS npc=8 race_roster=12 playable=4 archetypes_reused=4")
		get_tree().quit(0)
		return

	for failure: String in failures:
		push_error("CHARACTER SYSTEM FAIL " + failure)
	get_tree().quit(1)
