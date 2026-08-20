class_name WildDashGraphicsPhase2WorldArt
extends Node3D

## Graphics Phase 2 visual-only world art director.
## Existing lighting, route geometry, collision, AI, recovery and Phase 1 materials
## remain authoritative. Everything generated here is decoration-only.

@export_enum("grand_prix", "fruit_frenzy", "logspire", "wild_rumble", "neon_harbor") var round_profile: String = "grand_prix"

const PROFILE_GRAND_PRIX := "grand_prix"
const PROFILE_FRUIT := "fruit_frenzy"
const PROFILE_LOGSPIRE := "logspire"
const PROFILE_RUMBLE := "wild_rumble"
const PROFILE_NEON := "neon_harbor"

var _foreground: Node3D
var _gameplay: Node3D
var _background: Node3D
var _far_background: Node3D
var _rng := RandomNumberGenerator.new()
var _landmark_count: int = 0
var _multimesh_instances: int = 0

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		set_process(false)
		return
	_rng.seed = 7319 + round_profile.hash()
	call_deferred("_build_visual_world")

func _build_visual_world() -> void:
	_build_depth_roots()
	match round_profile:
		PROFILE_FRUIT: _build_fruit_festival()
		PROFILE_LOGSPIRE: _build_logspire_forest()
		PROFILE_RUMBLE: _build_titan_arena()
		PROFILE_NEON: _build_neon_festival()
		_: _build_safari_adventure()
	print("GRAPHICS PHASE 2 WORLD READY profile=%s depth_layers=4 landmarks=%d multimesh_instances=%d collision_added=false route_changed=false" % [
		round_profile, _landmark_count, _multimesh_instances,
	])

func _build_depth_roots() -> void:
	_foreground = Node3D.new()
	_foreground.name = "ForegroundDetail"
	add_child(_foreground)
	_gameplay = Node3D.new()
	_gameplay.name = "GameplayArtLayer"
	add_child(_gameplay)
	_background = Node3D.new()
	_background.name = "BackgroundDetail"
	add_child(_background)
	_far_background = Node3D.new()
	_far_background.name = "FarBackgroundSilhouette"
	add_child(_far_background)

# -----------------------------------------------------------------------------
# ROUND 1 — SUNNY SAFARI ADVENTURE
# -----------------------------------------------------------------------------

func _build_safari_adventure() -> void:
	var grass_mat: Material = WildDashEnvironmentMaterialLibrary.get_palette().get(&"grass")
	var rock_mat: Material = WildDashEnvironmentMaterialLibrary.get_palette().get(&"rock")
	var wood_mat: Material = WildDashEnvironmentMaterialLibrary.get_palette().get(&"wood")
	var sun_mat := _mat(Color("e7a947"), 0.66)
	var flag_mat := _mat(Color("ef704d"), 0.62)
	_add_grass_multimesh(_foreground, "SafariGrass", 96, Vector3(42, 0, -155), Vector3(92, 0, 330), grass_mat, 48.0)
	_add_rock_multimesh(_background, "SafariRocks", 28, Vector3(0, -0.2, -175), Vector3(88, 0, 350), rock_mat, 95.0)
	_add_flag_multimesh(_gameplay, "SafariRaceFlags", 34, Vector3(0, 1.2, -170), Vector3(58, 0, 340), flag_mat, 70.0)
	_add_landmark_baobab("Landmark_SafariBaobab", Vector3(-31, 0, -72), 9.0, wood_mat, grass_mat)
	_add_landmark_arch("Landmark_SunstoneRaceArch", Vector3(29, 0, -190), 11.0, rock_mat, sun_mat)
	_add_landmark_balloon("Landmark_AdventureBalloon", Vector3(-36, 19, -315), sun_mat, flag_mat)
	_add_far_hills(_far_background, "SafariDistantLandscape", Vector3(0, -4, -390), 9, Color("70845c"), 220.0)
	_add_safari_wildlife(Vector3(26, 8, -118))

func _add_landmark_baobab(node_name: String, position: Vector3, scale_value: float, wood: Material, leaf: Material) -> void:
	var root := _landmark_root(node_name, position, _background)
	_add_mesh(root, "HeroTrunk", _cylinder_mesh(2.3, 1.4, 12.0, wood), Vector3(0, 6, 0), Vector3.ONE * scale_value / 9.0, 150.0)
	for offset in [Vector3(-3.0, 12.0, 0), Vector3(3.2, 11.3, 0.6), Vector3(0, 13.0, -2.2)]:
		_add_mesh(root, "ChunkyCrown", _sphere_mesh(leaf, 12, 7), offset, Vector3(4.2, 2.8, 3.8), 150.0)

