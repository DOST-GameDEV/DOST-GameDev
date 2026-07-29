extends RefCounted
class_name CharacterRoster

## THE CHARACTER-SELECT ROSTER — the single place a playable character is named.
##
## Same job `GameLaunch.MAPS` does for maps, and deliberately the same shape, so
## adding a character is one entry here and nothing else: the select screen, the
## live 3D preview, the spawn path and `character_visual.gd` all read this list
## and none of them holds its own copy.
##
## A CHARACTER IS A RIG PLUS A PALETTE, NOT A NEW MODEL.
##
## Human instruction, 2026-07-29: "dont create other models use existing ones, js
## edit these models". Every entry below wears one of the twelve CC0 Kenney rigs
## already in `assets/characters/persons/` and differs only in its palette .tres
## — which is exactly the mechanism checklist 2.3 / M-5 built
## `person_palette.gdshader` for ("recolouring a Person is 16 colours in a .tres
## — text, diffable, no binary, and the CC0 .glb stays pristine").
##
## The palettes are GENERATED — `tools/models/generate_person_palettes.py`. Edit
## that and re-run it; do not hand-edit a `person_*.tres`, and do not add an
## entry here whose palette that script does not emit.
##
## ⚠️ WHY THIS COSTS NOTHING IN FPP/CAMERA WORK. Because a roster character is
## the same .glb with a different material, everything ever tuned against a
## Person applies to all of them by construction rather than per character:
## camera_rig.gd's self-hide walks `Visual`'s GeometryInstance3D children by type
## and never names a mesh; the 1.25 eye, the 1.6 capsule and the viewmodel arms
## belong to the Person ROLE, not to a model; and
## `character_visual.gd::_align_to_capsule_floor` MEASURES the instanced model
## rather than assuming its height, so no pick can float or sink. Adding a
## character cannot regress any of it.
##
## ⚠️ INDEX ORDER IS PART OF THE NETWORK CONTRACT. `CharacterBase.character_index`
## is replicated as an int (see CharacterBase.tscn's SceneReplicationConfig), so
## every peer must resolve the same index to the same entry. APPEND new
## characters; never reorder or delete, or two peers on different builds will
## quietly render different people. `id` is the stable key for anything saved to
## disk; the index is only ever a wire format.

const MODEL_DIR: String = "res://assets/characters/persons/"
const MATERIAL_DIR: String = "res://assets/characters/persons/materials/"

