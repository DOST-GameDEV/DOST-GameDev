extends RefCounted
class_name CharacterRoster


const MODEL_DIR: String = "res://assets/characters/persons/"
const MATERIAL_DIR: String = "res://assets/characters/persons/materials/"

const TRAIT_MIN: int = 1
const TRAIT_MAX: int = 5
const TRAIT_NEUTRAL: int = 3

const NAME_MAX: int = SettingsManagerScript.PLAYER_NAME_MAX

const TRAIT_LABELS_PERSON: Array[Dictionary] = [
	{"key": &"bilis", "name": "SPEED", "gloss": ""},
	{"key": &"lakas", "name": "POWER", "gloss": ""},
	{"key": &"tatag", "name": "GRIT", "gloss": ""},
]

const TRAIT_LABELS_LATA: Array[Dictionary] = [
	{"key": &"bilis", "name": "RESET", "gloss": ""},
	{"key": &"lakas", "name": "REBOUND", "gloss": ""},
	{"key": &"tatag", "name": "STANCE", "gloss": ""},
]

const TRAIT_LABELS_TSINELAS: Array[Dictionary] = [
	{"key": &"bilis", "name": "FLIGHT", "gloss": ""},
	{"key": &"lakas", "name": "IMPACT", "gloss": ""},
	{"key": &"tatag", "name": "RECOVERY", "gloss": ""},
]

const ROSTER: Array[Dictionary] = [
	{
		"id": &"berto",
		"name": "BERTO",
		"tagline": "The original defender. Immovable, unhurriable, and still standing exactly where you left him.",
		"traits": {&"bilis": 2, &"lakas": 4, &"tatag": 5},
		"model": MODEL_DIR + "character-male-f.glb",
		"material": MATERIAL_DIR + "person_a.tres",
	},
	{
		"id": &"maring",
		"name": "MARING",
		"tagline": "Quick hands, quicker mouth. She has talked her way out of more tags than she has dodged.",
		"traits": {&"bilis": 5, &"lakas": 2, &"tatag": 2},
		"model": MODEL_DIR + "character-female-f.glb",
		"material": MATERIAL_DIR + "person_b.tres",
	},
	{
		"id": &"totoy",
		"name": "TOTOY",
		"tagline": "Raised barefoot in the eskinita. Nobody in this town has caught him twice.",
		"traits": {&"bilis": 5, &"lakas": 2, &"tatag": 3},
		"model": MODEL_DIR + "character-male-a.glb",
		"material": MATERIAL_DIR + "person_totoy.tres",
	},
	{
		"id": &"inday",
		"name": "INDAY",
		"tagline": "Minds the corner stall and is afraid of absolutely nothing that walks past it.",
		"traits": {&"bilis": 3, &"lakas": 4, &"tatag": 4},
		"model": MODEL_DIR + "character-female-a.glb",
		"material": MATERIAL_DIR + "person_inday.tres",
	},
	{
		"id": &"kuya_boy",
		"name": "KUYA BOY",
		"tagline": "Eldest of seven. He has been the taya since before he could count, and both the arm and the footwork know it.",
		"traits": {&"bilis": 3, &"lakas": 5, &"tatag": 3},
		"model": MODEL_DIR + "character-male-b.glb",
		"material": MATERIAL_DIR + "person_kuya-boy.tres",
	},
	{
		"id": &"ate_girlie",
		"name": "ATE GIRLIE",
		"tagline": "Queen of patintero, slumming it at tumbang preso. The footwork came with her.",
		"traits": {&"bilis": 4, &"lakas": 3, &"tatag": 3},
		"model": MODEL_DIR + "character-female-b.glb",
		"material": MATERIAL_DIR + "person_ate-girlie.tres",
	},
	{
		"id": &"tikboy",
		"name": "TIKBOY",
		"tagline": "Always down to one tsinelas. Half the footwear, twice the throwing arm.",
		"traits": {&"bilis": 4, &"lakas": 4, &"tatag": 2},
		"model": MODEL_DIR + "character-male-c.glb",
		"material": MATERIAL_DIR + "person_tikboy.tres",
	},
	{
		"id": &"bebang",
		"name": "BEBANG",
		"tagline": "Hits like a jeepney door closing, and moves about as easily. Do not tease her about it, and do not stand in front of her.",
		"traits": {&"bilis": 2, &"lakas": 5, &"tatag": 5},
		"model": MODEL_DIR + "character-female-c.glb",
		"material": MATERIAL_DIR + "person_bebang.tres",
	},
	{
		"id": &"jun_jun",
		"name": "JUN-JUN",
		"tagline": "The bunso of the street. Small, slippery, and impossible to corner. Also impossible to keep upright.",
		"traits": {&"bilis": 5, &"lakas": 1, &"tatag": 2},
		"model": MODEL_DIR + "character-male-d.glb",
		"material": MATERIAL_DIR + "person_jun-jun.tres",
	},
	{
		"id": &"lola_pacing",
		"name": "LOLA PACING",
		"tagline": "Watches from the window most afternoons. On the good ones she comes down to play, and she does not miss twice.",
		"traits": {&"bilis": 1, &"lakas": 4, &"tatag": 5},
		"model": MODEL_DIR + "character-female-d.glb",
		"material": MATERIAL_DIR + "person_lola-pacing.tres",
	},
	{
		"id": &"mang_kanor",
		"name": "MANG KANOR",
		"tagline": "Tricycle driver. He knows every corner of this town by its potholes and he takes them at speed. Braking was never the strong suit.",
		"traits": {&"bilis": 5, &"lakas": 3, &"tatag": 2},
		"model": MODEL_DIR + "character-male-e.glb",
		"material": MATERIAL_DIR + "person_mang-kanor.tres",
	},
	{
		"id": &"aling_nena",
		"name": "ALING NENA",
		"tagline": "She owns the sari-sari store, so she owns the rules. Nobody has ever argued a call twice.",
		"traits": {&"bilis": 2, &"lakas": 3, &"tatag": 5},
		"model": MODEL_DIR + "character-female-e.glb",
		"material": MATERIAL_DIR + "person_aling-nena.tres",
	},
]