func _add_landmark_arch(node_name: String, position: Vector3, width: float, stone: Material, accent: Material) -> void:
	var root := _landmark_root(node_name, position, _background)
	_add_mesh(root, "PillarL", _box_mesh(Vector3(2.0, 9.0, 2.0), stone), Vector3(-width * 0.5, 4.5, 0), Vector3.ONE, 130.0)
	_add_mesh(root, "PillarR", _box_mesh(Vector3(2.0, 9.0, 2.0), stone), Vector3(width * 0.5, 4.5, 0), Vector3.ONE, 130.0)
	_add_mesh(root, "TopBeam", _box_mesh(Vector3(width + 2.0, 1.6, 2.2), accent), Vector3(0, 9.2, 0), Vector3.ONE, 130.0)

func _add_landmark_balloon(node_name: String, position: Vector3, balloon_mat: Material, stripe_mat: Material) -> void:
	var root := _landmark_root(node_name, position, _far_background)
	_add_mesh(root, "Balloon", _sphere_mesh(balloon_mat, 16, 9), Vector3.ZERO, Vector3(4.2, 5.2, 4.2), 220.0)
	_add_mesh(root, "BalloonStripe", _torus_mesh(stripe_mat), Vector3.ZERO, Vector3(4.4, 1.4, 4.4), 220.0)
	_add_mesh(root, "Basket", _box_mesh(Vector3(1.6, 1.2, 1.6), _mat(Color("795132"), 0.84)), Vector3(0, -6.2, 0), Vector3.ONE, 220.0)

func _add_safari_wildlife(position: Vector3) -> void:
	var flock := Node3D.new()
	flock.name = "SmallWildlifeSilhouettes"
	flock.position = position
	_background.add_child(flock)
	var bird_mat := _mat(Color("293838"), 0.88)
	for i in range(7):
		var bird := _add_mesh(flock, "Bird", _box_mesh(Vector3(0.7, 0.05, 0.14), bird_mat), Vector3(float(i) * 1.3, sin(float(i)) * 0.6, -float(i) * 0.8), Vector3.ONE, 120.0)
		bird.rotation.z = (-0.18 if i % 2 == 0 else 0.18)

# -----------------------------------------------------------------------------
# ROUND 2 — JUICY TROPICAL FESTIVAL
# -----------------------------------------------------------------------------

func _build_fruit_festival() -> void:
	var foliage := _mat(Color("3f8a43"), 0.86)
	var wood := _mat(Color("80502f"), 0.84)
	var mango := _mat(Color("ffad32"), 0.62)
	var berry := _mat(Color("d9416e"), 0.64)
	var aqua := _mat(Color("38c6bd"), 0.58)
	_add_leaf_multimesh(_background, "TropicalFoliage", 64, Vector3.ZERO, Vector3(50, 0, 50), foliage, 62.0)
	_add_flag_multimesh(_gameplay, "FestivalBunting", 28, Vector3.ZERO, Vector3(48, 0, 48), berry, 52.0)
	_add_landmark_fruit_market("Landmark_FruitMarketPavilion", Vector3(-22, 0, -21), wood, mango, berry)
	_add_landmark_golden_fruit("Landmark_GoldenFruitShrine", Vector3(22, 0, -20), mango, aqua)
	_add_landmark_juice_tower("Landmark_JuiceFestivalTower", Vector3(0, 0, 24), berry, aqua, mango)
	_add_fruit_baskets(Vector3(-20, 0, 18), 5)
	_add_fruit_baskets(Vector3(18, 0, 17), 5)

func _add_landmark_fruit_market(node_name: String, position: Vector3, wood: Material, canopy: Material, accent: Material) -> void:
	var root := _landmark_root(node_name, position, _background)
	for x in [-4.0, 4.0]:
		_add_mesh(root, "MarketPost", _cylinder_mesh(0.30, 0.30, 6.0, wood), Vector3(x, 3.0, 0), Vector3.ONE, 72.0)
	_add_mesh(root, "ColorfulCanopy", _box_mesh(Vector3(10.0, 0.5, 5.0), canopy), Vector3(0, 6.0, 0), Vector3.ONE, 72.0)
	_add_mesh(root, "FestivalBanner", _box_mesh(Vector3(7.2, 1.0, 0.18), accent), Vector3(0, 4.8, -2.6), Vector3.ONE, 72.0)

