extends Node3D

@onready var player: WildDashCharacterController = $TestRacer

func _ready() -> void:
	GameManager.configure_run(&"dog", &"chaos", {"head": 0, "body": 0, "tail": 0})
	RaceManager.start_race()
	print("WILD DASH 3D scaffold ready: test track + temporary CharacterBody3D racer")

func _exit_tree() -> void:
	if player != null:
		RaceManager.unregister_racer(player)
