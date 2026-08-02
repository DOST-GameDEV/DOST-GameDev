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

## ⚠️⚠️ THE LONGEST A NAME IN THIS FILE MAY BE, AND IT IS A RULE RATHER THAN A CLAMP.
## 🧑 2026-08-02: *"try to resolve it so that character name length doesnt break shit
## / actually just add a maximum character length for names"*, then *"lets not
## truncate the names / lets js put a limit to how long names can be"*.
##
## The two are the same instruction and this is where it lands. Nothing clips a name
## at draw time — a "LOLA PACIN…" on a card is the layout bug wearing a disguise, and
## it gets found by a player rather than by a probe. Instead every name authored below
## must fit, and `tools/bot_name_probe.tscn` fails the build if one does not.
##
## ⚠️ 14 IS `SettingsManagerScript.PLAYER_NAME_MAX`, NOT A SECOND NUMBER. Human names
## have been sanitised to 14 since the settings screen shipped, and these names now sit
## on the same rows as those (bots got names 2026-08-02) — the scoreboard, the toasts,
## the role-swap cards. Two different caps on one row is how a layout gets tuned
## against one and broken by the other.
##
## Longest today is LOLA PACING at 11, so this bounds a future addition rather than
## anything currently here. It is the WORST CASE the UI is allowed to be designed
## against; `role_swap_card.gd` autowraps so that even the worst case survives.
const NAME_MAX: int = SettingsManagerScript.PLAYER_NAME_MAX

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
##
## ⚠️⚠️ ONE LIST BECAME THREE, 🧑 2026-08-02: *"its weird that slippers and can
## have grit"* / *"speed and power on can is fkn weird too"* / *"can doesnt move
## bro"*. The human is right and it is worth recording exactly how, because the
## MECHANICS were never the problem and must not be "fixed":
##
##   SPEED/POWER/GRIT is a vocabulary written for a unit that WALKS, THROWS and
##   GETS STUNNED. A lata only sits on a mark and falls over; a tsinelas only
##   flies and gets picked up. Stretching one set of three words across three
##   different body plans is what produced meters that contradict their own
##   sentence — the exact failure the ROSTER header's "readable off the sentence"
##   rule exists to prevent, committed by the rule's own labels.
##
##   Worst offenders, both now gone: a lata's SPEED never described the can doing
##   anything (it divides `Lata.RESET_CHANNEL_TIME` — how long the TAYA stands
##   still), and a tsinelas's GRIT is a readiness stat, not a sturdiness one (it
##   divides `Carrier.THROW_LOCK_TIME`).
##
## So each tab now names what its own meter actually does. Same three `key`s, same
## three multipliers, same tuning — display only. Nothing crosses the wire.
const TRAIT_LABELS_PERSON: Array[Dictionary] = [
	{"key": &"bilis", "name": "SPEED", "gloss": ""},
	{"key": &"lakas", "name": "POWER", "gloss": ""},
	{"key": &"tatag", "name": "GRIT", "gloss": ""},
]

## RESET  · how fast the taya stands it back up (`Lata.RESET_CHANNEL_TIME`).
## REBOUND· how far it throws the tsinelas off when it takes a hit.
## STANCE · how hard it is to knock over at all (the hit window).
##
## `RESET` is deliberately the codebase's own word for it, so a maintainer reading
## the meter can grep straight to the constant behind it.
const TRAIT_LABELS_LATA: Array[Dictionary] = [
	{"key": &"bilis", "name": "RESET", "gloss": ""},
	{"key": &"lakas", "name": "REBOUND", "gloss": ""},
	{"key": &"tatag", "name": "STANCE", "gloss": ""},
]

