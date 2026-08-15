class_name WildDashAnimalAbilityProfile
extends RefCounted

## Single source of truth for the six player-facing WILD DASH ability ratings.
## These values drive both Character Select presentation and gameplay adapters.
## Scale: 0.0 .. 10.0

const STAT_ORDER: Array[StringName] = [
	&"swim", &"climb", &"agility", &"power", &"rough", &"defense",
]

const PROFILES: Dictionary = {
	&"dog":       {"swim": 7.5, "climb": 7.0, "agility": 7.0, "power": 6.5, "rough": 7.0, "defense": 6.0},
	&"wolf":      {"swim": 5.5, "climb": 8.5, "agility": 8.0, "power": 7.5, "rough": 7.5, "defense": 6.5},
	&"boar":      {"swim": 6.0, "climb": 8.0, "agility": 5.5, "power": 9.0, "rough": 10.0, "defense": 8.5},
	&"rabbit":    {"swim": 3.5, "climb": 7.5, "agility": 10.0, "power": 5.5, "rough": 6.0, "defense": 4.5},
	&"deer":      {"swim": 5.5, "climb": 8.5, "agility": 9.0, "power": 6.0, "rough": 8.0, "defense": 5.5},
	&"monkey":    {"swim": 4.5, "climb": 10.0, "agility": 10.0, "power": 5.5, "rough": 7.0, "defense": 5.0},
	&"elephant":  {"swim": 8.0, "climb": 4.5, "agility": 3.0, "power": 10.0, "rough": 10.0, "defense": 10.0},
	&"bear":      {"swim": 9.0, "climb": 8.0, "agility": 5.0, "power": 9.5, "rough": 9.0, "defense": 9.0},
	&"panda":     {"swim": 6.5, "climb": 7.0, "agility": 6.0, "power": 7.5, "rough": 8.5, "defense": 8.0},
	&"crocodile": {"swim": 10.0, "climb": 4.0, "agility": 4.5, "power": 8.5, "rough": 9.0, "defense": 8.5},
	&"cat":       {"swim": 2.5, "climb": 9.5, "agility": 10.0, "power": 5.0, "rough": 6.5, "defense": 3.5},
	&"fox":       {"swim": 4.5, "climb": 7.5, "agility": 8.5, "power": 6.0, "rough": 7.0, "defense": 4.0},
	&"raccoon":   {"swim": 8.5, "climb": 7.5, "agility": 9.0, "power": 5.0, "rough": 8.5, "defense": 3.5},
}

const DEFAULT_PROFILE: Dictionary = {
	"swim": 5.0,
	"climb": 5.0,
	"agility": 5.0,
	"power": 5.0,
	"rough": 5.0,
	"defense": 5.0,
}

const IDENTITIES: Dictionary = {
	&"dog": "BALANCED RUNNER",
	&"wolf": "SPEED HUNTER",
	&"boar": "OFFROAD BRUISER",
	&"rabbit": "JUMP SPECIALIST",
	&"deer": "MOUNTAIN RACER",
	&"monkey": "TECHNICAL COLLECTOR",
	&"elephant": "HEAVY TANK",
	&"bear": "ALL-TERRAIN BRUISER",
	&"panda": "STABLE HEAVY",
	&"crocodile": "WATER BRUISER",
	&"cat": "PRECISION RACER",
	&"fox": "BURST RACER",
	&"raccoon": "UTILITY EXPLORER",
}

const PLAYSTYLES: Dictionary = {
	&"dog": "모든 지형에서 큰 약점 없이 운영하는 초보자 친화적 올라운더.",
	&"wolf": "산악과 직선 추격에서 강한 공격적 고속 레이서.",
	&"boar": "진흙·잔디·눈을 버티며 장애물을 뚫고 전진하는 돌파형.",
	&"rabbit": "장애물을 정면으로 상대하기보다 점프와 지름길로 시간을 줄이는 도약형.",
	&"deer": "산악과 기술 구간에서 속도를 잃지 않는 레이스 중심 캐릭터.",
	&"monkey": "나무와 높은 지형의 과일을 선점하는 고기동 Technical Collector.",
	&"elephant": "충돌을 피하지 않고 상대를 밀어내며 정면 돌파하는 최대 중량 Tank.",
	&"bear": "다양한 자연 지형과 물에서 강하고 몸싸움까지 가능한 Heavy All-Terrain 캐릭터.",
	&"panda": "향후 확장 캐릭터용으로 보존된 안정적인 Heavy 캐릭터.",
	&"crocodile": "육지에서는 묵직하지만 물에 들어가면 최고 속도로 돌진하고 강한 Bite를 쓰는 Water Bruiser.",
	&"cat": "좁은 길과 높은 지형을 정확하게 공략하는 고난도 Precision 캐릭터.",
	&"fox": "Cat보다 정밀 회전은 낮지만 직선 Burst와 추월 성능이 높은 캐릭터.",
	&"raccoon": "물·험로·수집 모드를 자유롭게 돌아다니는 고기동 Utility 캐릭터.",
}

static func get_profile(animal_id: StringName) -> Dictionary:
	var profile: Dictionary = PROFILES.get(animal_id, DEFAULT_PROFILE)
	return profile.duplicate(true)

static func get_stat(animal_id: StringName, stat_id: StringName) -> float:
	return clampf(float(get_profile(animal_id).get(String(stat_id), 5.0)), 0.0, 10.0)

static func get_identity(animal_id: StringName) -> String:
	return String(IDENTITIES.get(animal_id, "BALANCED RUNNER"))

static func get_playstyle(animal_id: StringName) -> String:
	return String(PLAYSTYLES.get(animal_id, "특정 능력에 치우치지 않고 상황에 맞춰 운영하는 밸런스형."))

static func has_complete_profile(animal_id: StringName) -> bool:
	if not PROFILES.has(animal_id):
		return false
	var profile: Dictionary = PROFILES[animal_id]
	for stat_id: StringName in STAT_ORDER:
		var key := String(stat_id)
		if not profile.has(key):
			return false
		var value := float(profile[key])
		if value < 0.0 or value > 10.0:
			return false
	return true
