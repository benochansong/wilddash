class_name WildDashCharacterSelectLocalization
extends RefCounted

## Production Character Select localization for the three languages exposed in Lobby.
## Gameplay definitions remain canonical; this adapter owns player-facing copy only.

const UI_COPY: Dictionary = {
	&"en": {
		"title": "WILD DASH — CHOOSE YOUR RACER",
		"subtitle": "12 UNIQUE RACERS · Compare 6 real ability stats, weight class and skills before choosing.",
		"basic_mode": "12 RACERS",
		"chimera_mode": "CHIMERA LAB · CORE 4",
		"chimera_parts": "CHIMERA CORE PARTS · DOG / RABBIT / ELEPHANT / CAT",
		"head_caption": "HEAD · Active Skill",
		"body_caption": "BODY · Passive Trait",
		"tail_caption": "TAIL · Utility Bonus",
		"color": "COLOR ▶",
		"pattern": "PATTERN ▶",
		"difficulty_wild": "Wild · Casual (10 racers)",
		"difficulty_chaos": "Chaos · Normal (15 racers)",
		"difficulty_nightmare": "Nightmare · Hard (18 racers)",
		"hints": "Choose an animal → compare 6 stats on the right · H/B/T: Chimera · Enter: Start",
		"mode_animal": "MODE: %s · %s",
		"mode_chimera": "MODE: CHIMERA PLAYSTYLE BUILD",
		"speed": "Speed",
		"accel": "Accel",
		"handling": "Handling",
		"jump": "Jump",
		"arena": "Arena",
		"skill": "Skill",
		"cooldown": "Cooldown",
		"start_as": "START AS %s",
		"save_build_start": "SAVE BUILD & START",
		"summary_chimera": "HEAD %s → %s\nBODY %s → passive trait\nTAIL %s → utility bonus\nColor %s · Pattern %s",
		"context_normal": "ABILITY + COMBAT PROFILE",
		"context_chimera": "CHIMERA BODY · 6-STAT PROFILE",
		"stats": "STATS",
		"strengths": "Strengths",
		"weaknesses": "Weaknesses",
		"recommended": "RECOMMENDED STYLE",
		"stats_footer": "The 6 ability stats are synchronized with terrain, obstacle traversal, basic attacks and defense balance.",
		"starting_round1": "STARTING ROUND 1...",
		"validating_transition": "STARTING ROUND 1 · validating campaign transition...",
		"retrying_round1": "ROUND 1 did not transition · retrying with fresh resources...",
		"checking_dependencies": "ROUND 1 load failed · checking production dependencies...",
		"retry_start": "RETRY START",
		"start_error": "START ERROR · %s",
	},
	&"ko": {
		"title": "WILD DASH — 레이서 선택",
		"subtitle": "12명의 개성 있는 레이서 · 6개 실제 능력치·체급·스킬을 비교하고 선택하세요.",
		"basic_mode": "12명의 레이서",
		"chimera_mode": "키메라 연구소 · 핵심 4종",
		"chimera_parts": "키메라 핵심 파츠 · 개 / 토끼 / 코끼리 / 고양이",
		"head_caption": "머리 · 액티브 스킬",
		"body_caption": "몸통 · 패시브 특성",
		"tail_caption": "꼬리 · 보조 보너스",
		"color": "색상 ▶",
		"pattern": "패턴 ▶",
		"difficulty_wild": "Wild · 캐주얼 (10명)",
		"difficulty_chaos": "Chaos · 보통 (15명)",
		"difficulty_nightmare": "Nightmare · 어려움 (18명)",
		"hints": "동물 선택 → 오른쪽 6개 능력치 비교 · H/B/T: 키메라 · Enter: 시작",
		"mode_animal": "모드: %s · %s",
		"mode_chimera": "모드: 키메라 플레이스타일 빌드",
		"speed": "속도",
		"accel": "가속",
		"handling": "핸들링",
		"jump": "점프",
		"arena": "아레나",
		"skill": "스킬",
		"cooldown": "재사용 대기시간",
		"start_as": "%s로 시작",
		"save_build_start": "빌드 저장 후 시작",
		"summary_chimera": "머리 %s → %s\n몸통 %s → 패시브 특성\n꼬리 %s → 보조 보너스\n색상 %s · 패턴 %s",
		"context_normal": "능력 + 전투 프로필",
		"context_chimera": "키메라 몸통 기준 · 6개 능력치",
		"stats": "능력치",
		"strengths": "강점",
		"weaknesses": "약점",
		"recommended": "추천 스타일",
		"stats_footer": "6개 능력치는 실제 지형·장애물 돌파·기본 공격·방어 밸런스와 동기화됩니다.",
		"starting_round1": "라운드 1 시작 중...",
		"validating_transition": "라운드 1 시작 중 · 캠페인 전환 확인 중...",
		"retrying_round1": "라운드 1 전환 실패 · 새 리소스로 다시 시도합니다...",
		"checking_dependencies": "라운드 1 로드 실패 · 게임 리소스를 확인 중입니다...",
		"retry_start": "다시 시작",
		"start_error": "시작 오류 · %s",
	},
	&"es": {
		"title": "WILD DASH — ELIGE TU CORREDOR",
		"subtitle": "12 CORREDORES ÚNICOS · Compara 6 atributos reales, categoría de peso y habilidades antes de elegir.",
		"basic_mode": "12 CORREDORES",
		"chimera_mode": "LAB. QUIMERA · 4 NÚCLEOS",
		"chimera_parts": "PIEZAS NÚCLEO DE QUIMERA · PERRO / CONEJO / ELEFANTE / GATO",
		"head_caption": "CABEZA · Habilidad activa",
		"body_caption": "CUERPO · Rasgo pasivo",
		"tail_caption": "COLA · Bono de utilidad",
		"color": "COLOR ▶",
		"pattern": "PATRÓN ▶",
		"difficulty_wild": "Wild · Casual (10 corredores)",
		"difficulty_chaos": "Chaos · Normal (15 corredores)",
		"difficulty_nightmare": "Nightmare · Difícil (18 corredores)",
		"hints": "Elige un animal → compara 6 atributos a la derecha · H/B/T: Quimera · Enter: Iniciar",
		"mode_animal": "MODO: %s · %s",
		"mode_chimera": "MODO: CONFIGURACIÓN DE QUIMERA",
		"speed": "Velocidad",
		"accel": "Aceleración",
		"handling": "Manejo",
		"jump": "Salto",
		"arena": "Arena",
		"skill": "Habilidad",
		"cooldown": "Recarga",
		"start_as": "JUGAR COMO %s",
		"save_build_start": "GUARDAR CONFIG. E INICIAR",
		"summary_chimera": "CABEZA %s → %s\nCUERPO %s → rasgo pasivo\nCOLA %s → bono de utilidad\nColor %s · Patrón %s",
		"context_normal": "PERFIL DE HABILIDAD + COMBATE",
		"context_chimera": "CUERPO DE QUIMERA · PERFIL DE 6 ATRIBUTOS",
		"stats": "ATRIBUTOS",
		"strengths": "Fortalezas",
		"weaknesses": "Debilidades",
		"recommended": "ESTILO RECOMENDADO",
		"stats_footer": "Los 6 atributos están sincronizados con el terreno, los obstáculos, los ataques básicos y el equilibrio defensivo.",
		"starting_round1": "INICIANDO RONDA 1...",
		"validating_transition": "INICIANDO RONDA 1 · validando la transición de campaña...",
		"retrying_round1": "La RONDA 1 no cambió · reintentando con recursos nuevos...",
		"checking_dependencies": "Falló la carga de RONDA 1 · comprobando recursos del juego...",
		"retry_start": "REINTENTAR",
		"start_error": "ERROR DE INICIO · %s",
	},
}