const CANS: Array[Dictionary] = [
	{
		"id": &"pasip",
		"name": "PASIP",
		"tagline": "Softdrink na hindi Pepsi. Tall, thin and empty — it goes over if you look at it hard, and it is back up before you have turned around.",
		"traits": {&"bilis": 5, &"lakas": 1, &"tatag": 1},
		"model": "res://assets/models/lata_pasip.obj",
		"tint": Color.WHITE,
	},
	{
		"id": &"boyben",
		"name": "BOYBEN",
		"tagline": "Leftover fence paint, half set solid. Nothing on the mark stands its ground like it does — but righting it is a proper job.",
		"traits": {&"bilis": 1, &"lakas": 3, &"tatag": 5},
		"model": "res://assets/models/lata_boyben.obj",
		"tint": Color.WHITE,
	},
	{
		"id": &"decades",
		"name": "DECADES TUNA",
		"tagline": "Flakes in oil from Aling Nena's. Squat and low, so tipping it is the hard part — and setting it back up is barely a motion.",
		"traits": {&"bilis": 4, &"lakas": 1, &"tatag": 4},
		"model": "res://assets/models/lata_decades.obj",
		"tint": Color.WHITE,
	},
	{
		"id": &"metal",
		"name": "KALAWANG",
		"tagline": "No label left, just ribs and rust. Heavy for its size — it sends the tsinelas across the street, and it is slow to stand back up.",
		"traits": {&"bilis": 2, &"lakas": 5, &"tatag": 3},
		"model": "res://assets/models/lata_metal.obj",
		"tint": Color.WHITE,
	},
]

