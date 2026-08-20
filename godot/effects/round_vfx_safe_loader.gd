class_name WildDashRoundVFXSafeLoader
extends Node3D

## Gameplay-safe bridge for Graphics Phase 3 round presentation.
## The optional visual director is intentionally loaded after the gameplay scene
## is already alive. A parser or resource error in visual polish must never keep
## Character Select from entering Round 1.

@export_enum("grand_prix", "fruit_frenzy", "logspire", "wild_rumble", "neon_harbor") var round_profile: String = "grand_prix"

const DIRECTOR_PATH := "res://effects/round_vfx_director.gd"

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		queue_free()
		return
	call_deferred("_attach_optional_director")

func _attach_optional_director() -> void:
	var script_resource: Resource = ResourceLoader.load(DIRECTOR_PATH, "Script", ResourceLoader.CACHE_MODE_REUSE)
	if script_resource == null or not script_resource is Script:
		push_warning("GRAPHICS PHASE 3 ROUND VFX skipped profile=%s reason=optional_director_load_failed gameplay_continues=true" % round_profile)
		queue_free()
		return

	var director := Node3D.new()
	director.name = "GraphicsPhase3RoundVFXRuntime"
	director.set_script(script_resource as Script)
	director.set("round_profile", round_profile)
	var parent := get_parent()
	if parent == null:
		director.queue_free()
		queue_free()
		return
	parent.add_child(director)
	print("GRAPHICS PHASE 3 ROUND VFX SAFE LOAD profile=%s gameplay_scene_already_loaded=true" % round_profile)
	queue_free()
