class_name PrototypeRules
extends RefCounted

const MAX_RACERS := 50
const MAX_AI_RACERS := 49
const RACE_QUALIFY_RANK := 25
const FRUIT_TARGET := 8
const SURVIVAL_START_HEARTS := 3

const ANIMALS := {
	"dog": {"role": "sprint", "cooldown": 12.0},
	"rabbit": {"role": "jump", "cooldown": 8.0},
	"elephant": {"role": "defense", "cooldown": 10.0},
	"cat": {"role": "evasion", "cooldown": 9.0},
}

const ITEMS := [&"banana", &"shield", &"magnet", &"ink"]

const DIFFICULTY := {
	"wild": {"ai_speed": 0.985, "aggression": 0.90},
	"chaos": {"ai_speed": 1.0, "aggression": 1.0},
	"nightmare": {"ai_speed": 1.018, "aggression": 1.15},
}

const ROUND_ORDER := [&"race", &"fruit", &"survival", &"final"]

static func qualifies_from_race(rank: int) -> bool:
	return rank > 0 and rank <= RACE_QUALIFY_RANK

static func fruit_round_complete(score: int) -> bool:
	return score >= FRUIT_TARGET

static func survival_failed(hearts: int) -> bool:
	return hearts <= 0
