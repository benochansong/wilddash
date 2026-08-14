extends Node

## Grand Prix V2.9 hard safety net.
##
## Round 1 no longer uses visible rails. This autoload exists deliberately at
## project level so even a stale/legacy Grand Prix scene cannot reintroduce the
## old cyan/dark guardrails or their route-beacon poles. Gameplay collision is
## never removed: CollisionObject3D / CollisionShape3D and invisible CSG
## collision shapes are explicitly preserved.

const SWEEP_INTERVAL: float = 0.10
const STARTUP_SWEEPS: int = 80

const ROOT_NAMES: PackedStringArray = PackedStringArray([
	"ProductionArtDressing",
	"ProductionArt_grand_prix",
	"RouteContainmentGuidance",
])

const VISUAL_EXACT_NAMES: PackedStringArray = PackedStringArray([
	"GuardrailPosts",
	"V2GuardrailVisuals",
])

const VISUAL_PREFIXES: PackedStringArray = PackedStringArray([
	"GuardrailUpper_",
	"GuardrailLower_",
	"GuardrailPost_",
	"V2GuardrailChunk_",
	"RouteBeacon_",
	"HeroLandmark_",
])

var _elapsed: float = 0.0
var _startup_sweeps_left: int = STARTUP_SWEEPS
var _total_removed: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	print("GRAND PRIX V2.9 VISUAL GUARDRAIL KILLER READY collision_preserved=true")

func _process(delta: float) -> void:
	if not _is_grand_prix_active():
		_elapsed = 0.0
		_startup_sweeps_left = STARTUP_SWEEPS
		return

	_elapsed += delta
	if _elapsed < SWEEP_INTERVAL and _startup_sweeps_left <= 0:
		return
	_elapsed = 0.0
	if _startup_sweeps_left > 0:
		_startup_sweeps_left -= 1

	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	var removed: int = _purge_visual_guardrails(scene)
	if removed > 0:
		_total_removed += removed
		print("GRAND PRIX V2.9 VISUAL GUARDRAIL PURGE removed=%d total=%d" % [removed, _total_removed])

func _is_grand_prix_active() -> bool:
	var scene: Node = get_tree().current_scene
	if scene == null:
		return false
	var scene_path: String = scene.scene_file_path.to_lower()
	if scene_path.contains("/grand_prix/"):
		return true
	return _contains_grand_prix_marker(scene)

func _contains_grand_prix_marker(root: Node) -> bool:
	if root == null:
		return false
	var node_name: String = String(root.name)
	if node_name == "GrandPrix" or node_name == "GrandPrixWorldTrack" or node_name == "GrandPrixTrack":
		return true
	for child: Node in root.get_children():
		if _contains_grand_prix_marker(child):
			return true
	return false

func _purge_visual_guardrails(root: Node) -> int:
	var removed: int = 0
	for child: Node in root.get_children():
		if _should_remove_visual_node(child):
			child.queue_free()
			removed += 1
			continue
		removed += _purge_visual_guardrails(child)
	return removed

func _should_remove_visual_node(node: Node) -> bool:
	if node == null:
		return false

	# Never touch gameplay collision, even when a legacy collision node happens
	# to include the word Rail or Barrier in its name.
	if node is CollisionObject3D or node is CollisionShape3D:
		return false
	if node is CSGShape3D:
		var csg: CSGShape3D = node as CSGShape3D
		if csg.use_collision or not csg.visible:
			return false

	var node_name: String = String(node.name)
	if ROOT_NAMES.has(node_name):
		return true
	if node_name.begins_with("ProductionArt_grand_prix"):
		return true
	if VISUAL_EXACT_NAMES.has(node_name):
		return node is VisualInstance3D or node is Node3D
	for prefix: String in VISUAL_PREFIXES:
		if node_name.begins_with(prefix):
			return node is VisualInstance3D or node is Node3D

	# Legacy direct rail visuals sometimes used Rail_##_*_Visual. Collision
	# siblings end in _Collision and are preserved by the checks above.
	if node_name.begins_with("Rail_") and node_name.ends_with("_Visual"):
		return node is VisualInstance3D
	return false