const STAT_LABELS: Dictionary = {
	&"en": {&"swim": "Swim", &"climb": "Climb", &"agility": "Agility", &"power": "Power", &"rough": "Rough", &"defense": "Defense"},
	&"ko": {&"swim": "수영", &"climb": "등반", &"agility": "민첩", &"power": "파워", &"rough": "험로", &"defense": "방어"},
	&"es": {&"swim": "Nado", &"climb": "Escalada", &"agility": "Agilidad", &"power": "Potencia", &"rough": "Terreno", &"defense": "Defensa"},
}

const ANIMAL_COPY: Dictionary = {
	&"dog": {
		&"en": {"name": "Dog", "identity": "BALANCED FIGHTER", "skill": "RALLY DASH", "description": "A stable breakthrough skill that evenly boosts speed, acceleration and handling for 2 seconds.", "playstyle": "Beginner-friendly balanced fighter with a broad Shoulder Push and a simple Running Tackle."},
		&"ko": {"name": "개", "identity": "밸런스 파이터", "skill": "랠리 대시", "description": "2초 동안 속도·가속·핸들링을 고르게 올리는 가장 안정적인 돌파 스킬.", "playstyle": "넓고 단순한 어깨 밀치기와 달리기 태클을 사용하는 초보자 친화적 밸런스 파이터."},
		&"es": {"name": "Perro", "identity": "LUCHADOR EQUILIBRADO", "skill": "IMPULSO DE RALLY", "description": "Habilidad de avance estable que aumenta de forma equilibrada la velocidad, la aceleración y el manejo durante 2 segundos.", "playstyle": "Luchador equilibrado y accesible para principiantes, con empuje de hombro amplio y placaje en carrera sencillo."},
	},
	&"wolf": {
		&"en": {"name": "Wolf", "identity": "HUNTER", "skill": "HUNTING RUSH", "description": "A high-speed Rally Dash variant built for short, sharp acceleration and straight-line pursuit.", "playstyle": "Hunter who chases fleeing or exposed opponents with a Lunge and Rear Pounce."},
		&"ko": {"name": "늑대", "identity": "사냥꾼", "skill": "사냥 돌진", "description": "짧고 날카로운 가속으로 직선에서 추격하는 고속형 랠리 대시 변형.", "playstyle": "도망가거나 등을 보이는 상대를 돌진과 후방 덮치기로 추격하는 사냥꾼."},
		&"es": {"name": "Lobo", "identity": "CAZADOR", "skill": "CARGA DE CAZA", "description": "Variante veloz de Rally Dash para aceleraciones cortas y persecuciones en línea recta.", "playstyle": "Cazador que persigue a rivales que huyen o muestran la espalda con una embestida y un salto por detrás."},
	},
	&"boar": {
		&"en": {"name": "Boar", "identity": "CHARGE BRUISER", "skill": "TUSK CHARGE", "description": "A rugged charge that prioritizes retaining speed after contact and holding ground over pure top speed.", "playstyle": "Charge Bruiser that uses high Power and Rough to break straight through with Headbutt and Boar Charge."},
		&"ko": {"name": "멧돼지", "identity": "돌진 브루저", "skill": "엄니 돌진", "description": "최고속도보다 충돌 후 속도 유지와 버티기에 초점을 둔 단단한 돌진.", "playstyle": "높은 파워와 험로 능력을 살려 박치기와 멧돼지 돌진으로 정면을 뚫는 돌진형 브루저."},
		&"es": {"name": "Jabalí", "identity": "BRUTO DE CARGA", "skill": "CARGA DE COLMILLOS", "description": "Carga robusta que prioriza conservar velocidad tras el contacto y resistir, más que alcanzar la máxima velocidad.", "playstyle": "Bruto de carga que aprovecha su alta Potencia y Terreno para abrirse paso de frente con cabezazos y embestidas."},
	},
	&"rabbit": {
		&"en": {"name": "Rabbit", "identity": "AERIAL FIGHTER", "skill": "SPRING LEAP", "description": "The strongest jump performance of the 12 racers, specialized in clearing obstacles and shortcuts directly.", "playstyle": "Aerial Fighter that chains high jumps and Stomps to build Stagger instead of trading strength head-on."},
		&"ko": {"name": "토끼", "identity": "공중 파이터", "skill": "스프링 도약", "description": "12종 중 가장 강한 점프 성능으로 장애물과 지름길을 직접 넘는 도약 특화형.", "playstyle": "높은 점프와 연속 내려찍기를 이어가며 정면 힘싸움 대신 공중에서 스태거를 쌓는 공중 파이터."},
		&"es": {"name": "Conejo", "identity": "LUCHADOR AÉREO", "skill": "SALTO RESORTE", "description": "El salto más potente de los 12 corredores, especializado en superar obstáculos y atajos directamente.", "playstyle": "Luchador aéreo que encadena saltos altos y pisotones para acumular desequilibrio en lugar de intercambiar fuerza de frente."},
	},
	&"deer": {
		&"en": {"name": "Deer", "identity": "LEAP DUELIST", "skill": "BOUNDING STRIDE", "description": "A race-focused leap that jumps lower than Rabbit but preserves more running speed and turning.", "playstyle": "Forward-moving Leap Duelist that converts movement momentum into Antler Rush and Hoof Drop."},
		&"ko": {"name": "사슴", "identity": "도약 듀얼리스트", "skill": "도약 질주", "description": "토끼보다 낮게 뛰지만 더 빠른 주행과 회전을 유지하는 레이스 중심 도약.", "playstyle": "이동 탄력을 뿔 돌진과 발굽 내려찍기로 바꾸는 전진형 도약 듀얼리스트."},
		&"es": {"name": "Ciervo", "identity": "DUELISTA SALTADOR", "skill": "ZANCADA SALTADORA", "description": "Salto orientado a la carrera: menos alto que Conejo, pero mantiene mejor la velocidad y el giro.", "playstyle": "Duelista de salto que transforma el impulso de movimiento en carga de astas y caída de pezuñas."},
	},
	&"monkey": {
		&"en": {"name": "Monkey", "identity": "CANOPY TRICKSTER", "skill": "VINE VAULT", "description": "A Canopy Trickster that chains trees, branches and vines quickly, then fights with Swing Kick and aerial Stomp.", "playstyle": "Uses Climb 10 and Agility 10 to chain trees, branches and vines, attacking with Swing Kick and Stomp."},
		&"ko": {"name": "원숭이", "identity": "수관 트릭스터", "skill": "덩굴 도약", "description": "나무·가지·덩굴을 빠르게 연결하고 스윙 킥과 공중 내려찍기로 싸우는 수관 트릭스터.", "playstyle": "등반 10과 민첩 10을 살려 나무·가지·덩굴을 연속 이동하고 스윙 킥과 내려찍기로 공격하는 수관 트릭스터."},
		&"es": {"name": "Mono", "identity": "TRAMPOSO DE LAS COPAS", "skill": "SALTO DE LIANA", "description": "Tramposo de las copas que enlaza árboles, ramas y lianas y ataca con patada de balanceo y pisotón aéreo.", "playstyle": "Usa Escalada 10 y Agilidad 10 para enlazar árboles, ramas y lianas y atacar con patadas de balanceo y pisotones."},
	},
	&"elephant": {
		&"en": {"name": "Elephant", "identity": "PUSH KING", "skill": "STAMPEDE", "description": "A heavyweight racer with top-tier defense whose trunk swings and charges break up the pack. Lower top speed is offset by powerful contact fighting and chase compensation.", "playstyle": "With Power 10 and Defense 10, uses Trunk Push and Ground Stomp to drive opponents toward the edge."},
		&"ko": {"name": "코끼리", "identity": "밀치기의 제왕", "skill": "맹렬한 돌진", "description": "최상급 방어력과 코 휘두르기·돌진으로 팩을 무너뜨리는 중량 레이서. 느린 최고속도는 강한 접촉전과 추격 보정으로 상쇄합니다.", "playstyle": "파워 10과 방어 10으로 코 밀치기와 지면 내려찍기를 사용해 상대를 가장자리로 밀어내는 밀치기의 제왕."},
		&"es": {"name": "Elefante", "identity": "REY DEL EMPUJE", "skill": "ESTAMPIDA", "description": "Corredor pesado con defensa de élite; sus golpes de trompa y embestidas desarman el pelotón. Su menor velocidad punta se compensa con gran contacto y recuperación.", "playstyle": "Con Potencia 10 y Defensa 10 usa empuje de trompa y pisotón para llevar a los rivales hacia el borde."},
	},
	&"bear": {
		&"en": {"name": "Bear", "identity": "CLOSE RANGE BRAWLER", "skill": "BEAR RUSH", "description": "A heavy bruiser charge that crushes one target with a strong body rush and drives back into the lead pack.", "playstyle": "Controls close-range chaos with Paw Swipe, Body Slam, Belly Drop and Heavy Gas."},
		&"ko": {"name": "곰", "identity": "근접 난투가", "skill": "곰 돌진", "description": "강한 몸통 돌진으로 한 대상을 무너뜨리고 다시 선두 팩에 파고드는 중량 브루저 돌진.", "playstyle": "앞발 휘두르기, 몸통 박치기, 배 내려찍기와 강력한 가스로 근거리 난전을 장악하는 난투가."},
		&"es": {"name": "Oso", "identity": "PELEADOR CUERPO A CUERPO", "skill": "EMBESTIDA DEL OSO", "description": "Carga de peso pesado que derriba a un objetivo con un fuerte golpe corporal y vuelve a meterse en el grupo delantero.", "playstyle": "Domina el caos cercano con zarpazo, golpe corporal, caída de barriga y gas pesado."},
	},
	&"panda": {
		&"en": {"name": "Panda", "identity": "STABLE HEAVY", "skill": "HEAVY RUSH", "description": "A stable heavyweight racer preserved for future roster expansion.", "playstyle": "Stable Heavy preserved for a future character expansion."},
		&"ko": {"name": "판다", "identity": "안정형 헤비", "skill": "헤비 돌진", "description": "향후 로스터 확장을 위해 보존된 안정적인 중량 레이서.", "playstyle": "향후 확장 캐릭터용으로 보존된 안정적인 헤비 캐릭터."},
		&"es": {"name": "Panda", "identity": "PESADO ESTABLE", "skill": "CARGA PESADA", "description": "Corredor pesado y estable reservado para una futura ampliación de la plantilla.", "playstyle": "Pesado estable reservado para una futura expansión de personajes."},
	},
	&"crocodile": {
		&"en": {"name": "Crocodile", "identity": "WATER BRUISER", "skill": "BITE LUNGE", "description": "A WATER BRUISER that is heavy and slower on land but becomes explosively fast in water.", "playstyle": "Uses elite water movement and Water Ambush, then survives on land with Bite Lunge and Tail Sweep."},
		&"ko": {"name": "악어", "identity": "수중 브루저", "skill": "물어뜯기 돌진", "description": "육지에서는 묵직하고 느리지만 물에서는 폭발적으로 빨라지는 수중 브루저.", "playstyle": "물에서는 최고 수준의 이동과 수중 기습을 쓰고 육지에서는 물어뜯기 돌진과 꼬리 휩쓸기로 버티는 수중 브루저."},
		&"es": {"name": "Cocodrilo", "identity": "BRUTO ACUÁTICO", "skill": "EMBESTIDA MORDIENTE", "description": "BRUTO ACUÁTICO pesado y lento en tierra, pero explosivamente rápido en el agua.", "playstyle": "Usa movilidad acuática de élite y emboscada en el agua; en tierra resiste con embestida mordiente y barrido de cola."},
	},
	&"cat": {
		&"en": {"name": "Cat", "identity": "AMBUSH SPECIALIST", "skill": "SHADOW STEP", "description": "A precision build with top-tier handling and instant evasion, balanced by only moderate top speed.", "playstyle": "Weak in frontal trades, but excels at Pounce and back-attack bonuses for quick hit-and-run ambushes."},
		&"ko": {"name": "고양이", "identity": "기습 전문가", "skill": "그림자 걸음", "description": "최고 수준의 핸들링과 순간 회피를 제공하지만 최고속도는 중간 수준인 정밀형.", "playstyle": "정면 공격은 약하지만 덮치기와 후방 공격 보너스로 치고 빠지는 기습 전문가."},
		&"es": {"name": "Gato", "identity": "ESPECIALISTA EN EMBOSCADAS", "skill": "PASO SOMBRA", "description": "Especialista de precisión con manejo de élite y evasión instantánea, a cambio de una velocidad punta media.", "playstyle": "Débil en choques frontales, pero destaca con saltos de ataque y bonificación por atacar desde atrás."},
	},
	&"fox": {
		&"en": {"name": "Fox", "identity": "HIT & RUN", "skill": "FOX FEINT", "description": "An overtaking-focused Shadow Step variant with more straight-line burst than Cat but less turning performance.", "playstyle": "Hits with Dash Hit and Feint Strike, then quickly opens the distance again."},
		&"ko": {"name": "여우", "identity": "치고 빠지기", "skill": "여우 페인트", "description": "고양이보다 직선 폭발력이 높고 회전 성능은 낮춘 추월 중심의 그림자 걸음 변형.", "playstyle": "대시 공격과 페인트 공격 뒤 빠르게 거리를 다시 벌리는 치고 빠지기 캐릭터."},
		&"es": {"name": "Zorro", "identity": "GOLPEA Y HUYE", "skill": "FINTA DEL ZORRO", "description": "Variante de Paso Sombra enfocada en adelantar: más explosión en recta que Gato, pero menos giro.", "playstyle": "Golpea con ataque en carrera y finta, y después vuelve a abrir distancia rápidamente."},
	},
	&"raccoon": {
		&"en": {"name": "Raccoon", "identity": "THIEF / CONTROL", "skill": "SCAMPER STEP", "description": "A collection/evasion Quick Dash that trades lower top speed for rapid acceleration and arena mobility.", "playstyle": "Slows rivals with Stink Cloud and can steal fruit directly when attacking from behind."},
		&"ko": {"name": "라쿤", "identity": "도둑 · 제어", "skill": "날쌘 걸음", "description": "낮은 최고속도 대신 빠른 가속과 아레나 기동을 얻는 수집·회피형 퀵 대시.", "playstyle": "악취 구름으로 상대를 느리게 만들고 뒤에서 과일을 직접 훔칠 수 있는 도둑·제어 캐릭터."},
		&"es": {"name": "Mapache", "identity": "LADRÓN / CONTROL", "skill": "PASO ESCURRIDIZO", "description": "Quick Dash de recolección y evasión: sacrifica velocidad punta por aceleración rápida y movilidad en arena.", "playstyle": "Ralentiza rivales con nube apestosa y puede robar fruta directamente al atacar desde atrás."},
	},
}

