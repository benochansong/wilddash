extends Node

func _ready() -> void:
	var requested_ai := GameManager.MIN_AI_COUNT
	if OS.has_environment("WILDDASH_AI_COUNT"):
		requested_ai = int(OS.get_environment("WILDDASH_AI_COUNT"))
	GameManager.configure_run(&"dog", &"chaos", {"head": 0, "body": 0, "tail": 0}, requested_ai)
	print("WILD DASH 3D four-round campaign ready: ai=%d range=%d..%d" % [GameManager.ai_count, GameManager.MIN_AI_COUNT, GameManager.MAX_AI_COUNT])
	GameManager.start_campaign()
