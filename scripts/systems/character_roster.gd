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
## ---------------------------------------------------------------------------
## TRAITS — three numbers per entry, 1 to 5, and 3 is the middle of the road.
##
## Human ask: *"give characters unique gameplay traits and stats (faster,
## stronger) that tie directly into their respective lore descriptions"* and
## *"find a creative way to visually show them on the character selection
## screen."* The second half is `character_select.gd`'s three chalk meters; this
## is the first half, and the rule that keeps it honest is:
##
##   ⚠️ THE NUMBER MUST BE READABLE OFF THE SENTENCE. If a description says
##   somebody is quick, BILIS is high. If it says they hit hard, LAKAS is high.
##   A stat nobody can predict from the lore is just a random modifier, and a
##   description nothing backs up is a lie the player finds out about in round 2.
##   The two are written together here, on the same line, for exactly that reason.
##
##   BILIS  · speed      how fast this unit walks.
##   LAKAS  · power      how hard its throws and body-checks land.
##   TATAG  · grit       how little it is moved and stunned by being hit.
##
## ⚠️ THE SPREAD IS DELIBERATELY NARROW. `CharacterBase.TRAIT_*_PER_POINT` turns
## a point into single-digit percentages, so the full 1..5 range spans roughly
## +/-10% on speed and +/-14% on power and grit. This is a party game about
## hitting a can with a slipper; a pick that is 40% faster than another pick is
## not a personality, it is the correct answer. Every entry is meant to stay
## playable and the differences are meant to be felt rather than counted.
##
## ⚠️ TOTALS ARE NOT BALANCED TO A FIXED BUDGET, ON PURPOSE. Lola Pacing is slow
## and tough and Jun-Jun is fast and fragile, but Bebang is genuinely a heavier
## pick than Jun-Jun overall — because "the small one is strictly equal to the
## big one once you add the numbers up" is a spreadsheet result, not a cast. The
## narrow spread above is what makes that affordable.
##
## Nothing in the game may read a raw number from here. Ask `CharacterBase`'s
## `trait_speed_scale()` / `trait_power_scale()` / `trait_grit_scale()` instead,
## so there is one conversion from points to multipliers.
const TRAIT_MIN: int = 1
const TRAIT_MAX: int = 5
const TRAIT_NEUTRAL: int = 3

## Display metadata for the meters on the CHARACTER screen.
##
## ⚠️ THESE WERE `BILIS` / `LAKAS` / `TATAG` WITH THE ENGLISH AS A GLOSS UNDERNEATH,
## and are now English outright — 🧑 human call, 2026-07-30: *"character stats
## should be english too."* The `gloss` field is kept and left EMPTY rather than
## removed: `character_select.gd` reads it, an empty string is the "no second
## line" case it already has to handle for a roster entry that never had one, and
## keeping the field means a future localisation has somewhere to put the
## Filipino reading back without a schema change.
##
## ⚠️ THE `key`s ARE UNCHANGED AND MUST STAY THAT WAY. They are the StringNames
## every trait lookup in the project indexes by (`trait_points(&"bilis")`, the
## `traits` dictionaries on all three roster lists, and `prop_trait`/`person_trait`);
## they are internal identifiers, not display text, and renaming them to match the
## label would be a silent flat-3 fallback on every entry — `traits_in()` returns
## the entry's dictionary and `_trait_value()` resolves a missing key to
## TRAIT_NEUTRAL without erroring. That is precisely the failure NET-1 is chasing.
const TRAIT_LABELS: Array[Dictionary] = [
	{"key": &"bilis", "name": "SPEED", "gloss": ""},
	{"key": &"lakas", "name": "POWER", "gloss": ""},
	{"key": &"tatag", "name": "GRIT", "gloss": ""},
]

