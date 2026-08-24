extends RefCounted

## Small shared helper for the AI Battle spectator MVP.
## The GameManager autoload survives scene changes, so metadata keeps spectator
## state across the full five-round campaign without changing campaign APIs.

const META_KEY: StringName = &"wilddash_spectator_mode"
const CAMERA_SCRIPT: Script = preload("res://camera/spectator_camera_director.gd")

static func set_enabled(enabled: bool) -> void:
	GameManager.set_meta(META_KEY, enabled)
	print("SPECTATOR MODE state=%s" % str(enabled))

static func is_enabled() -> bool:
	return bool(GameManager.get_meta(META_KEY, false))

static func install_camera(mode_root: Node, racer_values: Array) -> Node:
	if not is_enabled() or mode_root == null:
		return null
	var existing := mode_root.get_node_or_null("SpectatorCameraDirector")
	if existing != null:
		return existing
	var director := CAMERA_SCRIPT.new()
	if director == null:
		push_error("SPECTATOR MODE failed to create camera director")
		return null
	director.name = "SpectatorCameraDirector"
	mode_root.add_child(director)
	director.call("configure", mode_root, racer_values)
	return director

static func disable_human_control(racer: WildDashCharacterController) -> void:
	if racer == null:
		return
	racer.is_player = false
