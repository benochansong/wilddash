class_name WildDashSnowfallController
extends Node3D

@export var normal_amount := 180
@export var blizzard_amount := 320
@export var follow_height := 7.5

var _camera: Camera3D
var _player: WildDashCharacterController
var _track: WildDashSnowpeakWinterTrack
var _particles: GPUParticles3D
var _reported_ready := false

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		print("SNOWFALL READY headless=true particles=false")
		return
	_build_particles()

func _process(_delta: float) -> void:
	if _particles == null:
		return
	_resolve_nodes()
	if _camera != null:
		global_position = _camera.global_position + Vector3.UP * follow_height
	elif _player != null:
		global_position = _player.global_position + Vector3.UP * follow_height
	var blizzard := _track != null and _player != null and _track.is_blizzard_position(_player.global_position)
	var target_amount := blizzard_amount if blizzard else normal_amount
	if _particles.amount != target_amount:
		_particles.amount = target_amount
	if not _reported_ready and _player != null:
		_reported_ready = true
		print("SNOWFALL READY headless=false particles=true amount=%d blizzard_amount=%d" % [normal_amount, blizzard_amount])

func _build_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "SnowParticles"
	_particles.amount = normal_amount
	_particles.lifetime = 4.8
	_particles.randomness = 0.55
	_particles.visibility_aabb = AABB(Vector3(-28.0, -14.0, -28.0), Vector3(56.0, 28.0, 56.0))
	_particles.emitting = true

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(24.0, 8.0, 24.0)
	process.direction = Vector3(0.16, -1.0, 0.08)
	process.spread = 16.0
	process.initial_velocity_min = 3.2
	process.initial_velocity_max = 5.4
	process.gravity = Vector3(0.35, -1.4, 0.15)
	process.scale_min = 0.65
	process.scale_max = 1.35
	_particles.process_material = process

	var flake := QuadMesh.new()
	flake.size = Vector2(0.09, 0.09)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.95, 0.98, 1.0, 0.88)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	flake.material = material
	_particles.draw_pass_1 = flake
	add_child(_particles)

func _resolve_nodes() -> void:
	if _camera == null or not is_instance_valid(_camera):
		_camera = get_parent().get_node_or_null("ChaseCamera") as Camera3D
	if _player == null or not is_instance_valid(_player):
		_player = get_parent().get_node_or_null("Player") as WildDashCharacterController
	if _track == null or not is_instance_valid(_track):
		_track = get_parent().get_node_or_null("SnowpeakWorldTrack") as WildDashSnowpeakWinterTrack
