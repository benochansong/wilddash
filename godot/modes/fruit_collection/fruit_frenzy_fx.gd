extends Node

## Round-2-only readability polish.
## Adds a clear BANK HERE marker, player-bank fruit burst, and a light pulse
## during Golden Harvest without touching shared HUD/audio or Round 1 systems.

const BANK_BURST_COUNT: int = 7

var _mode: Node
var _last_player_banked: int = 0
var _marker_installed := false

func _ready() -> void:
	process_priority = 95
	_mode = get_parent()

func _process(_delta: float) -> void:
	if _mode == null:
		return
	_install_cart_marker_if_ready()
	_update_player_bank_feedback()
	_update_golden_harvest_pulse()

func _install_cart_marker_if_ready() -> void:
	if _marker_installed:
		return
	var cart := _mode.get("_cart_root") as Node3D
	if cart == null:
		return
	var label := Label3D.new()
	label.name = "BankHereLabel"
	label.text = "BANK HERE"
	label.position = Vector3(0.0, 4.7, 0.0)
	label.font_size = 58
	label.outline_size = 12
	label.modulate = Color(0.28, 1.0, 0.42)
	cart.add_child(label)
	_marker_installed = true
	print("FRUIT FRENZY BANK MARKER READY")

func _update_player_bank_feedback() -> void:
	var player := _mode.get("player") as WildDashCharacterController
	if player == null:
		return
	var banked: Dictionary = _mode.get("banked_by_id")
	var current: int = int(banked.get(player.get_instance_id(), 0))
	if current <= _last_player_banked:
		_last_player_banked = current
		return
	var gained: int = current - _last_player_banked
	_last_player_banked = current
	var cart := _mode.get("_cart_root") as Node3D
	if cart != null:
		_spawn_bank_burst(cart.global_position + Vector3.UP * 1.8, gained)

func _spawn_bank_burst(origin: Vector3, gained: int) -> void:
	for i in range(BANK_BURST_COUNT):
		var fruit := MeshInstance3D.new()
		fruit.name = "BankBurstFruit_%02d" % i
		var sphere := SphereMesh.new()
		sphere.radius = 0.22
		sphere.height = 0.44
		var material := StandardMaterial3D.new()
		match i % 4:
			0: material.albedo_color = Color(0.96, 0.20, 0.18)
			1: material.albedo_color = Color(1.0, 0.82, 0.10)
			2: material.albedo_color = Color(0.55, 0.20, 0.84)
			_: material.albedo_color = Color(0.12, 0.90, 0.38)
		material.emission_enabled = true
		material.emission = material.albedo_color * 0.45
		sphere.material = material
		fruit.mesh = sphere
		_mode.add_child(fruit)
		fruit.global_position = origin

		var angle: float = TAU * float(i) / float(BANK_BURST_COUNT)
		var distance: float = 1.6 + float(i % 3) * 0.45
		var target := origin + Vector3(cos(angle) * distance, 1.3 + float(i % 2) * 0.5, sin(angle) * distance)
		var tween := fruit.create_tween()
		tween.set_parallel(true)
		tween.tween_property(fruit, "global_position", target, 0.42)
		tween.tween_property(fruit, "scale", Vector3.ONE * 0.15, 0.52)
		tween.chain().tween_callback(Callable(fruit, "queue_free"))

	print("FRUIT FRENZY BANK BURST gained=%d cosmetic=%d" % [gained, BANK_BURST_COUNT])

func _update_golden_harvest_pulse() -> void:
	if not bool(_mode.get("_golden_harvest_active")):
		return
	var light := _mode.get("_golden_harvest_light") as OmniLight3D
	if light == null:
		return
	var phase: float = float(Time.get_ticks_msec()) * 0.006
	light.light_energy = 1.55 + (sin(phase) * 0.5 + 0.5) * 0.65
