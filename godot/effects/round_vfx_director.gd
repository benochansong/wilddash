class_name WildDashRoundVFXDirector
extends Node3D

## Graphics Phase 3 round-level presentation. Visual-only and non-blocking.
## It reuses a fixed mesh pool, adds no collision, and never delays gameplay input.

@export_enum("grand_prix", "fruit_frenzy", "logspire", "wild_rumble", "neon_harbor") var round_profile: String = "grand_prix"

const WORLD_POOL_SIZE := 12
const START_PRESENTATION_SECONDS := 1.45
const FINALE_SECONDS := 2.6

var _pool: Array[Dictionary] = []
var _cursor := 0
var _start_elapsed := 0.0
var _start_layer: CanvasLayer
var _start_panel: Panel
var _round_label: Label
var _theme_label: Label
var _racer_label: Label
var _finale_remaining := 0.0
var _finale_tick := 0.0
var _finale_origin := Vector3.ZERO
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("wilddash_round_vfx")
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_rng.seed = 9151 + round_profile.hash()
	_build_world_pool()
	_build_start_overlay()
	print("GRAPHICS PHASE 3 ROUND VFX READY profile=%s pooled=%d start_non_blocking=true collision_added=false" % [round_profile, WORLD_POOL_SIZE])

func _process(delta: float) -> void:
	_update_pool(delta)
	_update_start_presentation(delta)
	_update_finale(delta)

func accent_action(kind: StringName, world_position: Vector3, strength: float) -> void:
	if strength < 0.20:
		return
	# Tiny footsteps remain racer-local. Round-global accents are reserved for
	# readable action beats so 15 to 18 racers do not fill the screen with noise.
	if kind in [&"foot", &"wake"]:
		return
	var color := _profile_color(kind)
	var amount := strength * _kind_scale(kind)
	if amount < 0.24:
		return
	_emit_world(kind, world_position, color, amount)

func notify_player_finish(racer: Node3D, rank: int) -> void:
	if racer == null:
		return
	_finale_origin = racer.global_position
	_emit_world(&"finish", _finale_origin + Vector3.UP * 1.2, _profile_color(&"finish"), 1.35)
	if round_profile == "neon_harbor":
		_finale_remaining = FINALE_SECONDS
		_finale_tick = 0.0
		_show_finale_banner(rank)
	else:
		_spawn_confetti_burst(_finale_origin + Vector3.UP * 2.2, 0.85)

func _build_world_pool() -> void:
	for i in range(WORLD_POOL_SIZE):
		var root := Node3D.new()
		root.name = "RoundVFXPool_%02d" % i
		add_child(root)
		var mesh_node := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.34
		mesh.outer_radius = 0.50
		mesh.rings = 10
		mesh.ring_segments = 8
		mesh_node.mesh = mesh
		mesh_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1, 1, 1, 0)
		mesh_node.material_override = mat
		root.add_child(mesh_node)
		root.visible = false
		_pool.append({"root": root, "mat": mat, "time": 0.0, "life": 0.34, "strength": 0.0, "kind": &""})

func _emit_world(kind: StringName, position: Vector3, color: Color, strength: float) -> void:
	if _pool.is_empty():
		return
	var index := _cursor
	_cursor = (_cursor + 1) % _pool.size()
	var slot: Dictionary = _pool[index]
	var root: Node3D = slot["root"]
	var mat: StandardMaterial3D = slot["mat"]
	root.global_position = position
	root.scale = Vector3.ONE * clampf(strength, 0.20, 1.60)
	root.visible = true
	mat.albedo_color = Color(color.r, color.g, color.b, 0.58)
	mat.emission_enabled = kind in [&"item", &"boost", &"spark", &"finish", &"firework"] or round_profile == "neon_harbor"
	if mat.emission_enabled:
		mat.emission = Color(color.r, color.g, color.b) * 1.25
	slot["time"] = 0.0
	slot["life"] = 0.46 if kind in [&"finish", &"firework"] else 0.30
	slot["strength"] = strength
	slot["kind"] = kind
	_pool[index] = slot