## ⚠️ THE FIRST TWO ARE THE SIGNED-OFF MATCH PERSONS AND MUST STAY AT 0 AND 1.
## `character_visual.gd` falls back to `PERSON_MODELS[team]` when a unit has no
## roster pick (an AI slot, or a peer on an older build), and Art_Direction.md
## pins these two specifically: they are the pair chosen to read apart at arena
## distance on the two things visible from there — ginger hair against dark, and
## a black/yellow outfit against green. They point at the hand-authored
## person_a/person_b materials, which `generate_person_palettes.py` deliberately
## does NOT emit.
const ROSTER: Array[Dictionary] = [
	{
		"id": &"berto",
		"name": "BERTO",
		"tagline": "Ang orihinal na taya. Matigas ang ulo.",
		"model": MODEL_DIR + "character-male-f.glb",
		"material": MATERIAL_DIR + "person_a.tres",
	},
	{
		"id": &"maring",
		"name": "MARING",
		"tagline": "Mabilis ang kamay. Mas mabilis ang bibig.",
		"model": MODEL_DIR + "character-female-f.glb",
		"material": MATERIAL_DIR + "person_b.tres",
	},
	{
		"id": &"totoy",
		"name": "TOTOY",
		"tagline": "Palaboy ng eskinita. Mabilis tumakbo.",
		"model": MODEL_DIR + "character-male-a.glb",
		"material": MATERIAL_DIR + "person_totoy.tres",
	},
	{
		"id": &"inday",
		"name": "INDAY",
		"tagline": "Tindera sa kanto. Walang takot.",
		"model": MODEL_DIR + "character-female-a.glb",
		"material": MATERIAL_DIR + "person_inday.tres",
	},
	{
		"id": &"kuya_boy",
		"name": "KUYA BOY",
		"tagline": "Panganay. Siya ang taya, lagi.",
		"model": MODEL_DIR + "character-male-b.glb",
		"material": MATERIAL_DIR + "person_kuya-boy.tres",
	},
	{
		"id": &"ate_girlie",
		"name": "ATE GIRLIE",
		"tagline": "Reyna ng patintero. Ngayon, tumbang preso.",
		"model": MODEL_DIR + "character-female-b.glb",
		"material": MATERIAL_DIR + "person_ate-girlie.tres",
	},
	{
		"id": &"tikboy",
		"name": "TIKBOY",
		"tagline": "Laging may tsinelas na isa lang.",
		"model": MODEL_DIR + "character-male-c.glb",
		"material": MATERIAL_DIR + "person_tikboy.tres",
	},
	{
		"id": &"bebang",
		"name": "BEBANG",
		"tagline": "Malakas ang tama. Wag mo lang asarin.",
		"model": MODEL_DIR + "character-female-c.glb",
		"material": MATERIAL_DIR + "person_bebang.tres",
	},
	{
		"id": &"jun_jun",
		"name": "JUN-JUN",
		"tagline": "Bunso. Maliit pero mailap.",
		"model": MODEL_DIR + "character-male-d.glb",
		"material": MATERIAL_DIR + "person_jun-jun.tres",
	},
	{
		"id": &"lola_pacing",
		"name": "LOLA PACING",
		"tagline": "Nanonood sa may bintana. Minsan sumasali.",
		"model": MODEL_DIR + "character-female-d.glb",
		"material": MATERIAL_DIR + "person_lola-pacing.tres",
	},
	{
		"id": &"mang_kanor",
		"name": "MANG KANOR",
		"tagline": "Tricycle driver. Alam ang bawat kanto.",
		"model": MODEL_DIR + "character-male-e.glb",
		"material": MATERIAL_DIR + "person_mang-kanor.tres",
	},
	{
		"id": &"aling_nena",
		"name": "ALING NENA",
		"tagline": "May-ari ng sari-sari. Siya ang referee.",
		"model": MODEL_DIR + "character-female-e.glb",
		"material": MATERIAL_DIR + "person_aling-nena.tres",
	},
]

## ---------------------------------------------------------------------------
## THE OTHER TWO TABS — the lata and the tsinelas.
##
## Every player controls a Person AND a Prop, and the Prop is a lata one round
## and a tsinelas the next (`is_can` flips every round — see
## `main.gd::_reset_world`). So a player picks THREE things, not one, and the
## CHARACTER screen has three tabs rather than one list.
##
## ⚠️ THESE ARE TINTS, NOT MODELS, FOR THE SAME REASON THE PERSONS ARE PALETTES.
## The lata is `kits/food/soda-can.glb` and the tsinelas is the project's own
## generated `tsinelas.obj`; both keep their geometry and both are recoloured
## through the toon material `_apply_toon_pass()` already builds for every Prop.
## `albedo_color` on that shader means exactly "what colour am I" — the hit flash
## drives a separate `flash_amount` uniform (see character_visual.gd::flash_hit's
## own 7.1 note) — so writing it is safe and cannot break the flash.
##
## ⚠️ NO BRANDS, NO WORDMARKS, NO LOGOS. Filipino-themed by COLOUR and by the
## everyday Tagalog name for the thing, which is what actually reads as local at
## arena distance. A sari-sari store's shelf is recognisable from its colours
## across a street; nothing here reproduces anyone's trademark, and no roster
## entry renders text.
##
## ⚠️ AND THEY STAY INSIDE THE PROP PALETTE'S RULES. `ui_theme.gd`'s PROP_* block
## says a hero prop may be more saturated than any ENV_* colour — it is the
## most-looked-at object in the game and has to read against asphalt — but must
## never go near `OFFENSE` #f87020 or `DEFENSE` #0080e8 in hue, because those two
## mean "which side is this". Every tint below clears that bar.