func _add_landmark_golden_fruit(node_name: String, position: Vector3, gold: Material, accent: Material) -> void:
	var root := _landmark_root(node_name, position, _background)
	_add_mesh(root, "ShrineBase", _cylinder_mesh(3.2, 3.8, 1.3, accent), Vector3(0, 0.65, 0), Vector3.ONE, 72.0)
	_add_mesh(root, "GoldenFruit", _sphere_mesh(gold, 16, 9), Vector3(0, 5.6, 0), Vector3(2.8, 3.1, 2.8), 72.0)
	_add_mesh(root, "GoldenLeaf", _sphere_mesh(accent, 10, 5), Vector3(1.5, 8.0, 0), Vector3(1.6, 0.35, 0.8), 72.0)

func _add_landmark_juice_tower(node_name: String, position: Vector3, berry: Material, aqua: Material, mango: Material) -> void:
	var root := _landmark_root(node_name, position, _background)
	_add_mesh(root, "JuiceCup", _cylinder_mesh(2.5, 3.2, 7.0, berry), Vector3(0, 3.5, 0), Vector3.ONE, 76.0)
	_add_mesh(root, "JuiceTop", _cylinder_mesh(3.2, 3.2, 0.5, mango), Vector3(0, 7.1, 0), Vector3.ONE, 76.0)
	var straw := _add_mesh(root, "GiantStraw", _cylinder_mesh(0.28, 0.28, 7.0, aqua), Vector3(1.2, 10.0, 0), Vector3.ONE, 76.0)
	straw.rotation.z = 0.20

func _add_fruit_baskets(position: Vector3, count: int) -> void:
	var root := Node3D.new()
	root.name = "FruitBasketCluster"
	root.position = position
	_foreground.add_child(root)
	var basket := _mat(Color("8f5f32"), 0.88)
	var colors := [Color("e94b35"), Color("ffc43a"), Color("7d4db5")]
	for i in range(count):
		var p := Vector3(float(i % 3) * 1.2, 0.25, float(i / 3) * 1.1)
		_add_mesh(root, "Basket", _cylinder_mesh(0.55, 0.75, 0.50, basket), p, Vector3.ONE, 38.0)
		_add_mesh(root, "Fruit", _sphere_mesh(_mat(colors[i % colors.size()], 0.72), 8, 4), p + Vector3(0, 0.55, 0), Vector3(0.38, 0.38, 0.38), 38.0)

# -----------------------------------------------------------------------------
# ROUND 3 — MAGICAL GIANT FOREST
# -----------------------------------------------------------------------------

func _build_logspire_forest() -> void:
	var wood: Material = WildDashEnvironmentMaterialLibrary.get_palette().get(&"wood")
	var foliage: Material = WildDashEnvironmentMaterialLibrary.get_palette().get(&"foliage")
	var moss := _mat(Color("6f9e48"), 0.92)
	var mushroom := _mat(Color("d96c7f"), 0.72)
	var magic := _emissive(Color("6ce5b4"), 1.45, 0.58)
	_add_logspire_route_sleeves(wood, moss)
	_add_fern_multimesh(_foreground, "ForestFerns", 112, Vector3(0, 0, -330), Vector3(70, 42, 660), foliage, 58.0)
	_add_mushroom_multimesh(_gameplay, "MooncapMushrooms", 38, Vector3(0, 3, -340), Vector3(58, 50, 650), mushroom, 70.0)
	_add_magic_light_multimesh(_gameplay, "ForestFireflies", 72, Vector3(0, 12, -360), Vector3(54, 52, 680), magic, 82.0)
	_add_landmark_root_cathedral("Landmark_TitanRootCathedral", Vector3(-31, 8, -120), wood, moss)
	_add_landmark_mushroom_grove("Landmark_MooncapGrove", Vector3(31, 21, -350), mushroom, magic)
	_add_landmark_ancient_gate("Landmark_AncientFireflyGate", Vector3(-32, 46, -610), wood, moss, magic)
	_add_far_forest(_far_background, "AncientForestSilhouette", Vector3(0, 0, -390), 18, Color("233b31"), 240.0)
	_add_forest_sun_shafts()

