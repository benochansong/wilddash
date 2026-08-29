extends "res://modes/fruit_collection/fruit_frenzy_v12_vertical_dispersion.gd"

## Small runtime/readability guard for V12.
## Keeps the seventh tree fruit on Tree 5 (the tallest 7.8m tree) and adds a
## lightweight emissive disc under high/tree fruit so vertical routes read from
## across the arena without expensive particles.

func _ready() -> void:
	await super()
	_install_vertical_fruit_markers()
	print("FRUIT FRENZY V13 VERTICAL READABILITY READY high_markers=6 tree_markers=7 tallest_tree=7.8m monkey_top_fruit=true")

func _fruit_position(index: int, cycle: int) -> Vector3:
	if index == 29:
		return Vector3(-10.0, 7.65, -11.0)
	return super(index, cycle)

func _install_vertical_fruit_markers() -> void:
	for fruit_index: int in V12_HIGH_INDICES:
		_add_vertical_marker(fruit_index, false)
	for fruit_index: int in V12_TREE_INDICES:
		_add_vertical_marker(fruit_index, bool(fruits[fruit_index].get_meta(&"wilddash_monkey_top_fruit", false)))

func _add_vertical_marker(fruit_index: int, monkey_top: bool) -> void:
	if fruit_index < 0 or fruit_index >= fruits.size():
		return
	var fruit: MeshInstance3D = fruits[fruit_index]
	if fruit == null:
		return
	var marker: MeshInstance3D = MeshInstance3D.new()
	marker.name = "VerticalFruitMarker"
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.50 if not monkey_top else 0.66
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.055
	mesh.radial_segments = 16
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var color: Color = Color(0.40, 0.92, 1.0, 0.42) if not monkey_top else Color(1.0, 0.72, 0.10, 0.58)
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(color.r, color.g, color.b, 1.0) * (1.25 if monkey_top else 0.75)
	mesh.material = material
	marker.mesh = mesh
	marker.position = Vector3(0.0, -0.58, 0.0)
	marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fruit.add_child(marker)
