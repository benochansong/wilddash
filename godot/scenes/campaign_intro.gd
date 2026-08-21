extends Node

## Short, self-contained campaign montage shown after Character Select and before
## Round 1. It deliberately does NOT instantiate production round scenes: those
## scenes own campaign state, checkpoints and results. This sandbox uses the real
## racer scene/animal visuals but has no collision, scoring or ResultManager writes.

const RACER_SCENE: PackedScene = preload("res://characters/test_racer.tscn")
const ROUND_SECONDS := 1.48
const FADE_SECONDS := 0.14
const RACER_COUNT := 8

const INTRO_COPY: Dictionary = {
	&"en": {
		"eyebrow": "5 ROUNDS · ONE WILD RUN",
		"skip": "SPACE / ENTER / A  ·  SKIP",
		"rounds": [
			["ROUND 1 · GRAND PRIX", "Race the pack · draft, dodge and overtake"],
			["ROUND 2 · FRUIT COLLECTION", "Scramble for fruit · steal space and score"],
			["ROUND 3 · LOGSPIRE LEAP", "Climb fast · jump, stomp and survive"],
			["ROUND 4 · WILD RUMBLE", "Fight for the arena · shove rivals away"],
			["ROUND 5 · WILD CURRENT", "Swim the final · currents, items and combat"],
		],
	},
	&"ko": {
		"eyebrow": "5개의 라운드 · 단 하나의 와일드 런",
		"skip": "SPACE / ENTER / A  ·  건너뛰기",
		"rounds": [
			["ROUND 1 · GRAND PRIX", "무리 속을 질주하고 · 드래프트와 추월로 승부"],
			["ROUND 2 · FRUIT COLLECTION", "과일을 차지하고 · 몸싸움으로 점수를 확보"],
			["ROUND 3 · LOGSPIRE LEAP", "통나무를 타고 오르며 · 점프와 밟기로 생존"],
			["ROUND 4 · WILD RUMBLE", "아레나에서 충돌하고 · 상대를 밖으로 밀어내기"],
			["ROUND 5 · WILD CURRENT", "최종 수영전 · 물살과 아이템, 공격으로 역전"],
		],
	},
	&"es": {
		"eyebrow": "5 RONDAS · UNA CARRERA SALVAJE",
		"skip": "ESPACIO / ENTER / A  ·  SALTAR",
		"rounds": [
			["RONDA 1 · GRAND PRIX", "Corre con el grupo · rebufo, esquiva y adelanta"],
			["RONDA 2 · FRUIT COLLECTION", "Lucha por la fruta · gana espacio y puntos"],
			["RONDA 3 · LOGSPIRE LEAP", "Sube rápido · salta, pisa y sobrevive"],
			["RONDA 4 · WILD RUMBLE", "Domina la arena · empuja a tus rivales"],
			["RONDA 5 · WILD CURRENT", "Nada la final · corrientes, objetos y combate"],
		],
	},
}

const PREVIEW_SPECIES: Array[StringName] = [
	&"dog", &"wolf", &"boar", &"rabbit", &"deer", &"monkey", &"elephant", &"bear",
]

var _stage: Node3D
var _camera: Camera3D
var _racers: Array[WildDashCharacterController] = []
var _racer_origins: Array[Vector3] = []
var _round_index := 0
var _round_elapsed := 0.0
var _title: Label
var _description: Label
var _progress: Label
var _fade: ColorRect
var _finished := false
var _transitioning := false
var _round5_torpedo: MeshInstance3D

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color(0.012, 0.025, 0.055))
	_build_world()
	_build_ui()
	print("CAMPAIGN INTRO READY rounds=5 seconds_per_round=%.2f sandbox=true result_writes=false" % ROUND_SECONDS)
	call_deferred("_play_montage")

func _process(delta: float) -> void:
	if _finished or _transitioning:
		return
	_round_elapsed += delta
	_animate_round(_round_index, _round_elapsed)