func _add_logspire_route_sleeves(wood: Material, moss: Material) -> void:
	var world := get_parent().get_node_or_null("LogspireWorld")
	if world == null or not world.has_method("get_main_route_points"):
		return
	var value: Variant = world.call("get_main_route_points")
	if not (value is Array):
		return
	var points: Array = value
	for i in range(1, points.size()):
		if not (points[i - 1] is Vector3) or not (points[i] is Vector3):
			continue
		if i % 2 != 0:
			continue
		var a: Vector3 = points[i - 1]
		var b: Vector3 = points[i]
		var delta := b - a
		var planar := Vector2(delta.x, delta.z)
		var length := planar.length()
		if length <= 0.5 or length > 32.0:
			continue
		var center := a.lerp(b, 0.5) + Vector3(0, -0.58, 0)
		var sleeve := _add_mesh(_gameplay, "VisualRootSleeve", _box_mesh(Vector3(5.8, 0.60, length * 0.88), wood), center, Vector3.ONE, 74.0)
		sleeve.rotation.y = atan2(-delta.x, -delta.z)
		sleeve.rotation.x = atan2(delta.y, maxf(0.1, length))
		var moss_strip := _add_mesh(_gameplay, "MossHighlight", _box_mesh(Vector3(4.4, 0.08, length * 0.68), moss), center + Vector3(0, 0.36, 0), Vector3.ONE, 64.0)
		moss_strip.rotation.y = sleeve.rotation.y

func _add_landmark_root_cathedral(node_name: String, position: Vector3, wood: Material, moss: Material) -> void:
	var root := _landmark_root(node_name, position, _background)
	for side in [-1.0, 1.0]:
		var trunk := _add_mesh(root, "MassiveRoot", _cylinder_mesh(2.6, 3.8, 22.0, wood), Vector3(side * 8.0, 9.0, 0), Vector3.ONE, 150.0)
		trunk.rotation.z = side * 0.32
		_add_mesh(root, "MossCrown", _sphere_mesh(moss, 12, 6), Vector3(side * 8.0, 19.0, 0), Vector3(3.7, 2.0, 3.2), 150.0)

func _add_landmark_mushroom_grove(node_name: String, position: Vector3, cap_mat: Material, glow_mat: Material) -> void:
	var root := _landmark_root(node_name, position, _background)
	for i in range(5):
		var x := float(i - 2) * 3.3
		var h := 4.0 + float(i % 3) * 1.8
		_add_mesh(root, "MooncapStem", _cylinder_mesh(0.55, 0.85, h, _mat(Color("dfd6bc"), 0.90)), Vector3(x, h * 0.5, 0), Vector3.ONE, 105.0)
		_add_mesh(root, "Mooncap", _sphere_mesh(cap_mat if i % 2 == 0 else glow_mat, 12, 6), Vector3(x, h, 0), Vector3(2.2, 0.75, 2.2), 105.0)

func _add_landmark_ancient_gate(node_name: String, position: Vector3, wood: Material, moss: Material, glow: Material) -> void:
	var root := _landmark_root(node_name, position, _background)
	for x in [-6.0, 6.0]:
		_add_mesh(root, "AncientTrunk", _cylinder_mesh(1.8, 2.6, 18.0, wood), Vector3(x, 9, 0), Vector3.ONE, 150.0)
		_add_mesh(root, "AncientMoss", _sphere_mesh(moss, 10, 5), Vector3(x, 16, 0), Vector3(2.8, 1.1, 2.0), 150.0)
	_add_mesh(root, "AncientBridgeCrown", _box_mesh(Vector3(14.0, 1.4, 2.8), wood), Vector3(0, 17, 0), Vector3.ONE, 150.0)
	for x in [-4.2, 0.0, 4.2]:
		_add_mesh(root, "MagicLantern", _sphere_mesh(glow, 10, 5), Vector3(x, 14.8, -1.7), Vector3(0.42, 0.42, 0.42), 150.0)

func _add_forest_sun_shafts() -> void:
	var shaft_mat := _transparent_emissive(Color(0.76, 0.95, 0.72, 0.10), 0.18)
	for i in range(3):
		var shaft := _add_mesh(_far_background, "SunShaft", _cylinder_mesh(1.2, 4.0, 38.0, shaft_mat), Vector3(-24.0 + float(i) * 24.0, 38.0, -220.0 - float(i) * 145.0), Vector3.ONE, 170.0)
		shaft.rotation.z = 0.16

