class_name WildDashRoundRecapMotionPolish
extends Node

## Broadcast-style visual polish layered on the existing RoundRecap flow.
## Navigation timing, scoring and ResultManager state stay owned by round_recap.gd.

const CONFETTI_COUNT := 18

var _confetti: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _elapsed := 0.0
var _accent := Color("63e6ff")

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_rng.seed = 6021 + GameManager.current_round_index * 117
	call_deferred("_start_polish")

func _process(delta: float) -> void:
	_elapsed += delta
	for i in range(_confetti.size()):
		var piece: Dictionary = _confetti[i]
		var node: ColorRect = piece["node"]
		var velocity: Vector2 = piece["velocity"]
		velocity.y += 80.0 * delta
		node.position += velocity * delta
		node.rotation += float(piece["spin"]) * delta
		if node.position.y > 760.0:
			node.position = Vector2(_rng.randf_range(40.0, 1240.0), _rng.randf_range(-120.0, -20.0))
			velocity = Vector2(_rng.randf_range(-28.0, 28.0), _rng.randf_range(55.0, 110.0))
		piece["velocity"] = velocity
		_confetti[i] = piece

func _start_polish() -> void:
	var entry := ResultManager.get_latest_round_result()
	_accent = _accent_for_mode(StringName(entry.get("mode_id", &"unknown")))
	_animate_existing_panel()
	_build_confetti()
	_celebrate_preview_racer()
	print("GRAPHICS PHASE 3 RECAP READY panel_transition=true countup_preserved=true celebration=true confetti_pool=%d" % CONFETTI_COUNT)

func _animate_existing_panel() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var panel := parent.find_child("PanelContainer", true, false) as Control
	if panel == null:
		# Runtime-created recap panel may keep the default class name rather than an
		# authored node name. Search by type without creating replacement UI.
		for child in parent.find_children("*", "PanelContainer", true, false):
			if child is Control:
				panel = child as Control
				break
	if panel == null:
		return
	panel.modulate.a = 0.0
	panel.scale = Vector2(0.94, 0.94)
	panel.pivot_offset = panel.size * 0.5
	var tween := create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.20)
	tween.parallel().tween_property(panel, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_confetti() -> void:
	var layer := CanvasLayer.new()
	layer.name = "RecapThemeFX"
	layer.layer = 4
	add_child(layer)
	for i in range(CONFETTI_COUNT):
		var piece := ColorRect.new()
		piece.name = "Confetti_%02d" % i
		piece.mouse_filter = Control.MOUSE_FILTER_IGNORE
		piece.size = Vector2(_rng.randf_range(5.0, 10.0), _rng.randf_range(10.0, 20.0))
		piece.position = Vector2(_rng.randf_range(40.0, 1240.0), _rng.randf_range(-180.0, 620.0))
		piece.color = _accent.lightened(_rng.randf_range(0.0, 0.28)) if i % 3 != 0 else Color("ffd75d")
		piece.modulate.a = 0.62
		layer.add_child(piece)
		_confetti.append({
			"node": piece,
			"velocity": Vector2(_rng.randf_range(-24.0, 24.0), _rng.randf_range(58.0, 112.0)),
			"spin": _rng.randf_range(-2.6, 2.6),
		})

func _celebrate_preview_racer() -> void:
	var parent := get_parent()
	if parent == null:
		return
	var racer := parent.get_node_or_null("RecapRacer") as WildDashCharacterController
	if racer == null:
		return
	var visual := racer.get_visual()
	if visual != null:
		visual.play_result(true)
	var premium := racer.get_node_or_null("PremiumCharacterArt") as WildDashPremiumCharacterArt
	if premium != null:
		premium.set_expression(WildDashPremiumCharacterArt.EXPRESSION_VICTORY, 3.0)

func _accent_for_mode(mode_id: StringName) -> Color:
	match mode_id:
		&"fruit_collection": return Color("ff805f")
		&"logspire_leap": return Color("a8e873")
		&"push_out": return Color("ffad4f")
		&"neon_harbor_race": return Color("63eaff")
		_: return Color("65d2de")