func _update_pool(delta: float) -> void:
	for i in range(_pool.size()):
		var slot: Dictionary = _pool[i]
		var root: Node3D = slot["root"]
		if not root.visible:
			continue
		var time := float(slot["time"]) + delta
		var life := maxf(0.01, float(slot["life"]))
		var t := clampf(time / life, 0.0, 1.0)
		var strength := float(slot["strength"])
		root.scale = Vector3(1.0 + t * 3.4, 0.42 + t * 0.55, 1.0 + t * 3.4) * maxf(0.2, strength)
		root.position.y += delta * (0.45 if round_profile in ["fruit_frenzy", "logspire", "neon_harbor"] else 0.12)
		var mat: StandardMaterial3D = slot["mat"]
		var c := mat.albedo_color
		c.a = (1.0 - t) * 0.58
		mat.albedo_color = c
		if t >= 1.0:
			root.visible = false
		slot["time"] = time
		_pool[i] = slot

func _build_start_overlay() -> void:
	_start_layer = CanvasLayer.new()
	_start_layer.name = "RoundStartPresentation"
	_start_layer.layer = 18
	add_child(_start_layer)
	_start_panel = Panel.new()
	_start_panel.position = Vector2(42, 210)
	_start_panel.size = Vector2(600, 188)
	_start_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.045, 0.075, 0.82)
	style.border_color = _profile_color(&"finish")
	style.set_border_width_all(3)
	style.set_corner_radius_all(24)
	style.shadow_color = Color(0, 0, 0, 0.30)
	style.shadow_size = 10
	_start_panel.add_theme_stylebox_override("panel", style)
	_start_layer.add_child(_start_panel)
	_round_label = Label.new()
	_round_label.position = Vector2(28, 24)
	_round_label.size = Vector2(540, 52)
	_round_label.text = _round_title()
	_round_label.add_theme_font_size_override("font_size", 34)
	_round_label.add_theme_color_override("font_color", Color(0.98, 0.98, 1.0))
	_start_panel.add_child(_round_label)
	_theme_label = Label.new()
	_theme_label.position = Vector2(30, 78)
	_theme_label.size = Vector2(530, 34)
	_theme_label.text = _theme_line()
	_theme_label.add_theme_font_size_override("font_size", 18)
	_theme_label.add_theme_color_override("font_color", _profile_color(&"finish"))
	_start_panel.add_child(_theme_label)
	_racer_label = Label.new()
	_racer_label.position = Vector2(30, 123)
	_racer_label.size = Vector2(530, 30)
	_racer_label.text = "WILD DASH · GET READY"
	_racer_label.add_theme_font_size_override("font_size", 17)
	_racer_label.add_theme_color_override("font_color", Color(0.82, 0.89, 0.96))
	_start_panel.add_child(_racer_label)
	_start_panel.modulate.a = 0.0

func _update_start_presentation(delta: float) -> void:
	if _start_panel == null or _start_elapsed >= START_PRESENTATION_SECONDS:
		return
	_start_elapsed += delta
	var t := clampf(_start_elapsed / START_PRESENTATION_SECONDS, 0.0, 1.0)
	var alpha := smoothstep(0.0, 0.15, t) * (1.0 - smoothstep(0.72, 1.0, t))
	_start_panel.modulate.a = alpha
	_start_panel.position.x = lerpf(12.0, 42.0, smoothstep(0.0, 0.30, t))
	if t > 0.12 and _racer_label.text == "WILD DASH · GET READY":
		var player := _find_player()
		if player != null:
			_racer_label.text = "%s · 3  2  1  GO!" % player.get_display_name().to_upper()
	if t >= 1.0:
		_start_panel.visible = false

