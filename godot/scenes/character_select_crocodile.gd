extends "res://scenes/character_select.gd"

## RC9 active-roster adapter. The base Character Select remains intact while the
## ninth basic slot swaps archived Panda for the new Crocodile Water Bruiser.

func _ready() -> void:
	super()
	_replace_panda_button_with_crocodile()
	print("CHARACTER SELECT RC9 ROSTER active=12 panda_archived=true crocodile_playable=true")

func _replace_panda_button_with_crocodile() -> void:
	var panda_button: Button = _animal_buttons.get(&"panda", null) as Button
	if panda_button == null:
		return
	var grid := panda_button.get_parent() as GridContainer
	if grid == null:
		return
	var old_index := panda_button.get_index()
	_animal_buttons.erase(&"panda")
	grid.remove_child(panda_button)
	panda_button.queue_free()

	var definition := WildDashAnimalCatalog.get_definition(&"crocodile")
	if definition == null:
		return
	var button := Button.new()
	button.text = definition.display_name.to_upper()
	button.tooltip_text = "%s · %s · %s" % [
		definition.display_name,
		WildDashAnimalSelectionPresentation.get_identity(&"crocodile"),
		definition.skill_name,
	]
	button.custom_minimum_size = Vector2(170, 48)
	button.toggle_mode = true
	button.pressed.connect(select_animal.bind(&"crocodile"))
	grid.add_child(button)
	grid.move_child(button, old_index)
	_animal_buttons[&"crocodile"] = button
	_refresh_animal_button_states()
