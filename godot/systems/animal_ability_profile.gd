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
	&"dog": "BALANCED FIGHTER",
	&"wolf": "HUNTER",
	&"boar": "CHARGE BRUISER",
	&"rabbit": "AERIAL FIGHTER",
	&"deer": "LEAP DUELIST",
	&"monkey": "CANOPY TRICKSTER",
	&"elephant": "PUSH KING",
	&"bear": "CLOSE RANGE BRAWLER",
	&"panda": "STABLE HEAVY",
	&"crocodile": "WATER BRUISER",
	&"cat": "AMBUSH SPECIALIST",
	&"fox": "HIT & RUN",
	&"raccoon": "THIEF / CONTROL",
}

const PLAYSTYLES: Dictionary = {
	&"dog": "넓고 단순한 Shoulder Push와 Running Tackle을 쓰는 초보자 친화적 밸런스 파이터.",
	&"wolf": "도망가거나 등을 보이는 상대를 Lunge와 Rear Pounce로 추격하는 Hunter.",
	&"boar": "높은 Power와 Rough를 살린 Headbutt와 Boar Charge로 정면을 뚫는 Charge Bruiser.",
	&"rabbit": "높은 점프와 Chain Stomp를 이어가며 정면 힘싸움 대신 공중에서 Stagger를 쌓는 Aerial Fighter.",
	&"deer": "이동 Momentum을 Antler Rush와 Hoof Drop으로 바꾸는 전진형 Leap Duelist.",
	&"monkey": "Climb 10과 Agility 10을 살려 나무·가지·덩굴을 연속 이동하고 Swing Kick과 Stomp로 공격하는 Canopy Trickster.",
	&"elephant": "Power 10과 Defense 10으로 Trunk Push와 Ground Stomp를 사용해 상대를 가장자리로 밀어내는 Push King.",
	&"bear": "Paw Swipe, Body Slam, Belly Drop과 Heavy Gas로 근거리 난전을 장악하는 Close Range Brawler.",
	&"panda": "향후 확장 캐릭터용으로 보존된 안정적인 Heavy 캐릭터.",
	&"crocodile": "물에서는 최고 수준의 이동과 Water Ambush를 쓰고 육지에서는 Bite Lunge와 Tail Sweep으로 버티는 Water Bruiser.",
	&"cat": "정면 공격은 약하지만 Pounce와 Back Attack 보너스로 치고 빠지는 Ambush Specialist.",
	&"fox": "Dash Hit과 Feint Strike 뒤 빠르게 거리를 다시 벌리는 Hit & Run 캐릭터.",
	&"raccoon": "Stink Cloud로 상대를 느리게 만들고 뒤에서 과일을 직접 훔칠 수 있는 Thief / Control 캐릭터.",
}

static func get_profile(animal_id: StringName) -> Dictionary:
	var profile: Dictionary = PROFILES.get(animal_id, DEFAULT_PROFILE)
	return profile.duplicate(true)

static func get_stat(animal_id: StringName, stat_id: StringName) -> float:
	return clampf(float(get_profile(animal_id).get(String(stat_id), 5.0)), 0.0, 10.0)

static func get_identity(animal_id: StringName) -> String:
	return String(IDENTITIES.get(animal_id, "BALANCED FIGHTER"))

static func get_playstyle(animal_id: StringName) -> String:
	return String(PLAYSTYLES.get(animal_id, "특정 능력에 치우치지 않고 상황에 맞춰 운영하는 밸런스형."))

static func has_complete_profile(animal_id: StringName) -> bool:
	if not PROFILES.has(animal_id):
		return false
	var profile: Dictionary = PROFILES[animal_id]
	for stat_id: StringName in STAT_ORDER:
		var key: String = String(stat_id)
		if not profile.has(key):
			return false
		var value: float = float(profile[key])
		if value < 0.0 or value > 10.0:
			return false
	return true