const CANS: Array[Dictionary] = [
	{
		"id": &"sarsi",
		"name": "SARSILYA",
		"tagline": "Ang klasikong lata. Pula, matigas, maingay.",
		# The signed-off default — UiTheme.PROP_SARSI_RED, so the stock lata is
		# entry 0 and an unpicked Prop looks exactly as it always has.
		"tint": Color("d8221c"),
	},
	{
		"id": &"gatas",
		"name": "LATA NG GATAS",
		"tagline": "Kondensada. Maliit pero matigas ang ulo.",
		"tint": Color("2f6ea8"),
	},
	{
		"id": &"sardinas",
		"name": "LATA NG SARDINAS",
		"tagline": "Galing sa tindahan ni Aling Nena.",
		"tint": Color("c8a02a"),
	},
	{
		"id": &"kape",
		"name": "LATA NG KAPE",
		"tagline": "Walang laman. Perpekto para tumbahin.",
		"tint": Color("7a4a24"),
	},
	{
		"id": &"pintura",
		"name": "LATA NG PINTURA",
		"tagline": "Tirang pintura sa bakuran. Kalawangin na.",
		"tint": Color("4f8c6a"),
	},
	{
		"id": &"biskwit",
		"name": "LATA NG BISKWIT",
		"tagline": "Ang lata ni Lola. Hindi na binalik ang biskwit.",
		"tint": Color("b0552a"),
	},
]

const SLIPPERS: Array[Dictionary] = [
	{
		"id": &"goma",
		"name": "TSINELAS NA GOMA",
		"tagline": "Basic na goma. Ang pambato ng bawat bata.",
		# UiTheme.PROP_FOAM — the signed-off default, so entry 0 is the stock look.
		"tint": Color("7a5741"),
	},
	{
		"id": &"bakya",
		"name": "BAKYA",
		"tagline": "Kahoy. Mabigat tumama, mahirap ihagis.",
		"tint": Color("8a5a2a"),
	},
	{
		"id": &"pula",
		"name": "TSINELAS NA PULA",
		"tagline": "Pang-simbahan. Ginagamit pa rin panghagis.",
		"tint": Color("a83a3a"),
	},
	{
		"id": &"asul",
		"name": "TSINELAS NA ASUL",
		"tagline": "Kupas na sa araw. Paborito pa rin.",
		"tint": Color("3a6a8a"),
	},
	{
		"id": &"dilaw",
		"name": "TSINELAS NA DILAW",
		"tagline": "Kita mo agad kahit saan lumapag.",
		"tint": Color("c9a52a"),
	},
	{
		"id": &"luma",
		"name": "TSINELAS NA LUMA",
		"tagline": "Nipis na ang suelas. Sentimental value.",
		"tint": Color("5c5248"),
	},
]

## The three tabs, in the order the screen shows them. A list rather than three
## hardcoded branches so `character_select.gd` cycles tabs the same way it cycles
## entries within one, and adding a fourth category later is one entry here.
##
## `slot` is which `GameLaunch` preference and which `CharacterBase` index this
## tab writes — named rather than positional so nothing depends on tab order.
const CATEGORIES: Array[Dictionary] = [
	{"id": &"person", "label": "TAO",      "slot": &"character", "entries": ROSTER},
	{"id": &"can",    "label": "LATA",     "slot": &"can",       "entries": CANS},
	{"id": &"slipper","label": "TSINELAS", "slot": &"slipper",   "entries": SLIPPERS},
]

static func category(index: int) -> Dictionary:
	return CATEGORIES[posmod(index, CATEGORIES.size())]

static func entries_for(category_index: int) -> Array:
	return category(category_index)["entries"]

## Wrapped lookup into one category's list — the CANS/SLIPPERS counterpart of
## `at()`, and non-asserting for the same reason: this is read on the spawn path
## from a replicated int.
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

## Entry at `index`, wrapped. Never returns null and never asserts: this is read
## on the spawn path from a replicated int, and a peer running a build with a
## shorter roster must render SOMEBODY rather than crash or show an empty Person.
static func at(index: int) -> Dictionary:
	if ROSTER.is_empty():
		return {}
	return ROSTER[posmod(index, ROSTER.size())]

## Index for a stable id, or -1. Used when restoring a saved preference, which is
## the one place an id — not an index — is the source of truth.
static func index_of(id: StringName) -> int:
	for i in range(ROSTER.size()):
		if ROSTER[i]["id"] == id:
			return i
	return -1

static func name_at(index: int) -> String:
	var entry := at(index)
	return String(entry["name"]) if entry.has("name") else "?"