## ---------------------------------------------------------------------------
## ⚠️ THE DESCRIPTIONS ARE ENGLISH AND THE NAMES ARE NOT. Human call: *"rewrite
## all descriptions to be in English, but keep the Filipino names."* The name is
## the character; the sentence is the joke, and a joke only lands in a language
## the reader is fluent in. Role words the game teaches on purpose (lata,
## tsinelas, eskinita, sari-sari) stay Filipino inside the English, which is how
## the words actually get learned.
##
## ⚠️ NO EM-DASHES ANYWHERE IN A DESCRIPTION, also on request. Use a full stop or
## a comma. This is checked by eye, not by a test, so do not add one.
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
		"tagline": "Eldest of seven. He has been the defender since before he could count, and his arm knows it.",
		"traits": {&"bilis": 2, &"lakas": 5, &"tatag": 4},
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
		"tagline": "Hits like a jeepney door closing. Do not tease her about it, and do not stand in front of her.",
		"traits": {&"bilis": 2, &"lakas": 5, &"tatag": 4},
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
		"tagline": "Watches from the window most afternoons. On the good ones she comes down to play, and she does not miss.",
		"traits": {&"bilis": 1, &"lakas": 3, &"tatag": 5},
		"model": MODEL_DIR + "character-female-d.glb",
		"material": MATERIAL_DIR + "person_lola-pacing.tres",
	},
	{
		"id": &"mang_kanor",
		"name": "MANG KANOR",
		"tagline": "Tricycle driver. He knows every corner of this town by its potholes, and he takes them at speed.",
		"traits": {&"bilis": 4, &"lakas": 3, &"tatag": 3},
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

## ⚠️ `ability` IS WHAT MAKES A PICK MECHANICAL, NOT JUST COSMETIC (3.3 / B-76).
## This roster began as appearance only — a rig and a palette — and the kit a Prop
## carried was still hardcoded per TEAM in `main.gd` (`TSINELAS_ABILITY_TEAM_A` /
## `_TEAM_B`), so the three Tsinelas throw identities were unreachable by choice
## and the two spare Can specials were unreachable at all.
##
## Attaching the kit to the SKIN, rather than adding a fourth and fifth picker,
## is deliberate. A player already picks a Can and a Slipper separately here, and
## the reason that split exists is the reason a paired "fighter" would not work:
## a Prop is a lata one round and a tsinelas the next, so its kit has to be
## re-picked on every role swap. These two lists already have exactly the right
## shape for that — `main.gd::_prop_ability_for()` asks the one that matches the
## side being played THIS round and gets the right answer without branching.
##
## ⚠️ SIX LOOKS, THREE KITS PER SIDE — two skins share each ability, because
## three `.tres` exist per side and six entries do not. Entry 0 of each list
## keeps TODAY'S behaviour (`quick_stand` / the light throw), so a player who
## never opens the screen is where they always were. The pairings follow the
## taglines that were already written here rather than being imposed on them:
## `bakya` is "kahoy, mabigat tumama" and gets Bakya Bash; `sardinas` names the
## ability Quick Stand is already called after; `pintura` is leftover rusting
## paint and gets Shatter Trap's hazard patch. **First pass, and a balance
## surface** — see the Phase 9 fairness log before moving any of them.

## ⚠️ A PROP'S TRAITS ARE READ THE SAME WAY A PERSON'S ARE, and they mean the
## same three things — but on an object rather than a player, which is where the
## lore has to do more work. A lata's BILIS is how quickly it can shuffle off its
## own mark; its TATAG is how well it shrugs off a hit that would send a lighter
## can rolling. A tsinelas' LAKAS rides on top of its ThrowProfile, so a heavy
## bakya is heavy twice over and that is intended: the profile decides HOW it
## flies, the trait decides how much it hurts when it arrives.
const CANS: Array[Dictionary] = [
	{
		"id": &"sarsi",
		"name": "SARSILYA",
		"tagline": "The classic. Red, stubborn, and loud enough that the whole street hears it go over.",
		"traits": {&"bilis": 3, &"lakas": 3, &"tatag": 3},
		"ability": "res://scripts/abilities/resources/quick_stand.tres",
		# The signed-off default — UiTheme.PROP_SARSI_RED, so the stock lata is
		# entry 0 and an unpicked Prop looks exactly as it always has. Its traits
		# are the neutral 3/3/3 for the same reason: a player who never opens the
		# CHARACTER screen must get the balance everything else was tuned against.
		"tint": Color("d8221c"),
	},
	{
		"id": &"gatas",
		"name": "LATA NG GATAS",
		"tagline": "Condensed milk, drunk years ago. Small, dense, and far harder to topple than it looks.",
		"traits": {&"bilis": 2, &"lakas": 3, &"tatag": 5},
		"ability": "res://scripts/abilities/resources/spin_guard.tres",
		"tint": Color("2f6ea8"),
	},
	{
		"id": &"sardinas",
		"name": "LATA NG SARDINAS",
		"tagline": "Straight off the shelf at Aling Nena's. Flat, wide, and it always lands on its feet.",
		"traits": {&"bilis": 3, &"lakas": 2, &"tatag": 4},
		"ability": "res://scripts/abilities/resources/quick_stand.tres",
		"tint": Color("c8a02a"),
	},
	{
		"id": &"kape",
		"name": "LATA NG KAPE",
		"tagline": "Completely empty, and it knows it. Skitters away from anything that comes near.",
		"traits": {&"bilis": 5, &"lakas": 2, &"tatag": 1},
		"ability": "res://scripts/abilities/resources/spin_guard.tres",
		"tint": Color("7a4a24"),
	},
	{
		"id": &"pintura",
		"name": "LATA NG PINTURA",
		"tagline": "Leftover paint from the fence, gone to rust. Heavy, mean, and it leaves a mess where it falls.",
		"traits": {&"bilis": 1, &"lakas": 5, &"tatag": 4},
		"ability": "res://scripts/abilities/resources/shatter_trap.tres",
		"tint": Color("4f8c6a"),
	},
	{
		"id": &"biskwit",
		"name": "LATA NG BISKWIT",
		"tagline": "Lola's biscuit tin. The biscuits never came back and neither will your throw.",
		"traits": {&"bilis": 2, &"lakas": 4, &"tatag": 4},
		"ability": "res://scripts/abilities/resources/shatter_trap.tres",
		"tint": Color("b0552a"),
	},
]

const SLIPPERS: Array[Dictionary] = [
	{
		"id": &"goma",
		"name": "TSINELAS NA GOMA",
		"tagline": "Plain rubber, one peso of it. Every child on this street has thrown a pair.",
		"traits": {&"bilis": 3, &"lakas": 3, &"tatag": 3},
		"ability": "res://scripts/abilities/resources/flick_dash.tres",
		# UiTheme.PROP_FOAM — the signed-off default, so entry 0 is the stock look
		# and the neutral 3/3/3, same contract as SARSILYA above.
		"tint": Color("7a5741"),
	},
	{
		"id": &"bakya",
		"name": "BAKYA",
		"tagline": "Solid wood. It lands like a dropped brick and it moves like one too.",
		"traits": {&"bilis": 1, &"lakas": 5, &"tatag": 5},
		"ability": "res://scripts/abilities/resources/bakya_bash.tres",
		"tint": Color("8a5a2a"),
	},
	{
		"id": &"pula",
		"name": "TSINELAS NA PULA",
		"tagline": "Kept for church, borrowed for this. Somebody is going to be in trouble later.",
		"traits": {&"bilis": 3, &"lakas": 4, &"tatag": 2},
		"ability": "res://scripts/abilities/resources/bagsak_bomb.tres",
		"tint": Color("a83a3a"),
	},
	{
		"id": &"asul",
		"name": "TSINELAS NA ASUL",
		"tagline": "Bleached pale by ten summers on the windowsill. Still nobody else is allowed to touch it.",
		"traits": {&"bilis": 4, &"lakas": 3, &"tatag": 3},
		"ability": "res://scripts/abilities/resources/bakya_bash.tres",
		"tint": Color("3a6a8a"),
	},
	{
		"id": &"dilaw",
		"name": "TSINELAS NA DILAW",
		"tagline": "So bright you can find it from across the plaza, which is the entire point of owning it.",
		"traits": {&"bilis": 4, &"lakas": 2, &"tatag": 3},
		"ability": "res://scripts/abilities/resources/bagsak_bomb.tres",
		"tint": Color("c9a52a"),
	},
	{
		"id": &"luma",
		"name": "TSINELAS NA LUMA",
		"tagline": "The sole is worn through to nothing. Weighs almost as little, and flies like it.",
		"traits": {&"bilis": 5, &"lakas": 1, &"tatag": 2},
		"ability": "res://scripts/abilities/resources/flick_dash.tres",
		"tint": Color("5c5248"),
	},
	# ⚠️ APPENDED, NOT INSERTED. See the ROSTER header: the index is the wire format
	# (`CharacterBase.slipper_index` is a replicated int), so a new entry goes on the END
	# or two peers on different builds quietly render different objects.
	#
	# THE HANGER. Human instruction, 2026-07-30: *"add a hanger to the slipper
	# customization options and ensure these attachments do not break physics."* The
	# hanger itself is four primitives in `character_visual.gd::SLIPPER_ATTACHMENTS`
	# under this same `id`, parented under the model and invisible to every collision
	# shape — the structural argument is in that block's header.
	{
		"id": &"sabit",
		"name": "TSINELAS NA SABIT",
		"tagline": "Hung on a nail by the door and never taken off its hanger. It throws the whole coat rack at you.",
		"traits": {&"bilis": 2, &"lakas": 5, &"tatag": 4},
		"ability": "res://scripts/abilities/resources/bakya_bash.tres",
		"tint": Color("6f6a86"),
	},
]

## ⚠️ MAX POWER, FOR THE TSINELAS DESCRIPTION ON THE CHARACTER SCREEN. Human
## instruction: *"display the max power in the custom slipper description UI."*
##
## Read off the skin's own `ThrowProfile.launch_speed` rather than stored as a second
## number here, which is the whole point: the two lists already disagree about nothing
## because there is only ever one place a slipper's launch speed lives. A hand-copied
## "power: 4" beside it would be true on the day it was typed.
##
## Returned in metres/second, the raw profile value, so the screen can present it however
## it likes. -1.0 when the skin's ability carries no profile (the three Can abilities do
## not) or the index is the -1 "no pick" sentinel.
static func slipper_max_power(index: int) -> float:
	if index < 0 or index >= SLIPPERS.size():
		return -1.0
	var path: String = String(SLIPPERS[index].get("ability", ""))
	if path == "":
		return -1.0
	# ⚠️ WAS READ OFF THE SKIN'S `ThrowProfile`. Per-class throw profiles are
	# deleted — every slipper flies the same way now — so the MAX POWER row on the
	# character screen reports the one launch speed there is.
	return Slipper.LAUNCH_SPEED

## The three tabs, in the order the screen shows them. A list rather than three
## hardcoded branches so `character_select.gd` cycles tabs the same way it cycles
## entries within one, and adding a fourth category later is one entry here.
##
## `slot` is which `GameLaunch` preference and which `CharacterBase` index this
## tab writes — named rather than positional so nothing depends on tab order.
const CATEGORIES: Array[Dictionary] = [
	{"id": &"person", "label": "PERSON",   "slot": &"character", "entries": ROSTER},
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


## The ability `.tres` a Prop carries THIS round, given the two skin indices its
## player picked and which side the round put it on. Returns "" when the pick is
## unknown — index -1 is the "no pick" sentinel `character_visual.gd` already
## uses for an AI slot or a peer on an older build — and `main.gd` falls back to
## its own defaults for that. Never assume a pick exists.
##
## Indices, not ids, because that is what crosses the wire: `CharacterBase`
## replicates `can_index`/`slipper_index` as ints, so this is answerable on every
## peer from what the spawn already carried. See the ROSTER header's note on
## append-only ordering — the same contract applies to both lists below.
static func ability_path_at(can_index: int, slipper_index: int, is_can: bool) -> String:
	var list: Array[Dictionary] = CANS if is_can else SLIPPERS
	var index: int = can_index if is_can else slipper_index
	if index < 0 or index >= list.size():
		return ""
	return String(list[index].get("ability", ""))

## ---------------------------------------------------------------------------
## TRAIT LOOKUP
##
## ⚠️ EVERY ONE OF THESE FALLS BACK TO NEUTRAL RATHER THAN FAILING, and that is
## the same contract `at()` already keeps for the same reason: these are read on
## the SPAWN PATH from a replicated int. An AI slot has no pick (index -1), a
## `--host` command-line session never passed a CHARACTER screen, and a peer on
## an older build can send an index this build's roster does not have. All three
## must produce a playable unit with the balance everything else was tuned
## against, not a crash and not a silently super-powered one.
## ---------------------------------------------------------------------------

## The traits dictionary for one entry of one list, or an empty one.
static func traits_in(entries: Array, index: int) -> Dictionary:
	if index < 0 or index >= entries.size():
		return {}
	var entry: Dictionary = entries[index]
	return entry.get("traits", {})

## One trait's points for a Person pick, 1..5, or TRAIT_NEUTRAL.
static func person_trait(index: int, key: StringName) -> int:
	return _trait_value(traits_in(ROSTER, index), key)

## One trait's points for a Prop pick. `is_can` chooses which of the player's two
## Prop skins is being asked about — a Prop is a lata one round and a tsinelas the
## next, so the answer genuinely changes between rounds and must never be cached.
static func prop_trait(can_index: int, slipper_index: int, is_can: bool, key: StringName) -> int:
	var entries: Array[Dictionary] = CANS if is_can else SLIPPERS
	var index: int = can_index if is_can else slipper_index
	return _trait_value(traits_in(entries, index), key)

static func _trait_value(traits: Dictionary, key: StringName) -> int:
	if traits.is_empty() or not traits.has(key):
		return TRAIT_NEUTRAL
	return clampi(int(traits[key]), TRAIT_MIN, TRAIT_MAX)
