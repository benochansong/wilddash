class_name WildDashLocalizedAnimalStatsPanel
extends "res://ui/animal_stats_panel.gd"

const LOCALIZATION = preload("res://ui/character_select_localization.gd")
const SOURCE_STAT_IDS: Dictionary = {
	"수영": &"swim",
	"등반": &"climb",
	"민첩": &"agility",
	"파워": &"power",
	"험로": &"rough",
	"방어": &"defense",
}

func _ready() -> void:
	super()
	_localize_static_labels()

func show_animal(animal_id: StringName, definition: WildDashAnimalDefinition, chimera_body: bool = false) -> void:
	if not is_node_ready():
		await ready
	super(animal_id, definition, chimera_body)
	if definition == null:
		return

	_context_label.text = LOCALIZATION.text("context_chimera") if chimera_body else LOCALIZATION.text("context_normal")
	_name_label.text = LOCALIZATION.animal_name(animal_id, definition.display_name).to_upper()
	_role_label.text = LOCALIZATION.identity(animal_id, WildDashAnimalSelectionPresentation.get_identity(animal_id))
	_description_label.text = LOCALIZATION.skill_description(animal_id, definition.skill_description)

	var strengths: Array[StringName] = WildDashAnimalSelectionPresentation.get_strengths(animal_id, 2)
	var weaknesses: Array[StringName] = WildDashAnimalSelectionPresentation.get_weaknesses(animal_id, 2)
	_strengths_label.text = "%s   %s" % [LOCALIZATION.text("strengths"), LOCALIZATION.format_stat_tags(strengths)]
	_weaknesses_label.text = "%s   %s" % [LOCALIZATION.text("weaknesses"), LOCALIZATION.format_stat_tags(weaknesses)]
	_playstyle_label.text = LOCALIZATION.playstyle(animal_id, WildDashAnimalSelectionPresentation.get_recommended_style(animal_id))
	_localize_static_labels()

func _localize_static_labels() -> void:
	for node: Node in find_children("*", "Label", true, false):
		var label := node as Label
		if label == null:
			continue
		if SOURCE_STAT_IDS.has(label.text):
			label.text = LOCALIZATION.stat_label(SOURCE_STAT_IDS[label.text])
			continue
		match label.text:
			"ABILITY + COMBAT PROFILE":
				label.text = LOCALIZATION.text("context_normal")
			"CHIMERA BODY 기준 · 6-STAT PROFILE":
				label.text = LOCALIZATION.text("context_chimera")
			"능력치":
				label.text = LOCALIZATION.text("stats")
			"추천 스타일":
				label.text = LOCALIZATION.text("recommended")
			"6개 능력치는 실제 지형·장애물 돌파·기본 공격·방어 밸런스와 동기화됩니다.":
				label.text = LOCALIZATION.text("stats_footer")
