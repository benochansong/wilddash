extends "res://modes/fruit_collection/fruit_frenzy_v5_specials.gd"

## Round 2 V6: lightweight vertical-route execution for AI.
## Target selection already filters by access stats; this layer supplies the
## prototype jump/climb impulse needed to actually reach those chosen fruits.

var _ai_vertical_assist_cooldown: Dictionary = {}

func _ready() -> void:
	await super()
	for racer: WildDashCharacterController in ai_racers:
		if racer != null:
			_ai_vertical_assist_cooldown[racer.get_instance_id()] = 0.0
	print("FRUIT FRENZY V6 AI VERTICAL READY tree_climber=monkey/cat/raccoon high_jump=rabbit/deer/fox access_filter=true")

func _physics_process(delta: float) -> void:
	super(delta)
	if mode_finished or not GameManager.round_active:
		return
	for racer: WildDashCharacterController in ai_racers:
		if racer == null or racer.finished:
			continue
		var id := racer.get_instance_id()
		_ai_vertical_assist_cooldown[id] = maxf(0.0, float(_ai_vertical_assist_cooldown.get(id, 0.0)) - delta)
		if float(_ai_vertical_assist_cooldown[id]) <= 0.0:
			_try_ai_vertical_assist(racer)

func _try_ai_vertical_assist(racer: WildDashCharacterController) -> void:
	var climb := WildDashAnimalAbilityProfile.get_stat(racer.animal_id, &"climb")
	var agility := WildDashAnimalAbilityProfile.get_stat(racer.animal_id, &"agility")
	if climb < 6.5 and agility < 8.5:
		return

	var best_index := -1
	var best_horizontal := INF
	for i in range(fruits.size()):
		if not fruit_active[i]:
			continue
		var fruit := fruits[i]
		var access_type := WildDashFruitAccessSystem.get_access_type(fruit)
		if access_type == WildDashFruitAccessSystem.FruitAccessType.GROUND:
			continue
		if not WildDashFruitAccessSystem.can_racer_reach_fruit(racer, fruit):
			continue
		var vertical := fruit.global_position.y - racer.global_position.y
		if vertical < 0.65 or vertical > 5.6:
			continue
		var horizontal := Vector2(
			fruit.global_position.x - racer.global_position.x,
			fruit.global_position.z - racer.global_position.z
		).length()
		if horizontal <= 2.5 and horizontal < best_horizontal:
			best_horizontal = horizontal
			best_index = i

	if best_index < 0:
		return
	var target := fruits[best_index]
	var access_type := WildDashFruitAccessSystem.get_access_type(target)
	var impulse := 4.2 + clampf((agility - 7.0) * 0.30, 0.0, 1.0)
	if access_type == WildDashFruitAccessSystem.FruitAccessType.TREE:
		impulse += clampf((climb - 7.0) * 0.45, 0.0, 1.45)
	if racer.animal_id == &"monkey":
		impulse += 0.85
	racer.velocity.y = maxf(racer.velocity.y, impulse)
	_ai_vertical_assist_cooldown[racer.get_instance_id()] = 0.34