const SLIPPERS: Array[Dictionary] = [
	{
		"id": &"tsinelas",
		"name": "TSINELAS",
		"tagline": "Plain rubber, one peso of it. Every child on this street has thrown a pair, and it does everything well enough.",
		"traits": {&"bilis": 3, &"lakas": 3, &"tatag": 3},
		"model": "res://assets/models/tsinelas_classic.obj",
		"tint": Color.WHITE,
	},
	{
		"id": &"crocs",
		"name": "CROCS",
		"tagline": "Holes in the top, strap at the back. Heavy and it does not fly straight — but whoever body-blocks it knows all about it.",
		"traits": {&"bilis": 2, &"lakas": 5, &"tatag": 2},
		"model": "res://assets/models/tsinelas_crocs.obj",
		"tint": Color.WHITE,
	},
	{
		"id": &"pantulog",
		"name": "PANTULOG",
		"tagline": "Lola's house slipper, worn soft. No weight behind it at all, but it is ready again before the taya has turned around.",
		"traits": {&"bilis": 3, &"lakas": 1, &"tatag": 5},
		"model": "res://assets/models/tsinelas_pantulog.obj",
		"tint": Color.WHITE,
	},
	{
		"id": &"sike",
		"name": "IKE",
		"tagline": "Definitely not the real brand. Light, loud, and the quickest thing off a hand on this street.",
		"traits": {&"bilis": 4, &"lakas": 2, &"tatag": 3},
		"model": "res://assets/models/tsinelas_sike.obj",
		"tint": Color.WHITE,
	},
]

static func slipper_launch_speed(index: int) -> float:
	if index < 0 or index >= SLIPPERS.size():
		return -1.0
	return Slipper.LAUNCH_SPEED * trait_scale(
		slipper_trait(index, &"bilis"), CharacterBase.TRAIT_SPEED_PER_POINT)

const CATEGORIES: Array[Dictionary] = [
	{"id": &"person", "label": "PERSON",   "slot": &"character", "entries": ROSTER,
		"traits": TRAIT_LABELS_PERSON},
	{"id": &"can",    "label": "LATA",     "slot": &"can",       "entries": CANS,
		"traits": TRAIT_LABELS_LATA},
	{"id": &"slipper","label": "TSINELAS", "slot": &"slipper",   "entries": SLIPPERS,
		"traits": TRAIT_LABELS_TSINELAS},
]


static func category(index: int) -> Dictionary:
	return CATEGORIES[posmod(index, CATEGORIES.size())]

static func entries_for(category_index: int) -> Array:
	return category(category_index)["entries"]

static func trait_labels(category_index: int) -> Array:
	return category(category_index)["traits"]

static func prop_at(entries: Array, index: int) -> Dictionary:
	if entries.is_empty():
		return {}
	return entries[posmod(index, entries.size())]

static func can_at(index: int) -> Dictionary:
	return prop_at(CANS, index)

static func slipper_at(index: int) -> Dictionary:
	return prop_at(SLIPPERS, index)

static func index_in(entries: Array, id: StringName) -> int:
	for i in range(entries.size()):
		if entries[i]["id"] == id:
			return i
	return -1

static func size() -> int:
	return ROSTER.size()

static func at(index: int) -> Dictionary:
	if ROSTER.is_empty():
		return {}
	return ROSTER[posmod(index, ROSTER.size())]

static func index_of(id: StringName) -> int:
	for i in range(ROSTER.size()):
		if ROSTER[i]["id"] == id:
			return i
	return -1

static func name_at(index: int) -> String:
	var entry := at(index)
	return String(entry["name"]) if entry.has("name") else "?"




static func traits_in(entries: Array, index: int) -> Dictionary:
	if index < 0 or index >= entries.size():
		return {}
	var entry: Dictionary = entries[index]
	return entry.get("traits", {})

static func person_trait(index: int, key: StringName) -> int:
	return _trait_value(traits_in(ROSTER, index), key)

static func can_trait(index: int, key: StringName) -> int:
	return _trait_value(traits_in(CANS, index), key)

static func slipper_trait(index: int, key: StringName) -> int:
	return _trait_value(traits_in(SLIPPERS, index), key)

static func prop_trait(can_index: int, slipper_index: int, is_can: bool, key: StringName) -> int:
	return can_trait(can_index, key) if is_can else slipper_trait(slipper_index, key)

static func trait_scale(points: int, per_point: float) -> float:
	return 1.0 + float(clampi(points, TRAIT_MIN, TRAIT_MAX) - TRAIT_NEUTRAL) * per_point

static func _trait_value(traits: Dictionary, key: StringName) -> int:
	if traits.is_empty() or not traits.has(key):
		return TRAIT_NEUTRAL
	return clampi(int(traits[key]), TRAIT_MIN, TRAIT_MAX)

