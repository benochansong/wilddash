class_name WildDashSpeedLinesOverlay
extends Control

const STREAK_ANCHORS: Array[Vector2] = [
	Vector2(0.04, 0.18), Vector2(0.02, 0.32), Vector2(0.03, 0.48), Vector2(0.05, 0.67), Vector2(0.08, 0.82),
	Vector2(0.96, 0.18), Vector2(0.98, 0.32), Vector2(0.97, 0.48), Vector2(0.95, 0.67), Vector2(0.92, 0.82),
	Vector2(0.20, 0.04), Vector2(0.80, 0.04),
]

var effect_strength := 0.0
var boost_active := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	queue_redraw()

func set_effect_strength(value: float, boosted: bool) -> void:
	var next_strength := clampf(value, 0.0, 1.0)
	if is_equal_approx(next_strength, effect_strength) and boosted == boost_active:
		return
	effect_strength = next_strength
	boost_active = boosted
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	if effect_strength <= 0.015 or size.x <= 1.0 or size.y <= 1.0:
		return
	var center := size * 0.5
	var length := lerpf(22.0, 94.0, effect_strength)
	if boost_active:
		length *= 1.18
	var width := lerpf(1.0, 2.4, effect_strength)
	var alpha := lerpf(0.04, 0.27, effect_strength)
	if boost_active:
		alpha = minf(0.36, alpha + 0.07)
	var tint := Color(0.72, 0.92, 1.0, alpha)
	for index in range(STREAK_ANCHORS.size()):
		var anchor := STREAK_ANCHORS[index]
		var start := Vector2(anchor.x * size.x, anchor.y * size.y)
		var direction := (center - start).normalized()
		var stagger := 0.72 + float(index % 4) * 0.09
		draw_line(start, start + direction * length * stagger, tint, width, true)