# -----------------------------------------------------------------------------
# ROUND 4 — ANIMAL TITAN ARENA
# -----------------------------------------------------------------------------

func _build_titan_arena() -> void:
	var stone := _mat(Color("59463a"), 0.90)
	var wood := _mat(Color("744624"), 0.82)
	var orange := _mat(Color("ef6c35"), 0.60)
	var gold := _mat(Color("e8b345"), 0.55)
	_add_flag_multimesh(_background, "AudienceBanners", 32, Vector3.ZERO, Vector3(54, 0, 54), orange, 64.0)
	_add_totem_multimesh(_background, "ArenaTotems", 18, Vector3.ZERO, 27.0, wood, gold, 72.0)
	_add_landmark_titan_gate("Landmark_TitanGate", Vector3(0, 0, -25), stone, orange)
	_add_landmark_totem_pair("Landmark_ChampionTotems", Vector3(-24, 0, 6), wood, gold)
	_add_landmark_champion_dais("Landmark_ChampionDais", Vector3(22, 0, 12), stone, gold)
	_add_arena_impact_marks()

func _add_landmark_titan_gate(node_name: String, position: Vector3, stone: Material, accent: Material) -> void:
	var root := _landmark_root(node_name, position, _background)
	for x in [-6.0, 6.0]:
		_add_mesh(root, "GateTower", _box_mesh(Vector3(4.0, 13.0, 4.0), stone), Vector3(x, 6.5, 0), Vector3.ONE, 90.0)
	_add_mesh(root, "TitanHeader", _box_mesh(Vector3(16.0, 2.3, 4.2), accent), Vector3(0, 12.0, 0), Vector3.ONE, 90.0)

func _add_landmark_totem_pair(node_name: String, position: Vector3, wood: Material, gold: Material) -> void:
	var root := _landmark_root(node_name, position, _background)
	for z in [-5.0, 5.0]:
		_add_mesh(root, "Totem", _cylinder_mesh(1.3, 1.7, 12.0, wood), Vector3(0, 6.0, z), Vector3.ONE, 85.0)
		_add_mesh(root, "TotemCrown", _sphere_mesh(gold, 10, 5), Vector3(0, 12.0, z), Vector3(1.8, 1.3, 1.8), 85.0)

func _add_landmark_champion_dais(node_name: String, position: Vector3, stone: Material, gold: Material) -> void:
	var root := _landmark_root(node_name, position, _background)
	_add_mesh(root, "ChampionBase", _cylinder_mesh(4.2, 5.0, 1.2, stone), Vector3(0, 0.6, 0), Vector3.ONE, 80.0)
	_add_mesh(root, "ChampionCrown", _torus_mesh(gold), Vector3(0, 5.0, 0), Vector3(3.0, 1.1, 3.0), 80.0)
	for i in range(5):
		var angle := TAU * float(i) / 5.0
		_add_mesh(root, "CrownPoint", _cone_mesh(gold), Vector3(cos(angle) * 2.5, 7.0, sin(angle) * 2.5), Vector3(0.75, 2.2, 0.75), 80.0)

func _add_arena_impact_marks() -> void:
	var mark_mat := _mat(Color("3b2a22"), 0.96)
	for i in range(9):
		var angle := TAU * float(i) / 9.0
		var radius := 12.0 + float(i % 3) * 2.0
		var mark := _add_mesh(_gameplay, "ImpactMark", _cylinder_mesh(0.8, 1.8, 0.035, mark_mat), Vector3(cos(angle) * radius, 0.06, sin(angle) * radius), Vector3.ONE, 44.0)
		mark.rotation.y = angle

# -----------------------------------------------------------------------------
# ROUND 5 — NEON NIGHT FESTIVAL
# -----------------------------------------------------------------------------