func _update_finale(delta: float) -> void:
	if _finale_remaining <= 0.0:
		return
	_finale_remaining = maxf(0.0, _finale_remaining - delta)
	_finale_tick -= delta
	if _finale_tick <= 0.0:
		_finale_tick = 0.16
		var offset := Vector3(_rng.randf_range(-9.0, 9.0), _rng.randf_range(4.0, 11.0), _rng.randf_range(-5.0, 5.0))
		_emit_world(&"firework", _finale_origin + offset, Color.from_hsv(_rng.randf(), 0.62, 1.0), 0.75)
		if int(_finale_remaining * 10.0) % 4 == 0:
			_spawn_confetti_burst(_finale_origin + Vector3.UP * 3.0, 0.65)

func _spawn_confetti_burst(position: Vector3, strength: float) -> void:
	for i in range(3):
		var offset := Vector3(float(i - 1) * 1.4, float(i % 2) * 0.7, float(i - 1) * 0.5)
		_emit_world(&"confetti", position + offset, _profile_color(&"item"), strength * (0.78 + float(i) * 0.08))

func _show_finale_banner(rank: int) -> void:
	if _start_layer == null:
		return
	var label := Label.new()
	label.name = "FinaleWinnerPresentation"
	label.position = Vector2(0, 92)
	label.size = Vector2(1280, 90)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = "FINAL FESTIVAL · %s" % _ordinal(rank)
	label.add_theme_font_size_override("font_size", 42)
	label.add_theme_color_override("font_color", Color("7df5ff"))
	_start_layer.add_child(label)
	var tween := create_tween()
	label.scale = Vector2(0.84, 0.84)
	label.pivot_offset = label.size * 0.5
	tween.tween_property(label, "scale", Vector2.ONE, 0.20).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(1.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(label.queue_free)

func _kind_scale(kind: StringName) -> float:
	match kind:
		&"impact", &"finish": return 1.12
		&"boost", &"item": return 0.90
		&"landing": return 0.72
		&"splash", &"recovery": return 0.78
		_: return 0.52

func _profile_color(kind: StringName) -> Color:
	match round_profile:
		"fruit_frenzy":
			if kind == &"item": return Color("ffd54f")
			return Color("ff6f61") if kind in [&"impact", &"landing"] else Color("79d96b")
		"logspire":
			if kind in [&"splash", &"wake"]: return Color("70dfff")
			return Color("c8ef83") if kind in [&"jump", &"landing", &"recovery"] else Color("8fe5b0")
		"wild_rumble":
			return Color("ff9a45") if kind in [&"impact", &"landing"] else Color("ffd466")
		"neon_harbor":
			return Color("65efff") if kind in [&"boost", &"finish", &"firework"] else Color("f05cff")
		_:
			if kind in [&"splash", &"wake"]: return Color("6edcff")
			return Color("f5b65b") if kind in [&"landing", &"impact"] else Color("9bd66f")

func _round_title() -> String:
	match round_profile:
		"fruit_frenzy": return "FRUIT FRENZY"
		"logspire": return "LOGSPIRE LEAP"
		"wild_rumble": return "WILD RUMBLE"
		"neon_harbor": return "NEON HARBOR"
		_: return "WILD WORLD GRAND PRIX"

func _theme_line() -> String:
	match round_profile:
		"fruit_frenzy": return "JUICY TROPICAL FESTIVAL · GOLDEN FRUIT AHEAD"
		"logspire": return "MAGICAL GIANT FOREST · TITAN ROOTS AHEAD"
		"wild_rumble": return "ANIMAL TITAN ARENA · CHAMPION GATE"
		"neon_harbor": return "NEON NIGHT FESTIVAL · FINAL FESTIVAL"
		_: return "SUNNY SAFARI ADVENTURE · SUNSTONE ARCH"

func _find_player() -> WildDashCharacterController:
	for node in get_tree().get_nodes_in_group("wilddash_racer"):
		if node is WildDashCharacterController and (node as WildDashCharacterController).is_player:
			return node as WildDashCharacterController
	return null

func _ordinal(rank: int) -> String:
	if rank <= 0:
		return "FINISH!"
	var suffix := "TH"
	if rank % 100 < 11 or rank % 100 > 13:
		match rank % 10:
			1: suffix = "ST"
			2: suffix = "ND"
			3: suffix = "RD"
	return "%d%s!" % [rank, suffix]
