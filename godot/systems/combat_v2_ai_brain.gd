class_name WildDashCombatV2AIBrain
extends RefCounted

## Shared deterministic target scoring for Round 2/4 Combat V2. Lower score is
## better. Mode scripts still own navigation and combat authority; this helper
## only expresses species intent so anti-dogpile and existing AI state machines
## can stay intact.

static func target_score(
	source: WildDashCharacterController,
	target: WildDashCharacterController,
	mode_id: StringName,
	target_carry: int,
	target_stagger: float,
	edge_ratio: float,
	objective_carrier: bool,
	terrain_advantage: float,
	direct_chasers: int
) -> float:
	if source == null or target == null:
		return INF
	var distance: float = source.global_position.distance_to(target.global_position)
	var score: float = distance * distance + float(direct_chasers) * 18.0
	var animal_id: StringName = source.animal_id

	if mode_id == &"fruit_collection":
		score -= float(target_carry) * _fruit_hunt_weight(animal_id)
		if animal_id == &"crocodile":
			score -= terrain_advantage * 34.0
		if animal_id == &"raccoon" and target_carry > 0:
			score -= 28.0
		if animal_id == &"wolf" and target_carry >= 3:
			score -= 20.0
	else:
		score -= target_stagger * _stagger_hunt_weight(animal_id)
		score -= edge_ratio * _edge_hunt_weight(animal_id)
		if objective_carrier:
			score -= 46.0
		if animal_id == &"wolf" and target_stagger >= 55.0:
			score -= 28.0
		if animal_id == &"elephant" and edge_ratio >= 0.72:
			score -= 24.0

	if animal_id in [&"cat", &"wolf", &"fox", &"raccoon"] and is_behind_target(source, target):
		score -= 18.0 if animal_id != &"cat" else 34.0
	return score

static func preferred_attack_kind(
	animal_id: StringName,
	target_stagger: float,
	distance: float,
	is_behind: bool,
	phase_tick: int
) -> StringName:
	match animal_id:
		&"boar":
			return &"hold" if distance >= 2.4 or target_stagger >= 44.0 else &"tap"
		&"elephant":
			return &"hold" if target_stagger >= 46.0 or phase_tick % 3 == 0 else &"tap"
		&"bear":
			return &"hold" if distance <= 3.8 and (target_stagger >= 35.0 or phase_tick % 2 == 0) else &"tap"
		&"wolf":
			return &"hold" if is_behind or target_stagger >= 58.0 else &"tap"
		&"raccoon":
			return &"hold" if is_behind else &"tap"
		&"crocodile":
			return &"hold" if distance <= 3.9 and (target_stagger >= 42.0 or phase_tick % 3 == 0) else &"tap"
		&"dog":
			return &"hold" if target_stagger >= 70.0 else &"tap"
		&"deer", &"fox":
			return &"hold" if distance >= 2.6 and phase_tick % 4 == 0 else &"tap"
		_:
			return &"tap"

static func is_behind_target(source: WildDashCharacterController, target: WildDashCharacterController) -> bool:
	if source == null or target == null:
		return false
	var target_forward: Vector3 = -target.global_transform.basis.z
	target_forward.y = 0.0
	if target_forward.length_squared() <= 0.001:
		return false
	target_forward = target_forward.normalized()
	var target_to_source: Vector3 = source.global_position - target.global_position
	target_to_source.y = 0.0
	if target_to_source.length_squared() <= 0.001:
		return false
	return target_forward.dot(target_to_source.normalized()) <= -0.34

static func get_role(animal_id: StringName) -> StringName:
	match animal_id:
		&"elephant": return &"push_king"
		&"bear": return &"brawler"
		&"boar": return &"charger"
		&"wolf": return &"hunter"
		&"rabbit": return &"aerial"
		&"deer": return &"leap"
		&"monkey": return &"canopy"
		&"cat": return &"ambush"
		&"fox": return &"hit_run"
		&"raccoon": return &"control"
		&"crocodile": return &"water"
		_: return &"balanced"

static func _fruit_hunt_weight(animal_id: StringName) -> float:
	match animal_id:
		&"raccoon": return 13.5
		&"wolf": return 11.0
		&"cat", &"fox": return 8.5
		&"boar", &"bear": return 7.5
		_: return 6.0

static func _stagger_hunt_weight(animal_id: StringName) -> float:
	match animal_id:
		&"wolf": return 0.72
		&"boar": return 0.52
		&"elephant", &"bear": return 0.46
		&"cat": return 0.40
		_: return 0.28

static func _edge_hunt_weight(animal_id: StringName) -> float:
	match animal_id:
		&"elephant": return 54.0
		&"boar": return 46.0
		&"wolf": return 38.0
		&"bear": return 30.0
		_: return 20.0