func _build_neon_festival() -> void:
	var navy := _mat(Color("17223a"), 0.76)
	var metal: Material = WildDashEnvironmentMaterialLibrary.get_palette().get(&"metal")
	var cyan := _emissive(Color("24d8ee"), 1.6, 0.42)
	var magenta := _emissive(Color("e23de8"), 1.6, 0.42)
	var amber := _emissive(Color("ffae3b"), 1.25, 0.52)
	_add_neon_light_multimesh(_background, "HarborFestivalLights", 72, Vector3(0, 8, -160), Vector3(84, 18, 330), cyan, magenta, 120.0)
	_add_container_multimesh(_background, "HarborContainers", 34, Vector3(0, 0, -170), Vector3(86, 0, 340), metal, navy, 125.0)
	_add_landmark_neon_tower("Landmark_HoloHarborTower", Vector3(-35, 0, -80), navy, cyan, magenta)
	_add_landmark_harbor_crane("Landmark_FestivalCrane", Vector3(38, 0, -210), metal, amber)
	_add_landmark_finish_festival("Landmark_FinalFestival", Vector3(-30, 0, -340), navy, cyan, magenta)
	_add_wet_side_puddles(cyan)
	_add_city_silhouette(_far_background, "CitySilhouette", Vector3(0, 0, -410), navy, cyan, 230.0)

func _add_landmark_neon_tower(node_name: String, position: Vector3, building: Material, cyan: Material, magenta: Material) -> void:
	var root := _landmark_root(node_name, position, _background)
	_add_mesh(root, "HoloTower", _box_mesh(Vector3(8.0, 28.0, 8.0), building), Vector3(0, 14, 0), Vector3.ONE, 160.0)
	for y in [6.0, 13.0, 20.0, 27.0]:
		_add_mesh(root, "NeonBand", _torus_mesh(cyan if int(y) % 2 == 0 else magenta), Vector3(0, y, 0), Vector3(8.5, 0.8, 8.5), 160.0)

func _add_landmark_harbor_crane(node_name: String, position: Vector3, metal: Material, light: Material) -> void:
	var root := _landmark_root(node_name, position, _background)
	_add_mesh(root, "CraneMast", _box_mesh(Vector3(2.2, 25.0, 2.2), metal), Vector3(0, 12.5, 0), Vector3.ONE, 175.0)
	_add_mesh(root, "CraneArm", _box_mesh(Vector3(20.0, 1.5, 1.7), metal), Vector3(-7.0, 24.0, 0), Vector3.ONE, 175.0)
	_add_mesh(root, "CraneLight", _sphere_mesh(light, 10, 5), Vector3(-16.0, 23.5, 0), Vector3(0.7, 0.7, 0.7), 175.0)

func _add_landmark_finish_festival(node_name: String, position: Vector3, building: Material, cyan: Material, magenta: Material) -> void:
	var root := _landmark_root(node_name, position, _background)
	for x in [-7.0, 7.0]:
		_add_mesh(root, "FestivalPylon", _box_mesh(Vector3(2.4, 15.0, 2.4), building), Vector3(x, 7.5, 0), Vector3.ONE, 185.0)
		_add_mesh(root, "PylonGlow", _box_mesh(Vector3(2.7, 0.35, 2.7), cyan), Vector3(x, 12.0, 0), Vector3.ONE, 185.0)
	_add_mesh(root, "FinaleBoard", _box_mesh(Vector3(16.0, 4.0, 0.5), magenta), Vector3(0, 14.0, 0), Vector3.ONE, 185.0)

func _add_wet_side_puddles(reflection_mat: Material) -> void:
	var wet := _mat(Color("223b4a"), 0.18)
	for i in range(12):
		var side := -1.0 if i % 2 == 0 else 1.0
		var puddle := _add_mesh(_gameplay, "WetRoadEdgeReflection", _cylinder_mesh(1.1, 2.8, 0.025, wet), Vector3(side * (14.0 + float(i % 3) * 3.0), 0.04, -34.0 - float(i) * 28.0), Vector3.ONE, 64.0)
		puddle.rotation.y = float(i) * 0.21
		_add_mesh(_gameplay, "WetNeonGlint", _box_mesh(Vector3(2.4, 0.025, 0.18), reflection_mat), puddle.position + Vector3(0, 0.03, 0), Vector3.ONE, 58.0)

# -----------------------------------------------------------------------------
# Repeated decoration / performance helpers
# -----------------------------------------------------------------------------

func _add_grass_multimesh(parent: Node3D, node_name: String, count: int, center: Vector3, extents: Vector3, material: Material, visibility_end: float) -> void:
	var mesh := _cone_mesh(material)
	_add_scatter_multimesh(parent, node_name, mesh, count, center, extents, Vector3(0.10, 0.55, 0.10), visibility_end, true)

