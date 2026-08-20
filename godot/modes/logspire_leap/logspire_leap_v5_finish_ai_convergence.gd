extends "res://modes/logspire_leap/logspire_leap_v4_phase_b.gd"

## Round 3 finish-flow + competitive-field convergence adapter.
##
## Production campaign behavior remains unchanged. When Round 3 is launched
## directly from the editor/F6, reaching Crown Nest is promoted into a synthetic
## Round-3 campaign slot only at the moment of player finish so the normal
## GameManager complete_round -> Round Recap -> Round 4 path can be exercised.
##
## A small subset of AI racers are designated Finale contenders. They use the
## existing Phase-B Platform AI, forced Safe Route late-race convergence, and the
## bounded one-platform recovery defined in logspire_platform_ai_v5_phase_b.gd.

const FINALE_CONTENDER_AI_NUMBERS: Array[int] = [2, 3, 5, 6]
const ROUND3_CAMPAIGN_INDEX: int = 2

func _ready() -> void:
	await super()
	print("r3_finish_ai_convergence_ready contenders=%s direct_finish_to_recap=true round4_target=push_out" % [
		str(FINALE_CONTENDER_AI_NUMBERS),
	])

func _attach_platform_ai(
	racer: WildDashCharacterController,
	driver: WildDashAIController,
	route: Array[Vector3],
	route_ids: Array[StringName],
	route_id: StringName
) -> void:
	super(racer, driver, route, route_ids, route_id)
	if racer == null or racer.is_player:
		return
	var ai_number: int = _phase_b_ai_number(racer)
	if ai_number not in FINALE_CONTENDER_AI_NUMBERS:
		return
	var value: Variant = _platform_ai_by_racer.get(racer.get_instance_id(), null)
	var platform_ai := value as Node
	if platform_ai == null or not platform_ai.has_method("set_finale_contender"):
		push_warning("r3_ai_finale_contender_missing_adapter racer=%s slot=%d" % [
			RaceManager.get_racer_label(racer), ai_number,
		])
		return
	platform_ai.call("set_finale_contender", true)
	print("r3_ai_finale_contender_selected racer=%s animal=%s slot=%d of=%d" % [
		RaceManager.get_racer_label(racer), String(racer.animal_id), ai_number, GameManager.ai_count,
	])

func _on_player_finished(rank: int) -> void:
	if _direct_run:
		_promote_direct_round3_finish_to_recap_flow()
	super(rank)

func _promote_direct_round3_finish_to_recap_flow() -> void:
	# Direct editor/F6 runs previously stopped on the Crown Nest HUD message.
	# Establish only the minimum campaign state required for the same transition
	# path used by a real campaign. No gameplay or checkpoint state is rewritten.
	ResultManager.reset_campaign()
	GameManager.campaign_running = true
	GameManager.current_round_index = ROUND3_CAMPAIGN_INDEX
	GameManager.round_active = true
	GameManager._transition_pending = false
	_direct_run = false
	print("r3_direct_finish_promoted_to_campaign_slot round_index=3 recap=true next=push_out checkpoint_state_preserved=true")