## FLIGHT · launch speed — a flatter, faster arc (`Slipper.speed_scale()`).
## IMPACT · what a body-block costs the taya, and nothing else (§2.11).
## RECOVERY · how fast it is throwable once picked up (`Carrier.THROW_LOCK_TIME`).
##
## ⚠️ THIS SEAT TOOK THREE GOES AND THE TWO REJECTS ARE WORTH KEEPING, 2026-08-02.
## It was `RETURN` for one commit — 🧑 *"return on
## tsinelas isnt real, they dont return"*. Correct — nothing in this game hands a
## slipper back. `Carrier.notify_holding()` sets the lock AFTER a pickup the player
## has already walked over and made, so the stat covers the beat between having it
## and being able to throw it, not the trip to go get it. A label that implied the
## slipper comes to you would have promised a mechanic that does not exist, which
## is worse than the vague `GRIT` it replaced.
##
## ⚠️ `RECOVERY` IS ON `tatag` AND `RESET` ABOVE IS ON `bilis`. Both read as "back to
## usable" and they sit on DIFFERENT keys — the one trap in this table. A can's is
## the reset channel (speed); a slipper's is the throw lock (grit). Check the key.
const TRAIT_LABELS_TSINELAS: Array[Dictionary] = [
	{"key": &"bilis", "name": "FLIGHT", "gloss": ""},
	{"key": &"lakas", "name": "IMPACT", "gloss": ""},
	{"key": &"tatag", "name": "RECOVERY", "gloss": ""},
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
		# ⚠️ 2/5/4 -> 3/5/3, 2026-08-01. It was byte-identical to BEBANG's row, so
		# two of the twelve were one character wearing two rigs. He is the one who
		# has actually WORKED the box, so the mobility comes up and the padding
		# comes off; Bebang keeps the immovability, which is her whole joke.
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
		# GRIT 4 -> 5. "Do not stand in front of her" is a claim about being
		# immovable, and 4 left her tied with three other entries on it.
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
		# POWER 3 -> 4. "She does not miss" promised something the meters did not
		# pay out; there is no accuracy stat in this game, so the sentence cashes
		# out as the hit landing hard when it lands.
		"tagline": "Watches from the window most afternoons. On the good ones she comes down to play, and she does not miss twice.",
		"traits": {&"bilis": 1, &"lakas": 4, &"tatag": 5},
		"model": MODEL_DIR + "character-female-d.glb",
		"material": MATERIAL_DIR + "person_lola-pacing.tres",
	},
	{
		"id": &"mang_kanor",
		"name": "MANG KANOR",
		# ⚠️ 4/3/3 -> 5/3/2, 2026-08-01. It was byte-identical to ATE GIRLIE's row.
		# "Takes them at speed" is the loudest speed claim in the cast after
		# JUN-JUN, so it is paid in full and paid for out of GRIT.
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

## ⚠️ THE `ability` KEY IS GONE FROM BOTH TABLES — 2026-08-01, 🎨 `build model`,
## Agent_Prompts.md § 5.7.
##
## It used to hold a `res://scripts/abilities/resources/*.tres` path, and the long
## note that stood here explained how attaching a kit to a SKIN made the character
## screen's picks mechanical rather than cosmetic. **`scripts/abilities/**` was
## deleted outright in the HARRYDAKS pivot** (Design.md § 12 — eight verbs nobody
## asked for), so every one of those paths pointed at a file that no longer
## exists, and `CharacterRoster.ability_path_at()`, the only reader, had no
## callers left after `main.gd::_prop_ability_for()` went with it. The key and
## that function are both removed here rather than left to read as live design.
##
## `ROSTER`'s twelve Persons never carried the key at all — a Person's `ability`
## slot was emptied on 2026-07-30 when the Tag replaced it (see main.gd's header),
## so "drop it from all three tables" was already true for one of the three.
##
## ⚠️⚠️ §2.8 IS DECIDED AND THE ANSWER IS YES — THE PROP TABS CARRY REAL STATS.
## **2026-08-01, ⚖️ `build fair`, on direct human instruction**: 🧑 *"also make sure
## the stats actually apply u can also change the stats around for slippers, cans,
## characters, be creative with it, try to edit their descirptions too to match the
## stats"*. The traits below were carried verbatim through the model pass with
## nothing reading them; they are now tuned, they are read live, and each tagline
## was rewritten so the sentence and the meters agree.
##
## ⚠️ A PROP TRAIT MEANS SOMETHING DIFFERENT FROM A PERSON TRAIT, AND IT HAS TO.
## A Person walks, shoves and gets stunned, so SPEED/POWER/GRIT map onto it
## directly. A lata is a target that stands or lies, and a tsinelas is ammunition —
## neither of them walks. The three meters are re-read per tab, and the rule from
## the ROSTER header still governs: **the number must be readable off the sentence.**
##
##   TSINELAS — you throw it, every round you are an attacker (it is yours,
##              `Slipper.owner_slot`, `Design.md` §5.2):
##     FLIGHT → launch speed. A flatter, faster arc, and less time for the taya to
##              read it. ⚠️ NARROW ON PURPOSE, 2..4 — see `Slipper.speed_scale()`.
##     IMPACT → how hard a body-block hurts the blocker. It is the only thing that
##              makes blocking cost the taya anything (§2.11).
##     RECOVERY → how quickly it is ready to throw again after a pickup
##              (`Carrier.THROW_LOCK_TIME`). Retrieval is the game's thesis, so
##              this is the stat that plays it.
##
##   LATA — your can, on the mark during YOUR taya round (`Design.md` §9):
##     RESET   → how fast you can stand it back up (`Lata.RESET_CHANNEL_TIME`).
##     REBOUND → how far it knocks the tsinelas away when it takes a hit, which
##               buys the taya time by lengthening somebody's retrieval.
##     STANCE  → how hard it is to knock over at all (the hit window).
##
## ⚠️ THE THREE LATA STATS ARE THREE ROUTES TO ONE GOAL AND THAT IS THE DESIGN.
## A taya wants the can UPRIGHT (it is what passive defence is paid for). STANCE
## refuses the knockdown, RESET shortens the recovery, REBOUND punishes the
## attempt. A can that did all three would be the correct answer; each of these
## does one well and pays for it somewhere else.
##
## ⚠️ AND THE FOUR CANS WERE RETUNED AGAINST THEIR OWN MESHES, 2026-08-02, 🧑
## *"make it make sense from the cans and models, like boysen paint should be
## stable or smth"*. Every value below is now derivable from the shape the human
## drew — tall empty can topples, flat disc sits low, weighted tin does not move,
## solid ribbed tin hits back — rather than from an abstract role. One 5 each:
##
##   PASIP    RESET 5  · tall, thin, empty
##   BOYBEN   STANCE 5 · squat and half full of set paint
##   DECADES  (4/1/4)  · flat disc: stable AND quick to right, no mass to rebound
##   KALAWANG REBOUND 5· solid ribbed tin, heavy for its size
##
## BOYBEN held GRIT 4 *and* POWER 5 before this and was simply the best can on two
## axes; it now owns stance outright and concedes the rebound to KALAWANG. Totals
## are still not budget-balanced, per the ROSTER header — DECADES is a 9 and
## PASIP is a 7, and that is allowed.
##
## ⚠️ SIX CANS AND SEVEN SLIPPERS BECAME FOUR AND FOUR, because the human drew
## four of each and these tables now describe real meshes rather than tints. The
## dropped entries' traits are recorded in § LOG so `build fair` can see the full
## range that used to exist. THIS RENUMBERS THE INDICES, which cross the wire as
## `can_index`/`slipper_index` — safe only because every peer runs one build; the
## old append-only rule still applies to anything added from here on.

## ⚠️ `model` IS NEW AND IT IS WHAT MAKES THESE FOUR DIFFERENT OBJECTS.
## Until now a skin was a TINT and nothing else, so all six cans were one mesh in
## six colours. The human's four drawings are four genuinely different cans — a
## slim soda can, a squat paint tin, a tuna can and a ribbed bare tin — and the
## shape is most of what tells them apart at arena distance, so the mesh has to
## travel with the pick. `lata.gd::apply_skin()` reads this and swaps the mesh.
##
## ⚠️ AND `tint` IS WHITE ON EVERY ENTRY, WHICH IS NOT A COP-OUT.
## These meshes are TEXTURED with the human's own flattened label art, and the
## toon shader multiplies `albedo_color` INTO the texture rather than replacing
## it (toon.gdshader's fragment()). `lata.gd::_tint_meshes()` writes this value
## into `albedo_color` on every surface, so white multiplies to a no-op and the
## label reads exactly as drawn. A coloured tint here would stain the artwork.
## The tint machinery is untouched and still works — it is simply not what
## distinguishes these four any more.
const CANS: Array[Dictionary] = [
	{
		"id": &"pasip",
		"name": "PASIP",
		# RESET 5 · REBOUND 1 · STANCE 1. Unchanged by the 2026-08-02 retune and the
		# only can that was: a tall thin empty soda can topples if you breathe on it,
		# has no mass to throw a tsinelas anywhere, and weighs nothing to stand up.
		# The glass cannon — it concedes the knockdown and wins the time back.
		"tagline": "Softdrink na hindi Pepsi. Tall, thin and empty — it goes over if you look at it hard, and it is back up before you have turned around.",
		"traits": {&"bilis": 5, &"lakas": 1, &"tatag": 1},
		"model": "res://assets/models/lata_pasip.obj",
		"tint": Color.WHITE,
	},
	{
		"id": &"boyben",
		"name": "BOYBEN",
		# RESET 1 · REBOUND 3 · STANCE 5. 🧑 2026-08-02: *"boysen paint should be
		# stable or smth"* — and it now is, outright. A squat tin half full of set
		# paint is the most stable object on this table by some distance, so it takes
		# GRIT 5 off DECADES and gives up POWER 5 to KALAWANG for it: the immovable
		# can is not also allowed to be the hardest-hitting one. Slowest to right by
		# far, which is what the stance is paid for.
		"tagline": "Leftover fence paint, half set solid. Nothing on the mark stands its ground like it does — but righting it is a proper job.",
		"traits": {&"bilis": 1, &"lakas": 3, &"tatag": 5},
		"model": "res://assets/models/lata_boyben.obj",
		"tint": Color.WHITE,
	},
	{
		"id": &"decades",
		"name": "DECADES TUNA",
		# RESET 4 · REBOUND 1 · STANCE 4. Retuned 2026-08-02 off the MESH: a tuna can
		# is a flat wide disc, so it is genuinely hard to tip (STANCE 4, second only
		# to the paint tin) AND trivial to flick back upright (RESET 4) — the two
		# goods a low centre of gravity actually buys you. It pays for both in
		# REBOUND 1: there is no height or mass there to send a tsinelas anywhere.
		"tagline": "Flakes in oil from Aling Nena's. Squat and low, so tipping it is the hard part — and setting it back up is barely a motion.",
		"traits": {&"bilis": 4, &"lakas": 1, &"tatag": 4},
		"model": "res://assets/models/lata_decades.obj",
		"tint": Color.WHITE,
	},
	{
		"id": &"metal",
		"name": "KALAWANG",
		# RESET 2 · REBOUND 5 · STANCE 3. Takes POWER 5 from BOYBEN 2026-08-02, which
		# is where "heavy for its size" was always pointing: a solid ribbed tin is the
		# one can that genuinely punishes a throw by sending the tsinelas somewhere
		# awkward. Ordinary stance, slow and clumsy to right — it owns one stat.
		"tagline": "No label left, just ribs and rust. Heavy for its size — it sends the tsinelas across the street, and it is slow to stand back up.",
		"traits": {&"bilis": 2, &"lakas": 5, &"tatag": 3},
		"model": "res://assets/models/lata_metal.obj",
		"tint": Color.WHITE,
	},
]

## The four slippers, named by the human 2026-08-01: *"the 4 slipeprs are /
## Tsinelas / Crocs / Bakya / Sike (nike reference)"*. Same `model` and white
## `tint` contract as CANS above — see that block's header.
const SLIPPERS: Array[Dictionary] = [
	{
		"id": &"tsinelas",
		"name": "TSINELAS",
		# FLIGHT 3 · IMPACT 3 · RECOVERY 3, and this one stays neutral ON PURPOSE. It
		# is entry 0, which is what
		# an unpicked slipper and every -1 fallback resolve to (`_trait_value()`), so
		# making it anything else would silently retune every AI seat and every peer
		# that never reached the CHARACTER screen.
		"tagline": "Plain rubber, one peso of it. Every child on this street has thrown a pair, and it does everything well enough.",
		"traits": {&"bilis": 3, &"lakas": 3, &"tatag": 3},
		"model": "res://assets/models/tsinelas_classic.obj",
		"tint": Color.WHITE,
	},
	{
		"id": &"crocs",
		"name": "CROCS",
		# FLIGHT 2 "does not fly straight" · IMPACT 5 "knows about it" · RECOVERY 2. The
		# heavy one: slowest through the air, and the only slipper that genuinely
		# punishes a taya for standing in the lane. Values unchanged 2026-08-02 —
		# a rubber clog reads exactly like this and only the labels were wrong.
		"tagline": "Holes in the top, strap at the back. Heavy and it does not fly straight — but whoever body-blocks it knows all about it.",
		"traits": {&"bilis": 2, &"lakas": 5, &"tatag": 2},
		"model": "res://assets/models/tsinelas_crocs.obj",
		"tint": Color.WHITE,
	},
	{
		# ⚠️ THIS SEAT WAS `bakya` AND THE HUMAN REPLACED IT OUTRIGHT, 2026-08-01:
		# *"replace bakya with this (yes we wont do abkay anymore just outright use
		# this model) call it Pantulog or something"*. The carved-wood bakya is
		# gone from the game; a pantulog is the soft house slipper you actually
		# wear indoors, which is just as Filipino and reads far better in flight.
		"id": &"pantulog",
		"name": "PANTULOG",
		# FLIGHT 3 · IMPACT 1 "no weight behind it" · RECOVERY 5 "ready again before
		# the taya has turned around". The retrieval slipper: it hits like
		# nothing and it is ready again fastest, which is the trade the whole game
		# is about (`Design.md` §0 — the tension is the retrieval, not the throw).
		# ⚠️ Was 1/5/5, carried off the deleted `bakya` seat and never tuned; a
		# soft house slipper reading POWER 5 was the clearest case on the board of
		# a meter contradicting its own sentence. `RECOVERY` as a label finally names
		# what its 5 has always done.
		"tagline": "Lola's house slipper, worn soft. No weight behind it at all, but it is ready again before the taya has turned around.",
		"traits": {&"bilis": 3, &"lakas": 1, &"tatag": 5},
		"model": "res://assets/models/tsinelas_pantulog.obj",
		"tint": Color.WHITE,
	},
	{
		# ⚠️ DISPLAY NAME SHORTENED "SIKE" → "IKE", 2026-08-01, ON DIRECT HUMAN
		# INSTRUCTION: *"sike only says IKE so js change the name to ike on
		# everything"*. The model carries the real Nike wordmark as geometry
		# (Art_Direction.md §4b — the N could not be swapped for an S without
		# editing the mesh, which is out of scope), and in play only "IKE" reads
		# legibly off it. `id` stays `&"sike"` — every asset path, the roster key
		# and every internal reference are unaffected; only the string a player
		# sees changes. Out of row: `character_roster.gd`'s SLIPPERS table is
		# 🎨 `build model`'s per §3.
		"id": &"sike",
		"name": "IKE",
		# FLIGHT 4 "quickest thing off a hand" · IMPACT 2 · RECOVERY 3. The flat, fast
		# arc: least reaction time for the taya, least consequence if it is read.
		"tagline": "Definitely not the real brand. Light, loud, and the quickest thing off a hand on this street.",
		"traits": {&"bilis": 4, &"lakas": 2, &"tatag": 3},
		"model": "res://assets/models/tsinelas_sike.obj",
		"tint": Color.WHITE,
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
## Returned in metres/second, so the screen can present it however it likes.
## -1.0 only for the -1 "no pick" sentinel.
##
## ⚠️ IT IS THE SAME NUMBER FOR ALL FOUR SLIPPERS AND THAT IS NOT A BUG.
## Per-class `ThrowProfile`s are deleted (Design.md § 12 — "every slipper flies
## the same way now"), so there is exactly one launch speed in the game and this
## reports it. It used to gate on the entry's `ability` path first and return
## -1.0 when there was none; with `ability` dropped (§ 5.7) that gate would have
## returned -1.0 for EVERY slipper and silently blanked the MAX POWER row on the
## character screen — a dead row on a live control, which is the second half of
## THE REACHABILITY RULE. Removed rather than left to rot.
## ⚠️ IT IS NO LONGER THE SAME NUMBER FOR ALL FOUR, AND THAT IS THE 2026-08-02 FIX.
## The paragraph above is why it USED to be constant, and it was right that there is
## one `LAUNCH_SPEED` in the game — but the skin's own FLIGHT scale multiplies it on
## the way out (`slipper.gd::_throw()`, `launch_velocity_for()`), so the constant was
## reporting the baseline and not what the pick in front of the player actually does.
## Every slipper printing an identical "19 m/s" under four different FLIGHT meters
## was the same class of lie the labels were: a live row that tells you nothing.
## Scaled here through the one conversion (`trait_scale`) so it cannot drift from
## flight — IKE (bilis 4) reads 19.4, CROCS (bilis 2) 17.6, against neutral 18.5.
static func slipper_launch_speed(index: int) -> float:
	if index < 0 or index >= SLIPPERS.size():
		return -1.0
	return Slipper.LAUNCH_SPEED * trait_scale(
		slipper_trait(index, &"bilis"), CharacterBase.TRAIT_SPEED_PER_POINT)

## The three tabs, in the order the screen shows them. A list rather than three
## hardcoded branches so `character_select.gd` cycles tabs the same way it cycles
## entries within one, and adding a fourth category later is one entry here.
##
## `slot` is which `GameLaunch` preference and which `CharacterBase` index this
## tab writes — named rather than positional so nothing depends on tab order.
##
## `traits` is the tab's meter names (see the TRAIT_LABELS_* block). It lives HERE,
## on the category, rather than as a branch in `character_select.gd`, for the same
## reason `entries` does: a fourth tab is one row in this table and nothing in the
## UI. The screen asks `trait_labels()` and renders whatever it gets back.
const CATEGORIES: Array[Dictionary] = [
	{"id": &"person", "label": "PERSON",   "slot": &"character", "entries": ROSTER,
		"traits": TRAIT_LABELS_PERSON},
	{"id": &"can",    "label": "LATA",     "slot": &"can",       "entries": CANS,
		"traits": TRAIT_LABELS_LATA},
	{"id": &"slipper","label": "TSINELAS", "slot": &"slipper",   "entries": SLIPPERS,
		"traits": TRAIT_LABELS_TSINELAS},
]

## ---------------------------------------------------------------------------
## ⚠️⚠️ ALL THREE TABS STAY, AND THE TWO PROP TABS NOW DRIVE SOMETHING AGAIN.
## 🧑 2026-07-31: *"make slipper can and human still selectable in char select"*.
##
## They were nearly lost with the prop rewrite, and the reason is worth recording so
## it is not re-derived: these tabs used to pick which skin the PLAYER-DRIVEN lata
## and tsinelas units wore, and those units no longer exist. For one commit the picks
## therefore read nothing — **a tab that picks something nothing reads is worse than
## no tab**, because it costs a player real time and teaches them the choice matters.
##
## They are wired to the real props instead: `Lata.apply_skin()` and
## `Slipper.apply_skin()` take the `tint` from these tables, and `main.gd` pushes the
## host's pick to every peer at each round start so all four machines see one lata.
##
## ⚠️ THE "SOFT STATS" QUESTION IS ANSWERED — ALL THREE TABS REACH GAMEPLAY.
## §2.8, closed 2026-08-01 by ⚖️ `build fair` on direct human instruction. Every
## entry here carries `bilis` / `lakas` / `tatag` at ±5–7% per point on 1..5; the
## Person ones were already read live by `character_base.gd`, and the LATA and
## TSINELAS ones are now read by `lata.gd` and `slipper.gd`. See the CANS header
## for what each meter means on a prop and why it is not the same thing it means
## on a Person. `tools/trait_probe.tscn` asserts that all nine reach the game.
##
## ⚠️ THE `ability` FIELD ON EVERY ENTRY IS NOW INERT. `scripts/abilities/**` is
## deleted. The keys are left in place rather than stripped out of thirty-odd
## dictionary literals in a mechanics commit; whoever re-authors this table for the
## new models should drop them.
## ---------------------------------------------------------------------------

static func category(index: int) -> Dictionary:
	return CATEGORIES[posmod(index, CATEGORIES.size())]

static func entries_for(category_index: int) -> Array:
	return category(category_index)["entries"]

## The meter names for one tab. Wrapped like `entries_for()` so the screen never
## indexes `CATEGORIES` itself and the wrap-around is in one place.
static func trait_labels(category_index: int) -> Array:
	return category(category_index)["traits"]

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


## ⚠️ `ability_path_at()` WAS DELETED HERE — 2026-08-01, § 5.7. It returned the
## `.tres` a Prop's skin carried for the round. `scripts/abilities/**` is deleted,
## so every path it could return pointed at a missing file, and its only caller
## (`main.gd::_prop_ability_for()`) was itself deleted in the pivot — main.gd's
## own line 1595 records that. Recorded rather than silently dropped, because a
## lookup that still compiles is exactly the kind of thing a later lane restores a
## caller for.

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

## One trait's points for a LATA pick. `index` is `Lata.skin_index`, which is -1
## until a pick is pushed — and -1 resolving to neutral is the contract, not a
## bug: an unpicked can must play exactly like the balance everything else was
## measured against.
static func can_trait(index: int, key: StringName) -> int:
	return _trait_value(traits_in(CANS, index), key)

## One trait's points for a TSINELAS pick. `index` is `Slipper.skin_index`.
static func slipper_trait(index: int, key: StringName) -> int:
	return _trait_value(traits_in(SLIPPERS, index), key)

## ⚠️ KEPT, AND NOW A THIN WRAPPER RATHER THAN A SECOND IMPLEMENTATION. Its
## `is_can` argument dates from the deleted design in which ONE player unit was a
## lata one round and a tsinelas the next, so a single call site had to ask about
## both. The props are props now and each one knows its own skin, so the two
## lookups above are what the game actually calls; this stays because it is the
## documented API and routing it through them is what keeps one conversion.
static func prop_trait(can_index: int, slipper_index: int, is_can: bool, key: StringName) -> int:
	return can_trait(can_index, key) if is_can else slipper_trait(slipper_index, key)

## ⚠️⚠️ THE ONE CONVERSION FROM POINTS TO A MULTIPLIER, FOR ALL THREE TABS.
## `character_base.gd`'s `trait_speed_scale()` / `trait_power_scale()` /
## `trait_grit_scale()` route through this, and so do `slipper.gd`'s and
## `lata.gd`'s. Three points below neutral and three above, times a per-point
## constant the CALLER owns — because a point of SPEED is worth 5% and a point of
## POWER is worth 7%, and which constant applies is a property of the stat, not of
## this function.
##
## ⚠️ NEUTRAL IS EXACTLY 1.0 BY CONSTRUCTION. That is what makes "no pick",
## "an AI seat", "a peer on an older build" and "entry 0" all play the same game.
static func trait_scale(points: int, per_point: float) -> float:
	return 1.0 + float(clampi(points, TRAIT_MIN, TRAIT_MAX) - TRAIT_NEUTRAL) * per_point

static func _trait_value(traits: Dictionary, key: StringName) -> int:
	if traits.is_empty() or not traits.has(key):
		return TRAIT_NEUTRAL
	return clampi(int(traits[key]), TRAIT_MIN, TRAIT_MAX)