func _add_leaf_multimesh(parent: Node3D, node_name: String, count: int, center: Vector3, extents: Vector3, material: Material, visibility_end: float) -> void:
	var mesh := _sphere_mesh(material, 8, 4)
	_add_scatter_multimesh(parent, node_name, mesh, count, center, extents, Vector3(0.55, 0.22, 0.42), visibility_end, true)

func _add_fern_multimesh(parent: Node3D, node_name: String, count: int, center: Vector3, extents: Vector3, material: Material, visibility_end: float) -> void:
	var mesh := _cone_mesh(material)
	_add_scatter_multimesh(parent, node_name, mesh, count, center, extents, Vector3(0.22, 0.72, 0.22), visibility_end, true)

func _add_mushroom_multimesh(parent: Node3D, node_name: String, count: int, center: Vector3, extents: Vector3, material: Material, visibility_end: float) -> void:
	var mesh := _sphere_mesh(material, 8, 4)
	_add_scatter_multimesh(parent, node_name, mesh, count, center, extents, Vector3(0.42, 0.20, 0.42), visibility_end, true)

func _add_magic_light_multimesh(parent: Node3D, node_name: String, count: int, center: Vector3, extents: Vector3, material: Material, visibility_end: float) -> void:
	var mesh := _sphere_mesh(material, 8, 4)
	_add_scatter_multimesh(parent, node_name, mesh, count, center, extents, Vector3(0.11, 0.11, 0.11), visibility_end, false)

func _add_neon_light_multimesh(parent: Node3D, node_name: String, count: int, center: Vector3, extents: Vector3, cyan: Material, _magenta: Material, visibility_end: float) -> void:
	var mesh := _box_mesh(Vector3(0.18, 1.7, 0.18), cyan)
	_add_scatter_multimesh(parent, node_name, mesh, count, center, extents, Vector3.ONE, visibility_end, false)

func _add_rock_multimesh(parent: Node3D, node_name: String, count: int, center: Vector3, extents: Vector3, material: Material, visibility_end: float) -> void:
	var mesh := _sphere_mesh(material, 8, 4)
	_add_scatter_multimesh(parent, node_name, mesh, count, center, extents, Vector3(1.8, 0.9, 1.5), visibility_end, true)

func _add_flag_multimesh(parent: Node3D, node_name: String, count: int, center: Vector3, extents: Vector3, material: Material, visibility_end: float) -> void:
	var mesh := _box_mesh(Vector3(0.7, 1.0, 0.08), material)
	_add_scatter_multimesh(parent, node_name, mesh, count, center, extents, Vector3.ONE, visibility_end, false)

func _add_container_multimesh(parent: Node3D, node_name: String, count: int, center: Vector3, extents: Vector3, material_a: Material, _material_b: Material, visibility_end: float) -> void:
	var mesh := _box_mesh(Vector3(5.8, 2.6, 2.5), material_a)
	_add_scatter_multimesh(parent, node_name, mesh, count, center, extents, Vector3.ONE, visibility_end, true)

func _add_totem_multimesh(parent: Node3D, node_name: String, count: int, center: Vector3, radius: float, wood: Material, _accent: Material, visibility_end: float) -> void:
	var mesh := _cylinder_mesh(0.48, 0.68, 4.6, wood)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = count
	for i in range(count):
		var angle := TAU * float(i) / float(count)
		var transform := Transform3D(Basis.IDENTITY, center + Vector3(cos(angle) * radius, 2.3, sin(angle) * radius))
		multi.set_instance_transform(i, transform)
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.visibility_range_end = visibility_end
	parent.add_child(instance)
	_multimesh_instances += count

func _add_scatter_multimesh(parent: Node3D, node_name: String, mesh: Mesh, count: int, center: Vector3, extents: Vector3, base_scale: Vector3, visibility_end: float, perimeter_bias: bool) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = count
	for i in range(count):
		var x := _rng.randf_range(-extents.x * 0.5, extents.x * 0.5)
		var z := _rng.randf_range(-extents.z * 0.5, extents.z * 0.5)
		if perimeter_bias and absf(x) < extents.x * 0.20:
			x += signf(x if absf(x) > 0.01 else (1.0 if i % 2 == 0 else -1.0)) * extents.x * 0.28
		var y := center.y + _rng.randf_range(-extents.y * 0.5, extents.y * 0.5)
		var rotation := Basis(Vector3.UP, _rng.randf_range(-PI, PI))
		var scale_jitter := _rng.randf_range(0.75, 1.32)
		rotation = rotation.scaled(base_scale * scale_jitter)
		multi.set_instance_transform(i, Transform3D(rotation, Vector3(center.x + x, y, center.z + z)))
	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multi
	instance.visibility_range_end = visibility_end
	parent.add_child(instance)
	_multimesh_instances += count

