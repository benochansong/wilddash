class_name WildDashBeeSwarmEffect
extends Node3D

const LIFE_SECONDS := 1.25

var target: WildDashCharacterController
var _life := LIFE_SECONDS
var _multimesh_instance: MultiMeshInstance3D

func configure(value: WildDashCharacterController) -> void:
	target = value

func _ready() -> void:
	_build_visual()

func _process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0 or target == null or not is_instance_valid(target):
		queue_free()
		return
	global_position = target.global_position + Vector3.UP * 1.35
	rotation.y += delta * 3.8
	if _multimesh_instance != null:
		var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.012) * 0.06
		_multimesh_instance.scale = Vector3.ONE * pulse

func _build_visual() -> void:
	_multimesh_instance = MultiMeshInstance3D.new()
	_multimesh_instance.name = "BeeSwarmVisual"
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.instance_count = 7
	var bee_mesh := SphereMesh.new()
	bee_mesh.radius = 0.12
	bee_mesh.height = 0.24
	bee_mesh.radial_segments = 6
	bee_mesh.rings = 4
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.78, 0.08)
	material.emission_enabled = true
	material.emission = Color(0.35, 0.18, 0.0)
	material.emission_energy_multiplier = 1.15
	bee_mesh.material = material
	multimesh.mesh = bee_mesh
	for i in range(multimesh.instance_count):
		var angle := TAU * float(i) / float(multimesh.instance_count)
		var radius := 0.55 + 0.10 * float(i % 2)
		var pos := Vector3(cos(angle) * radius, sin(angle * 2.0) * 0.18, sin(angle) * radius)
		multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos))
	_multimesh_instance.multimesh = multimesh
	add_child(_multimesh_instance)