func _unhandled_input(event: InputEvent) -> void:
	if _finished:
		return
	if event.is_action_pressed("ui_accept"):
		_skip_intro()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_skip_intro()

func _build_world() -> void:
	_stage = Node3D.new()
	_stage.name = "SimulationStage"
	add_child(_stage)

	var sun := DirectionalLight3D.new()
	sun.name = "CinematicSun"
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)

	var fill := OmniLight3D.new()
	fill.name = "CinematicFill"
	fill.position = Vector3(-2.0, 8.0, 7.0)
	fill.light_energy = 2.3
	fill.omni_range = 28.0
	add_child(fill)

	_camera = Camera3D.new()
	_camera.name = "IntroCamera"
	_camera.current = true
	_camera.fov = 55.0
	add_child(_camera)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "IntroUI"
	layer.layer = 20
	add_child(layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(root)

	var top_shade := ColorRect.new()
	top_shade.color = Color(0.01, 0.02, 0.045, 0.78)
	top_shade.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_shade.offset_bottom = 184.0
	root.add_child(top_shade)

	var language := SettingsManager.get_language()
	var copy: Dictionary = INTRO_COPY.get(language, INTRO_COPY[&"en"])

	var eyebrow := Label.new()
	eyebrow.text = String(copy.get("eyebrow", "5 ROUNDS · ONE WILD RUN"))
	eyebrow.position = Vector2(72, 28)
	eyebrow.size = Vector2(900, 32)
	eyebrow.add_theme_font_size_override("font_size", 18)
	eyebrow.add_theme_color_override("font_color", SettingsManager.get_accent_color())
	root.add_child(eyebrow)

	_title = Label.new()
	_title.position = Vector2(68, 57)
	_title.size = Vector2(1100, 58)
	_title.add_theme_font_size_override("font_size", 38)
	root.add_child(_title)

	_description = Label.new()
	_description.position = Vector2(72, 113)
	_description.size = Vector2(1100, 36)
	_description.add_theme_font_size_override("font_size", 19)
	_description.modulate = Color(0.82, 0.88, 0.96)
	root.add_child(_description)

	_progress = Label.new()
	_progress.position = Vector2(72, 151)
	_progress.size = Vector2(520, 28)
	_progress.add_theme_font_size_override("font_size", 17)
	root.add_child(_progress)

	var skip := Label.new()
	skip.text = String(copy.get("skip", "SPACE / ENTER / A · SKIP"))
	skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.position = Vector2(-410, -62)
	skip.size = Vector2(350, 30)
	skip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip.add_theme_font_size_override("font_size", 16)
	skip.modulate = Color(0.78, 0.84, 0.92, 0.9)
	root.add_child(skip)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 1.0
	root.add_child(_fade)

func _play_montage() -> void:
	for index in range(5):
		if _finished:
			return
		_transitioning = true
		_round_index = index
		_round_elapsed = 0.0
		_setup_round(index)
		_update_copy(index)
		print("CAMPAIGN INTRO ROUND preview=%d mode=%s" % [index + 1, _round_mode_id(index)])
		await _fade_to(0.0, FADE_SECONDS)
		_transitioning = false
		await get_tree().create_timer(ROUND_SECONDS).timeout
		if _finished:
			return
		_transitioning = true
		await _fade_to(1.0, FADE_SECONDS)
	_complete_intro(false)

func _skip_intro() -> void:
	if _finished:
		return
	_finished = true
	_transitioning = true
	print("CAMPAIGN INTRO SKIP round=%d elapsed=%.2f" % [_round_index + 1, _round_elapsed])
	await _fade_to(1.0, 0.10)
	_start_real_campaign(true)

func _complete_intro(skipped: bool) -> void:
	if _finished:
		return
	_finished = true
	print("CAMPAIGN INTRO COMPLETE skipped=%s duration_target=%.2f" % [str(skipped), 5.0 * (ROUND_SECONDS + FADE_SECONDS * 2.0)])
	_start_real_campaign(skipped)

func _start_real_campaign(skipped: bool) -> void:
	print("CAMPAIGN INTRO HANDOFF round1=true skipped=%s result_writes=false" % str(skipped))
	if GameManager.has_method("continue_campaign_after_intro"):
		GameManager.continue_campaign_after_intro()
	else:
		GameManager.start_campaign()

func _fade_to(alpha: float, duration: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_fade, "modulate:a", alpha, duration)
	await tween.finished

func _update_copy(index: int) -> void:
	var language := SettingsManager.get_language()
	var copy: Dictionary = INTRO_COPY.get(language, INTRO_COPY[&"en"])
	var rounds: Array = copy.get("rounds", [])
	if index < rounds.size():
		var entry: Array = rounds[index]
		_title.text = String(entry[0])
		_description.text = String(entry[1])
	_progress.text = _progress_text(index)

func _progress_text(index: int) -> String:
	var result := ""
	for i in range(5):
		result += "●" if i == index else "○"
		if i < 4:
			result += "   "
	return result

func _setup_round(index: int) -> void:
	_clear_stage()
	match index:
		0:
			_build_grand_prix()
		1:
			_build_fruit_collection()
		2:
			_build_logspire()
		3:
			_build_rumble()
		4:
			_build_wild_current()
	_spawn_preview_racers(index)

func _clear_stage() -> void:
	_racers.clear()
	_racer_origins.clear()
	_round5_torpedo = null
	for child in _stage.get_children():
		_stage.remove_child(child)
		child.queue_free()

func _spawn_preview_racers(round_index: int) -> void:
	var species_order: Array[StringName] = []
	var selected: StringName = GameManager.selected_animal
	if WildDashAnimalCatalog.is_valid(selected):
		species_order.append(selected)
	for id in PREVIEW_SPECIES:
		if id != selected and species_order.size() < RACER_COUNT:
			species_order.append(id)

	for i in range(RACER_COUNT):
		var racer := RACER_SCENE.instantiate() as WildDashCharacterController
		if racer == null:
			continue
		racer.name = "IntroRacer_%02d" % i
		racer.is_player = false
		racer.movement_mode = WildDashCharacterController.MovementMode.ARENA
		racer.animal_id = species_order[i % species_order.size()]
		_stage.add_child(racer)
		racer.set_physics_process(false)
		racer.collision_layer = 0
		racer.collision_mask = 0
		var collision := racer.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision != null:
			collision.disabled = true
		racer.scale = Vector3.ONE * 0.78
		var origin := _initial_racer_position(round_index, i)
		racer.position = origin
		_racer_origins.append(origin)
		_racers.append(racer)

func _initial_racer_position(round_index: int, i: int) -> Vector3:
	match round_index:
		0:
			return Vector3((float(i % 4) - 1.5) * 2.1, 0.05, 7.5 + float(i / 4) * 2.2)
		1:
			var angle := TAU * float(i) / float(RACER_COUNT)
			return Vector3(cos(angle) * 7.0, 0.05, sin(angle) * 5.2)
		2:
			return Vector3((float(i % 4) - 1.5) * 1.65, 0.2 + float(i / 4) * 0.45, 3.5 + float(i % 2) * 1.2)
		3:
			var angle := TAU * float(i) / float(RACER_COUNT)
			return Vector3(cos(angle) * 5.0, 0.05, sin(angle) * 5.0)
		4:
			return Vector3((float(i % 4) - 1.5) * 2.0, -0.22, 7.0 + float(i / 4) * 2.0)
	return Vector3.ZERO

func _animate_round(index: int, t: float) -> void:
	match index:
		0:
			_animate_grand_prix(t)
		1:
			_animate_fruit_collection(t)
		2:
			_animate_logspire(t)
		3:
			_animate_rumble(t)
		4:
			_animate_wild_current(t)

func _animate_grand_prix(t: float) -> void:
	for i in range(_racers.size()):
		var racer := _racers[i]
		var speed := 15.0 + float((i * 7) % 5) * 0.65
		racer.position.z = _racer_origins[i].z - t * speed
		racer.position.x = _racer_origins[i].x + sin(t * 5.0 + float(i)) * 0.55
		racer.position.y = 0.05 + abs(sin(t * 10.0 + float(i))) * 0.10
		racer.rotation = Vector3(0.0, sin(t * 3.0 + i) * 0.08, sin(t * 8.0 + i) * 0.035)

func _animate_fruit_collection(t: float) -> void:
	for i in range(_racers.size()):
		var racer := _racers[i]
		var angle := t * (1.8 + 0.07 * i) + TAU * float(i) / float(maxi(1, _racers.size()))
		var radius := 5.0 + sin(t * 2.5 + i) * 1.4
		racer.position = Vector3(cos(angle) * radius, 0.05 + abs(sin(t * 8.0 + i)) * 0.12, sin(angle) * radius * 0.72)
		racer.rotation.y = -angle + PI * 0.5

func _animate_logspire(t: float) -> void:
	for i in range(_racers.size()):
		var racer := _racers[i]
		var phase := t * 3.0 + float(i) * 0.43
		racer.position.x = _racer_origins[i].x + sin(phase) * 1.5
		racer.position.z = 2.8 + cos(phase * 0.72 + i) * 1.3
		racer.position.y = _racer_origins[i].y + t * (6.2 + 0.18 * i) + abs(sin(phase * 2.0)) * 1.25
		racer.rotation.y = sin(phase) * 0.45

func _animate_rumble(t: float) -> void:
	for i in range(_racers.size()):
		var racer := _racers[i]
		var angle := TAU * float(i) / float(maxi(1, _racers.size())) + t * (0.85 if i % 2 == 0 else -0.92)
		var radius := 4.1 + sin(t * 4.0 + i) * 1.15
		if i == 6 and t > 0.75:
			radius += (t - 0.75) * 9.0
		racer.position = Vector3(cos(angle) * radius, 0.05, sin(angle) * radius)
		racer.rotation.y = -angle + PI * 0.5
		if i == 2 and t > 0.55 and t < 0.95:
			racer.rotation.z = sin((t - 0.55) * 8.0) * 0.28

func _animate_wild_current(t: float) -> void:
	for i in range(_racers.size()):
		var racer := _racers[i]
		var speed := 12.2 + float((i * 5) % 4) * 0.55
		racer.position.z = _racer_origins[i].z - t * speed
		racer.position.x = _racer_origins[i].x + sin(t * 3.8 + i * 0.8) * 1.05
		racer.position.y = -0.26 + sin(t * 7.0 + i) * 0.08
		racer.rotation.x = -0.16 + sin(t * 6.0 + i) * 0.035
		racer.rotation.z = sin(t * 5.5 + i) * 0.08
	if _round5_torpedo != null:
		_round5_torpedo.position = Vector3(sin(t * 2.2) * 0.7, 0.22, 6.0 - t * 24.0)

func _build_grand_prix() -> void:
	_add_box("Track", Vector3(0, -0.18, -4), Vector3(18, 0.35, 38), Color(0.12, 0.15, 0.19))
	for x in [-8.7, 8.7]:
		_add_box("Rail", Vector3(x, 0.25, -4), Vector3(0.28, 0.5, 38), Color(0.25, 0.74, 0.95))
	for z in [-3.0, -11.0, -19.0]:
		_add_box("Boost", Vector3(0, 0.02, z), Vector3(4.6, 0.05, 0.55), Color(0.95, 0.55, 0.12, 0.9), true)
	_camera.position = Vector3(0, 7.5, 16.5)
	_camera.look_at(Vector3(0, 0.7, -5.0), Vector3.UP)

func _build_fruit_collection() -> void:
	_add_cylinder("Arena", Vector3(0, -0.22, 0), 9.0, 0.4, Color(0.10, 0.20, 0.16))
	var fruit_colors := [Color(1.0, 0.25, 0.22), Color(1.0, 0.78, 0.16), Color(0.42, 0.92, 0.35), Color(0.68, 0.30, 0.95)]
	for i in range(14):
		var angle := TAU * float(i) / 14.0
		var radius := 2.2 + float(i % 3) * 1.8
		_add_sphere("Fruit_%02d" % i, Vector3(cos(angle) * radius, 0.55, sin(angle) * radius), 0.35, fruit_colors[i % fruit_colors.size()], true)
	_camera.position = Vector3(0, 13.5, 13.0)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

func _build_logspire() -> void:
	_add_cylinder("TitanTrunk", Vector3(0, 5.5, -1.5), 2.3, 11.0, Color(0.28, 0.14, 0.07))
	for i in range(9):
		var y := 0.8 + float(i) * 1.35
		var side := -1.0 if i % 2 == 0 else 1.0
		_add_box("Log_%02d" % i, Vector3(side * 2.5, y, -1.0 + sin(float(i)) * 1.8), Vector3(5.0, 0.30, 1.0), Color(0.46, 0.27, 0.10))
	_camera.position = Vector3(10.5, 8.0, 15.5)
	_camera.look_at(Vector3(0, 5.4, -1.0), Vector3.UP)

func _build_rumble() -> void:
	_add_cylinder("RumbleArena", Vector3(0, -0.28, 0), 8.4, 0.55, Color(0.30, 0.21, 0.12))
	_add_cylinder("CenterMark", Vector3(0, 0.02, 0), 2.1, 0.05, Color(0.95, 0.44, 0.12, 0.65), true)
	_camera.position = Vector3(0, 12.0, 15.0)
	_camera.look_at(Vector3.ZERO, Vector3.UP)

func _build_wild_current() -> void:
	_add_box("Water", Vector3(0, -0.48, -5), Vector3(22, 0.55, 42), Color(0.03, 0.38, 0.58, 0.82), true)
	for i in range(5):
		var x := -8.0 + float(i) * 4.0
		_add_box("Current_%02d" % i, Vector3(x, -0.14, -6), Vector3(0.45, 0.03, 26), Color(0.22, 0.82, 1.0, 0.42), true)
	for i in range(4):
		_add_box("Driftwood_%02d" % i, Vector3(-6.0 + i * 4.0, 0.18, -9.0 - i * 3.0), Vector3(3.0, 0.35, 0.45), Color(0.38, 0.22, 0.10))
	_round5_torpedo = _add_sphere("LeaderHunterPreview", Vector3(0, 0.22, 6), 0.32, Color(1.0, 0.52, 0.12), true)
	_camera.position = Vector3(0, 8.0, 16.5)
	_camera.look_at(Vector3(0, -0.2, -5.5), Vector3.UP)

func _add_box(name: String, position: Vector3, size: Vector3, color: Color, emissive := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color, emissive)
	node.mesh = mesh
	node.position = position
	_stage.add_child(node)
	return node

func _add_cylinder(name: String, position: Vector3, radius: float, height: float, color: Color, emissive := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	mesh.material = _material(color, emissive)
	node.mesh = mesh
	node.position = position
	_stage.add_child(node)
	return node

func _add_sphere(name: String, position: Vector3, radius: float, color: Color, emissive := false) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 20
	mesh.rings = 10
	mesh.material = _material(color, emissive)
	node.mesh = mesh
	node.position = position
	_stage.add_child(node)
	return node

func _material(color: Color, emissive: bool) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.62
	if color.a < 0.99:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if emissive:
		material.emission_enabled = true
		material.emission = Color(color.r, color.g, color.b)
		material.emission_energy_multiplier = 1.35
	return material

func _round_mode_id(index: int) -> String:
	match index:
		0: return "grand_prix"
		1: return "fruit_collection"
		2: return "logspire_leap"
		3: return "push_out"
		4: return "wild_current"
	return "unknown"
