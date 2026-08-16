class_name WildDashMudSplashTrap
extends Area3D

const LIFE_SECONDS: float = 10.0
const HIT_DURATION: float = 1.35
const HIT_SLOW_MULTIPLIER: float = 0.66

var owner_racer: WildDashCharacterController
var _life: float = LIFE_SECONDS

func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitoring = true
	body_entered.connect(_on_body_entered)
	var collision: CollisionShape3D = CollisionShape3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new()
	shape.radius = 1.35
	shape.height = 0.35
	collision.shape = shape
	add_child(collision)
	var visual: MeshInstance3D = MeshInstance3D.new()
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 1.28
	mesh.bottom_radius = 1.42
	mesh.height = 0.12
	mesh.radial_segments = 12
	visual.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = Color(0.24, 0.12, 0.045)
	material.roughness = 0.95
	visual.material_override = material
	add_child(visual)

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == owner_racer or not body is WildDashCharacterController:
		return
	var victim: WildDashCharacterController = body as WildDashCharacterController
	if ItemSystem.apply_attack(victim, owner_racer, &"mud_splash", HIT_DURATION, HIT_SLOW_MULTIPLIER, 0.0):
		AudioManager.play_sfx_id("hit", 0.58)
		print("MUD SPLASH POWER HIT target=%s slow=%.2f duration=%.2f" % [
			RaceManager.get_racer_label(victim), HIT_SLOW_MULTIPLIER, HIT_DURATION,
		])
		queue_free()
