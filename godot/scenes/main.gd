extends Node

func _ready() -> void:
	var requested_ai := GameManager.MIN_AI_COUNT
	if OS.has_environment("WILDDASH_AI_COUNT"):
		requested_ai = int(OS.get_environment("WILDDASH_AI_COUNT"))
	# Character/chimera selection is owned by GameManager. Main only configures
	# the run defaults and must not overwrite a previously selected loadout.
	GameManager.configure_run(&"dog", &"chaos", {}, requested_ai)
	print("WILD DASH 3D four-round campaign ready: ai=%d range=%d..%d" % [GameManager.ai_count, GameManager.MIN_AI_COUNT, GameManager.MAX_AI_COUNT])
	GameManager.start_campaign()