# -----------------------------------------------------------------------------
# Background silhouette helpers
# -----------------------------------------------------------------------------

func _add_far_hills(parent: Node3D, node_name: String, center: Vector3, count: int, color: Color, visibility_end: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = center
	parent.add_child(root)
	var material := _mat(color, 0.96)
	for i in range(count):
		var x := (float(i) - float(count - 1) * 0.5) * 24.0
		_add_mesh(root, "Hill", _sphere_mesh(material, 8, 4), Vector3(x, 0, 0), Vector3(17.0, 8.0 + float(i % 3) * 2.0, 12.0), visibility_end)

func _add_far_forest(parent: Node3D, node_name: String, center: Vector3, count: int, color: Color, visibility_end: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = center
	parent.add_child(root)
	var material := _mat(color, 0.94)
	for i in range(count):
		var x := (float(i) - float(count - 1) * 0.5) * 12.0
		var h := 24.0 + float(i % 5) * 5.0
		_add_mesh(root, "AncientTree", _cylinder_mesh(1.8, 3.0, h, material), Vector3(x, h * 0.5, 0), Vector3.ONE, visibility_end)

func _add_city_silhouette(parent: Node3D, node_name: String, center: Vector3, building: Material, light: Material, visibility_end: float) -> void:
	var root := Node3D.new()
	root.name = node_name
	root.position = center
	parent.add_child(root)
	for i in range(15):
		var x := (float(i) - 7.0) * 13.0
		var h := 18.0 + float((i * 7) % 5) * 7.0
		_add_mesh(root, "SkylineBlock", _box_mesh(Vector3(10.0, h, 9.0), building), Vector3(x, h * 0.5, 0), Vector3.ONE, visibility_end)
		_add_mesh(root, "SkylineLight", _box_mesh(Vector3(6.0, 0.35, 0.25), light), Vector3(x, h * 0.72, -4.7), Vector3.ONE, visibility_end)

# -----------------------------------------------------------------------------
# Shared mesh/material helpers. No collision nodes are created in this file.
# -----------------------------------------------------------------------------

func _landmark_root(node_name: String, position: Vector3, parent: Node3D) -> Node3D:
	var root := Node3D.new()
	root.name = node_name
	root.position = position
	root.set_meta("graphics_phase2_landmark", true)
	parent.add_child(root)
	_landmark_count += 1
	return root

func _add_mesh(parent: Node3D, node_name: String, mesh: Mesh, position: Vector3, scale_value: Vector3, visibility_end: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = node_name
	node.mesh = mesh
	node.position = position
	node.scale = scale_value
	node.visibility_range_end = visibility_end
	parent.add_child(node)
	return node

func _mat(color: Color, roughness: float = 0.82, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material

func _emissive(color: Color, energy: float, roughness: float) -> StandardMaterial3D:
	var material := _mat(color, roughness)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = energy
	return material

func _transparent_emissive(color: Color, energy: float) -> StandardMaterial3D:
	var material := _emissive(Color(color.r, color.g, color.b, 1.0), energy, 0.72)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material

func _box_mesh(size: Vector3, material: Material) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	return mesh

func _sphere_mesh(material: Material, radial: int, rings: int) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1.0
	mesh.radial_segments = radial
	mesh.rings = rings
	mesh.material = material
	return mesh

func _cylinder_mesh(top_radius: float, bottom_radius: float, height: float, material: Material) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	mesh.material = material
	return mesh

func _cone_mesh(material: Material) -> CylinderMesh:
	return _cylinder_mesh(0.0, 0.5, 1.0, material)

func _torus_mesh(material: Material) -> TorusMesh:
	var mesh := TorusMesh.new()
	mesh.inner_radius = 0.38
	mesh.outer_radius = 0.50
	mesh.rings = 12
	mesh.ring_segments = 8
	mesh.material = material
	return mesh