static func active_language() -> StringName:
	var locale := String(TranslationServer.get_locale()).to_lower()
	if locale.begins_with("ko"):
		return &"ko"
	if locale.begins_with("es"):
		return &"es"
	return &"en"

static func text(key: String, fallback: String = "") -> String:
	var language := active_language()
	var copy: Dictionary = UI_COPY.get(language, UI_COPY[&"en"])
	return String(copy.get(key, fallback))

static func animal_name(animal_id: StringName, fallback: String = "") -> String:
	return _animal_value(animal_id, "name", fallback if not fallback.is_empty() else String(animal_id).capitalize())

static func identity(animal_id: StringName, fallback: String = "") -> String:
	return _animal_value(animal_id, "identity", fallback)

static func skill_name(animal_id: StringName, fallback: String = "") -> String:
	return _animal_value(animal_id, "skill", fallback)

static func skill_description(animal_id: StringName, fallback: String = "") -> String:
	return _animal_value(animal_id, "description", fallback)

static func playstyle(animal_id: StringName, fallback: String = "") -> String:
	return _animal_value(animal_id, "playstyle", fallback)

static func stat_label(stat_id: StringName) -> String:
	var language := active_language()
	var labels: Dictionary = STAT_LABELS.get(language, STAT_LABELS[&"en"])
	return String(labels.get(stat_id, String(stat_id).capitalize()))

static func format_stat_tags(stats: Array[StringName]) -> String:
	var labels: PackedStringArray = []
	for stat_id: StringName in stats:
		labels.append(stat_label(stat_id))
	return " · ".join(labels)

static func _animal_value(animal_id: StringName, key: String, fallback: String) -> String:
	var animal: Dictionary = ANIMAL_COPY.get(animal_id, {})
	if animal.is_empty():
		return fallback
	var language := active_language()
	var localized: Dictionary = animal.get(language, animal.get(&"en", {}))
	return String(localized.get(key, fallback))
