extends Node
class_name AudioManagerScript
## Registered as the "AudioManager" autoload singleton (Project Settings > Autoload).
## Referenced globally as `AudioManager`, e.g. `AudioManager.play_at("bump", pos)`.

## Checklist 4.1 — the whole audio workstream's entry point. Before this, the
## repository contained ZERO AudioStreamPlayers of any kind: a lata could take a
## direct hit in complete silence, which reads as a broken build rather than as
## a missing feature.
##
## WHAT THIS OWNS
##   * The name -> stream table (SFX). One line per sound; see SFX_PATHS.
##   * Two voice pools, so nothing in gameplay ever calls `Node.new()` on a hot
##     path (a hit can resolve several times a frame — see the retrigger note).
##   * The three-bus volume model (Master / SFX / Music), driven by
##     SettingsManager and persisted to user://settings.cfg.
##
## WHAT THIS DELIBERATELY DOES NOT OWN
##   Map ambience. Those are plain looping AudioStreamPlayer nodes authored into
##   each map scene by its generator (tools/maps/build_*.py), on the Music bus,
##   because ambience is part of a place and belongs to that place's scene — the
##   same rule that put the WorldEnvironment and the kill plane in the map
##   rather than in Main.tscn (see main.gd::_load_map).
##
## ---------------------------------------------------------------------------
## ⚠️ THE AUDIO CLOCK IS NOT THE GAME CLOCK, AND THAT IS LOAD-BEARING HERE.
## ---------------------------------------------------------------------------
## `CharacterBase._hitstop()` dips `Engine.time_scale` to 0.05 for 60 ms on every
## landed hit (4.5). That scales `delta`, `SceneTreeTimer`, and every tween — but
## NOT the audio server, which runs on real time and does not repitch. That is
## exactly what makes a frame-synced impact work: the picture freezes and the
## clang plays at full speed and full pitch straight through it.
##
## It is also why every timing decision in this file uses
## `Time.get_ticks_msec()` (real milliseconds) and never `delta` or
## `create_timer`. A retrigger guard measured in scaled time would stretch 20x
## during hitstop — i.e. exactly during the moment it is guarding.

## Voices for non-positional audio: UI, and anything the local player should
## hear at a fixed volume regardless of where it happened (round win, countdown).
const UI_VOICES: int = 8
## Voices for positional gameplay audio. 12 is sized for the worst realistic
## frame: four units, two of them being hit, an ability firing and a slipper
## landing. Past that the oldest voice is stolen, which is the correct failure —
## a dropped sound is better than an allocation spike mid-fight.
const WORLD_VOICES: int = 12

## Default 3D falloff. The arena's playable width is ~17 units (Bounds/Wall* sit
## at ±8.6) and the confinement box is 5.0, so a 30-unit max distance means
## everything in the arena is audible and nothing outside it intrudes. Unit size
## rather than max distance is what actually shapes the curve in Godot 4.
const WORLD_UNIT_SIZE: float = 12.0
const WORLD_MAX_DISTANCE: float = 30.0

## ⚠️ THIS IS NOT COSMETIC — IT IS WHAT STOPS THE IMPACT BECOMING A BUZZSAW.
##
## `hitbox.gd::_on_area_entered` is re-run every physics frame for the whole of
## a thrown slipper's flight (`carriable.gd::_step_flying` calls
## `sweep_hitbox()` deliberately, because `area_entered` only fires on the ENTER
## edge and would otherwise miss a can already inside the hitbox on frame one).
## A slipper resting against a lata therefore resolves a "hit" 60 times a second.
## The state machine absorbs that fine — `apply_stagger` no-ops on a DOWNED or
## SEALED target — and `_hitstop()` has its own static guard, so nobody noticed.
## Audio does not absorb it on its own: a fixed 60 ms floor only throttles the
## TRIGGER rate, and `lata_impact` itself RINGS for ~300 ms — so sustained
## contact still stacked up to 5 overlapping, pitch-jittered copies of the same
## clang, which is what the "continuous metallic scream" actually sounded like
## in practice even with the floor in place. Fixed below by keying the guard to
## each sound's own ring time instead of one constant, so at most one voice of
## a given name is ever ringing at once. See `_retrigger_window()`.
##
## Measured in REAL milliseconds, per sound name. 60 ms is one hitstop, and is
## kept only as a floor — see `_retrigger_window()` for where the real,
## per-sound window comes from.
const RETRIGGER_MS: int = 60

## Pitch jitter applied to every play, as a fraction. Four players hitting things
## in a party game produce the same sound dozens of times a round; without this
## it reads as a looping sample rather than as impacts. Excluded for UI and for
## the match-state fanfares, which are melodic and must not detune (see
## `_NO_JITTER`).
const PITCH_JITTER: float = 0.07

const SFX_DIR: String = "res://assets/audio/sfx/"
const MUSIC_DIR: String = "res://assets/audio/music/"

## ---------------------------------------------------------------------------
## 4.2 — THE OST. Team-composed, delivered as they land (see docs/HUMAN.md
## § TABLE D). `ost_menu` covers the title screen, character select and lobby
## until a dedicated LOBBY track arrives; `ost_match` is the whole 90 s round,
## both maps. PRESSURE and VICTORY are not delivered yet — see `_music_lift()`
## below for the interim stand-in and docs/HUMAN.md for what is still owed.
##
## name -> filename, deliberately NOT the SFX_NAMES pattern (no `.wav` assumed):
## music ships as whatever the team hands over, `.mp3` for these two masters.
## ---------------------------------------------------------------------------
const MUSIC_PATHS: Dictionary = {
	"menu": "ost_menu.mp3",
	"match": "ost_match.mp3",
}
## How long a music cross-fade takes. Long enough that a swap is never heard as
## a cut, short enough that "round 1 starts" doesn't leave the menu bed
## bleeding through the countdown.
const MUSIC_CROSSFADE_TIME: float = 1.5
## ⚠️ CHECKLIST 5 — THE MIX, INTERIM. `_TRIM_DB`/`HEADROOM_DB` above exist
## because the SFX bus was measured clipping at +2.0 dBFS (B-121) with music
## silent; the delivered OST masters' own peak is unmeasured (no audio output
## in this session — see § LOG), so rather than ship them at the SFX table's
## 0 dB reference and risk repeating that bug the moment a real match layers
## impacts, the tag, VO and the bed at once, the bed starts here, quieter than
## everything else by default. **This is a starting point, not a measurement**
## — `tools/audio_mix_probe.gd` (the same probe B-121 used) is the one thing
## that should move this number, against a real recorded match with the OST
## actually playing.
const MUSIC_BASE_DB: float = -6.0
## The intensity lift, checklist 4.2's third bed. No dedicated PRESSURE track
## has been delivered yet (docs/HUMAN.md § TABLE D track 4) — until it is, the
## last 15 s of a round get a volume lift on the SAME match bed rather than a
## silent gap. Swap this for a real `play_music("pressure")` cross-fade the day
## `ost_pressure.ogg` lands; the hook (`_set_music_lift`) already exists.
const MUSIC_LIFT_DB: float = 4.0
const MUSIC_LIFT_SECONDS_LEFT: float = 15.0
const MUSIC_LIFT_TIME: float = 1.0
## Ducking under a countdown/result sting — checklist 4.6. Attack fast so the
## tick is never fighting the bed; release slow so the dip doesn't itself read
## as an edit.
const MUSIC_DUCK_DB: float = -10.0
const MUSIC_DUCK_ATTACK: float = 0.12
const MUSIC_DUCK_HOLD: float = 0.5
const MUSIC_DUCK_RELEASE: float = 0.8
## Sounds that ARE the ducking trigger. Every one of these already plays
## through `play()` from hud.gd/main.gd — see the class doc's file-you-don't-
## own note. Hooking the duck here means no other file has to know it exists.
## The bed's dip while a VOICE line is playing, as opposed to under a tick.
## ⚠️ DEEPER THAN `MUSIC_DUCK_DB` ON PURPOSE: a tick is a transient and only has to
## not collide, a spoken word has to be INTELLIGIBLE over a dense sustained bed, and
## that is an RMS problem rather than a peak one.
const VO_DUCK_DB: float = -14.0
## Floor for the VO duck's hold, for a take shorter than a countdown tick's window.
const VO_DUCK_MIN_HOLD: float = 0.5
const MUSIC_DUCK_TRIGGERS: PackedStringArray = [
	"countdown_tick", "countdown_go", "round_end", "match_win", "round_lose",
	"score_award",
]

## ---------------------------------------------------------------------------
## 4.3/4.4 — VOICE OVER. Checklist item 3: pools with no-repeat-last, and a
## cooldown per line category so a line that fires on every tag is not heard
## 20 times a match. docs/HUMAN.md § TABLE A/B/C is the line list and the `ID`
## column here is exactly that file's `ID` column — do not rename one without
## the other.
##
## ⚠️ DELIVERED 2026-08-01, PARTIALLY: eight of the sixteen ids on that page have
## takes. The pool contract below is unchanged and is what makes a partial
## delivery a non-event — an id with no file is an empty Array, `play_vo()`
## returns on `is_empty()`, and the trigger stays wired for the day it lands.
## `tumbang`, `taya`, `ayos`, `bilis`, `title` and `lata_restored` are in exactly
## that state right now. **Do not delete their triggers to "clean up".**
##
## ⚠️ THE DELIVERY ARRIVED AS AAC-IN-3GP NAMED `.wav` and had to be transcoded —
## `tools/audio/vo_import.py` is that conversion and its header is the record.
## Godot has no AAC decoder, so `load()` would have returned null for all eleven
## and this subsystem would have looked exactly as wired and exactly as silent as
## it did before the files existed. **Import through that tool, never by copying.**
## ---------------------------------------------------------------------------
const VO_DIR: String = "res://assets/audio/vo/"
## ⚠️ VOICE HAS ITS OWN HEADROOM AND IT IS NOT DECORATION — WITHOUT IT THE VO IS
## THE LOUDEST THING IN THE GAME BY ~7 dB.
##
## `play()`/`play_at()` both route through `_trim()`, which subtracts
## `HEADROOM_DB` (-7) from every sound effect. `play_vo()` never did, because
## when it was written there was nothing to play and 0 dB is what an unset
## `volume_db` is. The delivered takes are normalised to -6 dBFS peak
## (`vo_import.py`), so an untrimmed voice line would sit over `lata_impact` —
## the 0 dB reference the whole SFX table is quieter THAN — while also ducking
## the music by 10 dB every time it spoke.
##
## -4.0 rather than -7.0 deliberately: an announcer is SUPPOSED to sit above the
## scenery, just not above the impact. That puts a voice peak at -10 dBFS against
## `lata_impact`'s ~-8.4, i.e. just under the loudest thing in a fight.
## **A starting point measured, not a guess** — see § LOG and
## `tools/audio_mix_probe.gd`, which is the probe that should move it.
##
## ⚠️⚠️ RAISED -4.0 -> -1.0 AND THE DUCK DEEPENED, 2026-08-02, ON THE FIRST REPORT
## FROM SOMEBODY WHO ACTUALLY HEARD IT. 🧑: *"can you make voicelines sounds louder?
## usually the bg music overpower them and i cant hear them anymore"*.
##
## ⚠️ THE MEASUREMENT WAS NOT WRONG, IT WAS MEASURING THE WRONG THING. §4.7's
## `vo_mix_probe` put the voice at +5.6 dB peak over the bed and that is still true.
## But peak is not what an announcer competes with: a chiptune bed is dense and
## sustained, so it is the RMS that masks speech, and there the voice measured only
## **-1.1 dB against the effects** with the bed sitting under both. A line that peaks
## above the music and averages under it reads as "I can tell somebody said
## something" rather than as a word. **No session that set this number had an audio
## output device** (§4.7's own "not verified: anything by ear"), so this is the first
## time the thing being tuned was heard at all, and an ear beats the probe here.
##
## -1.0 rather than 0.0 keeps the one property the trim exists for: `lata_impact` is
## the 0 dB reference the whole SFX table is quieter than, and the voice still sits
## just under the loudest thing in a fight rather than on top of it.
const VO_TRIM_DB: float = -1.0
## Minimum real-ms gap between two plays of the SAME line id. Per-category
## rather than global: `tumbang` and `taya` should not silence each other.
const VO_COOLDOWN_MS: Dictionary = {
	"tumbang": 6000, "taya": 5000, "ayos": 4000,
	"clock_30": 0, "clock_10": 0, # each fires at most once per round anyway
	"match_win": 0, "match_draw": 0, "title": 0,
	# ⚠️ THE COUNTDOWN LINES MUST BE 0 AND THE DEFAULT WOULD HAVE BROKEN THEM.
	# They are separate ids so the 4 s default never applies BETWEEN them — but a
	# countdown runs before every round, and rounds 1 and 2 are far more than 4 s
	# apart only because the round is 90 s. Anything that ever re-counts inside
	# the window (a re-ready, an intermission counter) would silently lose the
	# line rather than the sound, which is the worst kind of missing: intermittent.
	"count_3": 0, "count_2": 0, "count_1": 0, "count_go": 0,
	"count_5": 0, "count_4": 0,
}
const VO_DEFAULT_COOLDOWN_MS: int = 4000

## Every sound in the game. Generated by tools/audio/generate_sfx.py — that
## script's section headers explain what each one is trying to sound like and
## why. Adding a sound is one line HERE and one function there; nothing else in
## the codebase needs to learn about it.
const SFX_NAMES: PackedStringArray = [
	# The lata — the sounds the whole game is built around.
	"lata_impact", "lata_knockdown", "lata_seal",
	"reset_channel_start", "reset_channel_complete",
	# Bodies.
	"bump", "tag", "downed", "jump", "land", "dash", "guard_block", "respawn",
	"stamina_empty",
	# The shove — checklist 4.5's "SHOVE connecting". `hit_body` and
	# `bump_swing` are ALIASES (see SFX_ALIASES below), not new syntheses: the
	# call sites (character_base.gd's `_apply_shove`/`_release_shove`,
	# slipper.gd's body-block branch) already exist and already use these
	# names, so this is the whole fix.
	"hit_body", "bump_swing",
	# The slipper.
	"throw_whoosh", "throw_charge", "slipper_land", "slipper_bounce", "grab",
	# More aliases — lata.gd and slipper.gd already call these exact names for
	# the RESET CHANNEL completing and a slipper being picked up/released.
	"can_knockdown", "reset_complete", "pickup", "throw_release",
	# Abilities (checklist 4.1's per-ability set).
	"ability_bagsak_bomb", "ability_bakya_bash", "ability_flick_dash",
	"ability_shatter_trap", "ability_spin_guard",
	# Match state.
	"countdown_tick", "countdown_go", "round_win", "round_lose", "match_win",
	"round_end", "score_award",
	# UI.
	"ui_click", "ui_hover", "ui_back", "ui_error",
	# The boot sting — the BH Studios entrance screen, which plays on every
	# single launch and did so in silence until now. See generate_sfx.py's
	# build_boot() for why it is a separate stream rather than audio on the
	# video: Godot 4's only core video codec is Theora and the clip is exported
	# with `-an`.
	"boot_sting",
]

## ⚠️⚠️ CHECKLIST 4.5 — THE FIVE SILENT EVENTS, AND WHY THIS TABLE IS THE FIX.
##
## `character_base.gd::_apply_shove`, `lata.gd::_apply_upright` and
## `slipper.gd::_apply_grabbed`/`_apply_thrown` ALREADY call
## `AudioManager.play_at()` with these exact names — the pivot wired the call
## sites and never gave them sounds. Renaming the call sites would mean
## editing files this lane does not own (`character_base.gd`, `lata.gd`,
## `slipper.gd` are not in this lane's § PATHS row); pointing the SAME name at
## an existing or newly-generated stream needs nothing but this table.
##
## `hit_body` and `bump_swing` are reuse, not new synthesis: `bump.wav` and
## `dash.wav` were generated for the 2v2 body-check and the deleted Dash
## mechanic (`Design.md` §12) and have had no caller since the pivot — a
## player-on-player thump and a body whoosh are exactly what a shove impact and
## its wind-up need, and reusing them is one line instead of a new sound that
## would have said the same thing.
const SFX_ALIASES: Dictionary = {
	"hit_body": "bump",
	"bump_swing": "dash",
	"can_knockdown": "lata_knockdown",
	"reset_complete": "reset_channel_complete",
	"pickup": "grab",
	"throw_release": "throw_whoosh",
}

## Sounds that must never be pitch-jittered: anything with a tune in it. A
## detuned UI click is unnoticeable; a detuned victory fanfare sounds broken.
const _NO_JITTER: PackedStringArray = [
	"ui_click", "ui_hover", "ui_back", "ui_error",
	"countdown_tick", "countdown_go", "round_win", "round_lose", "match_win",
	# A studio sting that is a different pitch every launch is a studio sting
	# that sounds broken. It is also the most-heard sound in the game by a wide
	# margin, so any wrongness in it is heard a thousand times.
	"boot_sting",
]

## ⚠️⚠️ B-121 — HEADROOM. EVERY VOICE IS ATTENUATED BY THIS, AND IT IS THE FIX
## FOR THE "LOUD BUZZ IN GAMEPLAY" REPORT. DO NOT REMOVE IT TO "MAKE THE GAME
## LOUDER" — that is precisely the change that caused the bug.
##
## Measured on the SFX bus during a real match (tools/audio_mix_probe.gd):
## **peak +2.0 dBFS**, i.e. over full scale, i.e. digital clipping — which is
## what a buzz IS. Two independent causes, and both are addressed here:
##
##   1. generate_sfx.py normalises every sound to peak 0.85, and `_TRIM_DB`
##      below then ADDED gain to three of them. `lata_impact` at +1.5 dB is
##      0.85 x 1.189 = **1.010, over full scale on its own**, before any
##      summing at all — so the most frequently played sound in combat clipped
##      on every single hit. Every trim below is now <= 0 dB: this table makes
##      things quieter relative to a reference, never louder.
##   2. Voices SUM. Four concurrent voices is normal in a fight (measured, and
##      it is what the pool is sized for), and four sounds each peaking at 0.85
##      can reach well past 1.0 together no matter how well behaved each is
##      alone. That needs headroom, and headroom has to be a real gap, not an
##      intention.
##
## ⚠️ WHY THIS IS NOT JUST `volume_db` ON THE SFX BUS. `_apply_bus()` below
## OVERWRITES the SFX bus volume from the player's slider every time it moves.
## Static headroom parked there would be silently wiped the first time settings
## loaded. Mix headroom belongs with the mix; the bus volume belongs to the
## player. Keeping those separate is what stops one clobbering the other.
##
## The Master limiter (B-120) is a genuine backstop but could never have fixed
## this: it sits DOWNSTREAM of the SFX bus, and no limiter can undo distortion
## that is already baked into the signal reaching it.
const HEADROOM_DB: float = -7.0

## Per-sound level trim, applied on top of HEADROOM_DB and the bus. Anything not
## listed plays at 0 dB, which is the loudest anything gets. This is mix
## balance, not a volume control — the player's own sliders are the bus volumes
## below.
##
## ⚠️ EVERY VALUE HERE MUST BE <= 0. See HEADROOM_DB. To make one sound stand
## out, pull the others DOWN; the sources are already normalised to 0.85 peak,
## so there is no headroom above 0 to boost into. `_trim()` clamps as a backstop.
const _TRIM_DB: Dictionary = {
	# lata_impact is the single most important sound in the game, so it is the
	# 0 dB reference that everything else is quieter THAN. It used to be +1.5,
	# which is the B-121 clip.
	"lata_impact": 0.0,
	"lata_seal": 0.0,
	"match_win": 0.0,
	"ui_hover": -8.0,        # fires on every mouse move across a menu
	"ui_click": -3.0,
	"slipper_bounce": -4.0,
	"land": -6.0,            # fires constantly; must sit under everything
	"jump": -4.0,
	"throw_charge": -5.0,
	# Measured as the busiest repeating group in a real match
	# (tools/audio_load_probe.gd: grab / charge / whoosh / bounce / land / the
	# ability all cycle ~0.4 times a second while the AI throws). They are
	# scenery around the impact, not events in their own right.
	"grab": -6.0,
	"throw_whoosh": -4.0,
	"slipper_land": -3.0,
	"dash": -3.0,
}

var _streams: Dictionary = {}          ## name -> AudioStream
## name -> real-ms retrigger window for that sound. See `_retrigger_window()`.
var _retrigger_ms: Dictionary = {}
var _ui_voices: Array[AudioStreamPlayer] = []
var _world_voices: Array[AudioStreamPlayer3D] = []
var _ui_next: int = 0
var _world_next: int = 0
## name -> Time.get_ticks_msec() of its last play. See RETRIGGER_MS.
var _last_played_ms: Dictionary = {}

## ---------------------------------------------------------------------------
## MUSIC — two players so a track change is a cross-fade, never a cut.
## ---------------------------------------------------------------------------
var _music_streams: Dictionary = {}       ## name -> AudioStream
var _music_players: Array[AudioStreamPlayer] = []
var _music_active_index: int = 0
var _current_music_name: String = ""
var _music_lift_on: bool = false
var _music_fade_tweens: Array[Tween] = [null, null]
var _music_duck_tween: Tween = null

## ---------------------------------------------------------------------------
## VOICE OVER STATE.
## ---------------------------------------------------------------------------
var _vo_takes: Dictionary = {}          ## id -> Array[AudioStream], every take pooled
var _vo_last_take: Dictionary = {}      ## id -> index last played, so the pool never
## repeats a take back to back (checklist 3's "no-repeat-last").
var _vo_cooldown_until_ms: Dictionary = {}  ## id -> Time.get_ticks_msec() it may play again
var _vo_voices: Array[AudioStreamPlayer] = []
var _vo_next: int = 0
## Round-scoped, so `clock_30`/`clock_10` fire once each rather than every
## frame `time_left` sits at or below the threshold.
var _clock_30_said: bool = false
var _clock_10_said: bool = false
## The whole second the run-out count last spoke, so 3-2-1 fires once each rather
## than every frame. 0 means "nothing said this round" — see `_process()`.
var _count_said: int = 0
## "" / "splash" / "match" / "menu" — see `_scene_state()`. Edge-detected in
## `_process()` rather than read once at boot, and EMPTY at startup so the very
## first transition is a real edge whichever state the game opens in.
##
## ⚠️ REPLACED `_was_main_menu` ON 2026-08-01. A bool could only express "are we
## on the title screen", which answers where the menu bed starts and not where it
## has to stop — see `_poll_scene_state()` for the leak that cost.
var _music_scene_state: String = ""

## 0..1, mirrored from SettingsManager (which owns persistence). Kept here too so
## the bus state and the saved state can be compared without reaching across.
var master_volume: float = 1.0
var sfx_volume: float = 1.0
var music_volume: float = 1.0


func _ready() -> void:
	# ⚠️ PROCESS_MODE_ALWAYS, and the voices below inherit it.
	#
	# The pause overlay (B-20) sets `get_tree().paused = true`, and a paused
	# AudioStreamPlayer stops dead. Without this, every button in the pause menu
	# — including the Settings panel where the volume sliders live — would be
	# silent, so dragging the SFX slider would produce no audible feedback at
	# exactly the moment the player is trying to set it by ear.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_streams()
	_build_voices()
	_install_master_limiter()
	_load_music()
	_build_music_players()
	_load_vo()
	_build_vo_voices()
	# ⚠️ FIRES FROM AUTOLOAD SIGNALS ONLY — no scripts/ui/** or main.gd call site
	# is touched. `RoundManager`/`MatchManager` are autoloads too, so subscribing
	# here reaches every round and match-end without this lane writing a line
	# in a file it does not own.
	#
	# ⚠️ NOT STARTED HERE ANY MORE. Starting the menu bed straight from `_ready()`
	# raced `SplashScreen`'s intro clip — the bed was audible under the intro
	# video before the video's own `AudioManager.play("boot_sting")` had even
	# finished. `_poll_scene_state()` below is what actually starts it, the
	# instant the splash hands off — see that function.
	MatchManager.round_started.connect(_on_round_started_music)
	MatchManager.match_won.connect(_on_match_won_music)
	MatchManager.score_changed.connect(_on_score_changed_audio)
	MatchManager.round_started.connect(_on_round_started_vo)
	MatchManager.match_won.connect(_on_match_won_vo)
	RoundManager.lata_knocked.connect(_on_lata_knocked_vo)
	RoundManager.attacker_tagged.connect(_on_attacker_tagged_vo)
	# docs/HUMAN.md TABLE A's `lata_restored` ("Nakatayo na!"). No take delivered
	# in the 2026-08-01 batch — wired anyway, because the whole point of the pool
	# contract is that a trigger costs nothing while its pool is empty and the
	# line is live the moment a file lands. Its counterpart `tumbang` is in the
	# same state and has been wired since the pooling was written.
	RoundManager.lata_restored.connect(_on_lata_restored_vo)


## ---------------------------------------------------------------------------
## MUSIC PLAYBACK.
## ---------------------------------------------------------------------------

func _load_music() -> void:
	for track_name in MUSIC_PATHS:
		var path := MUSIC_DIR + String(MUSIC_PATHS[track_name])
		if not ResourceLoader.exists(path):
			push_warning("AudioManager: missing music '%s' — see docs/HUMAN.md § TABLE D" % path)
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			push_warning("AudioManager: '%s' did not load as an AudioStream" % path)
			continue
		# Seamless looping per docs/HUMAN.md's spec — the exported file itself
		# has no fade at either end, this just tells the player to wrap rather
		# than stop.
		if stream is AudioStreamMP3:
			(stream as AudioStreamMP3).loop = true
		elif stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
		_music_streams[track_name] = stream


func _build_music_players() -> void:
	for i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.volume_db = -80.0
		add_child(player)
		_music_players.append(player)


## Public entry point for a track change. Safe to call with a name that has no
## delivered asset yet (VICTORY, LOBBY — see docs/HUMAN.md § TABLE D): it warns
## once at load and no-ops here, same contract as a missing SFX.
func play_music(track_name: String, fade_time: float = MUSIC_CROSSFADE_TIME) -> void:
	if track_name == _current_music_name:
		return
	var stream: AudioStream = _music_streams.get(track_name)
	if stream == null:
		return
	_current_music_name = track_name
	var old_index := _music_active_index
	var new_index := 1 - old_index
	var old_player := _music_players[old_index]
	var new_player := _music_players[new_index]
	new_player.stream = stream
	new_player.volume_db = -80.0
	new_player.play()
	_music_active_index = new_index
	var target_db := _music_target_db()
	_fade_music_player(new_index, target_db, fade_time)
	if old_player.playing:
		_fade_music_player(old_index, -80.0, fade_time, true)


func _fade_music_player(index: int, target_db: float, fade_time: float,
		stop_after: bool = false) -> void:
	if _music_fade_tweens[index] != null and _music_fade_tweens[index].is_valid():
		_music_fade_tweens[index].kill()
	var player := _music_players[index]
	if fade_time <= 0.0:
		player.volume_db = target_db
		if stop_after:
			player.stop()
		return
	var tween := create_tween()
	_music_fade_tweens[index] = tween
	tween.tween_property(player, "volume_db", target_db, fade_time)
	if stop_after:
		tween.tween_callback(player.stop)


## The base level the active player should sit at right now — lift included,
## duck NOT included (the duck tween works relative to this and restores to
## it, so ducking never has to know whether a lift is active).
func _music_target_db() -> float:
	return MUSIC_BASE_DB + (MUSIC_LIFT_DB if _music_lift_on else 0.0)


## ⚠️⚠️ THE MENU BED IS OWNED BY A SCENE STATE, NOT BY A LIST OF EVENTS, AND
## THAT REPLACED A `MainMenu`-ONLY EDGE CHECK ON 2026-08-01.
##
## 🧑, twice in one message, after playing it: *"the main menu ost audio still
## leaks to start"* and *"also main menu ost audio still leaks into game, pls js
## abruptly cut it so that it doesnt play anymore when start"*.
##
## ⚠️ AND THE MEASUREMENT SAID IT WAS FINE, WHICH IS THE INTERESTING PART.
## `tools/audio/music_probe.tscn` reported the round bed up and the menu bed
## silent once the round was running — because it only ever asserted DURING the
## round. The leak is in the window the probe deliberately skipped: `Main.tscn`
## loads, the player walks around in the free-roam window before pressing [R],
## and the match bed does not start until the first `countdown_tick`. So the
## player is standing in the arena, in the game, listening to the title screen.
## Both of 🧑's sentences describe exactly that window.
##
## The old check asked "is the current scene MainMenu" and started the bed on
## the false->true edge. That answers where the bed STARTS and says nothing about
## where it must STOP, which is the half that was wrong. This asks which of three
## states the game is in and hands each one its own rule:
##
##   splash  silence. The intro clip has its own sting and nothing may sit under it.
##   match   silence, ABRUPTLY. The round bed then starts on its own cue.
##   menu    the menu bed.
##
## ⚠️ "MENU" IS EVERYTHING THAT IS NEITHER OF THE OTHER TWO, deliberately, rather
## than a list of menu scenes. A list would have to be edited every time a screen
## is added, and the failure mode of forgetting is silence on the new screen. It
## also fixes a path no list would have covered: a network-disconnect bounce
## lands on `MultiplayerSetup`, not `MainMenu`, so the old check left the MATCH
## bed playing over a menu.
const MATCH_SCENE_PATH: String = "res://scenes/main/Main.tscn"

func _scene_state() -> String:
	var scene := get_tree().current_scene
	# ⚠️ NULL IS "DON'T KNOW", NOT "MENU". `change_scene_to_file` leaves
	# `current_scene` null for a frame, and at boot it is null before the splash
	# is ready — treating that as a menu state starts the bed under the intro
	# video, which is the first of the two bugs above.
	if scene == null or not is_instance_valid(scene):
		return ""
	if scene is SplashScreen:
		return "splash"
	if scene.scene_file_path == MATCH_SCENE_PATH:
		return "match"
	return "menu"


func _poll_scene_state() -> void:
	var state := _scene_state()
	if state == "" or state == _music_scene_state:
		return
	_music_scene_state = state
	match state:
		"menu":
			# ⚠️ FADE 0.0 — THE BED STARTS ON THE FRAME THE INTRO ENDS. 2026-08-01,
			# on human instruction: *"Remove the audio playback delay when
			# transitioning from the intro video. MenuMusic should begin playing at
			# the exact moment the intro video ends."* The delay was never a timer;
			# it was `MUSIC_CROSSFADE_TIME`, 1.5 s of ramp on a track starting from
			# silence. A cross-fade needs something to fade FROM, and at this edge
			# there is nothing — so the ramp was pure latency.
			play_music("menu", 0.0)
			play_vo("title")
		"match":
			# ⚠️ STOPPED, NOT CROSSFADED, AND THAT IS THE LITERAL ASK.
			# `play_music()` would fade the menu bed out over
			# `MUSIC_CROSSFADE_TIME`, and 1.5 s of title-screen music over the
			# arena is precisely what was reported. 🧑: *"pls js abruptly cut
			# it"*.
			stop_music_now()
		"splash":
			stop_music_now()


## Kills both music players dead, this frame, with no fade.
##
## ⚠️ IT MUST CLEAR `_current_music_name` AND THAT IS NOT BOOKKEEPING.
## `play_music()` opens with `if track_name == _current_music_name: return`, so
## stopping the players while the name still says "menu" would make the next
## `play_music("menu")` a no-op and the menu bed would never come back — silence
## for the rest of the session, from the function whose job is to be quiet.
func stop_music_now() -> void:
	for i in _music_players.size():
		if _music_fade_tweens[i] != null and _music_fade_tweens[i].is_valid():
			_music_fade_tweens[i].kill()
		_music_players[i].stop()
		_music_players[i].volume_db = -80.0
	if _music_duck_tween != null and _music_duck_tween.is_valid():
		_music_duck_tween.kill()
	_music_duck_tween = null
	_music_lift_on = false
	_current_music_name = ""


func _process(_delta: float) -> void:
	_poll_scene_state()
	var should_lift := RoundManager.round_active \
		and RoundManager.time_left <= MUSIC_LIFT_SECONDS_LEFT \
		and RoundManager.time_left > 0.0
	_set_music_lift(should_lift)
	# `bilis` ("Hurry!") rides the SAME threshold as the intensity lift below —
	# the two are meant to land together, one clock, one feeling, per
	# docs/HUMAN.md § TABLE D's "the music reacts to the state of play" note.
	if RoundManager.round_active and not _clock_30_said and RoundManager.time_left <= 30.0:
		_clock_30_said = true
		play_vo("clock_30")
		play_vo("bilis")
	if RoundManager.round_active and not _clock_10_said and RoundManager.time_left <= 10.0:
		_clock_10_said = true
		play_vo("clock_10")
	# ⚠️ THE ROUND'S LAST THREE SECONDS REUSE THE ROUND-START COUNT. 🧑 2026-08-01:
	# *"u dont do countdown for final seconds of match, u have audio for that
	# already, just reuse"* — and the recorded `count_3`/`count_2`/`count_1` are
	# plain numbers ("Tatlo! Dalawa! Isa!"), not "starting in three", so they carry
	# a run-out as naturally as a run-in. No new recording needed.
	#
	# ⚠️ CEIL, NOT FLOOR, AND FIRED ONCE PER WHOLE SECOND. `time_left` is a float
	# ticking down, so `int(time_left)` sits on 2 for the whole of 2.99..2.00 and
	# would say "Dalawa!" while the clock still reads 3. `ceili()` makes the spoken
	# number the number the HUD is showing. `_count_said` is the edge guard — the
	# same job `_clock_10_said` does, one per second instead of one per round.
	if RoundManager.round_active and RoundManager.time_left > 0.0:
		var whole := ceili(RoundManager.time_left)
		if whole <= 3 and whole != _count_said:
			_count_said = whole
			play_vo("count_%d" % whole)
	if not RoundManager.round_active:
		_clock_30_said = false
		_clock_10_said = false
		_count_said = 0


func _set_music_lift(on: bool) -> void:
	if on == _music_lift_on:
		return
	_music_lift_on = on
	# Retargets the active player only; a duck in progress will still release
	# to the NEW target because `_duck_music` always reads `_music_target_db()`
	# fresh at release time rather than capturing it up front.
	_fade_music_player(_music_active_index, _music_target_db(), MUSIC_LIFT_TIME)


## Checklist 4.6/2 — ducks the active music player under a countdown or a
## match/round result sting so it cuts through rather than competing with the
## bed. Called from `play()` below for the sounds in `MUSIC_DUCK_TRIGGERS`;
## every one of those already plays from a file this lane does not own
## (hud.gd, main.gd), so hooking it here needs no other file touched.
## ⚠️⚠️ THE HOLD IS A PARAMETER SINCE 2026-08-02, BECAUSE A VOICE LINE OUTLASTS IT.
## 🧑: *"the bg music overpower them and i cant hear them anymore"*. `MUSIC_DUCK_HOLD`
## is 0.5 s, tuned for a countdown TICK, and the delivered VO takes run **0.74 to
## 1.45 s** (`vo_probe`). So the bed began climbing back at 0.5 s and had fully
## returned by 1.3 s — over the back half of every line, which is where the word
## actually is. Raising `VO_TRIM_DB` alone would have made the voice louder while
## still letting the music close over the end of it.
##
## The tick keeps 0.5 s; a voice line asks for a hold that covers the longest take.
func _duck_music(hold: float = MUSIC_DUCK_HOLD, depth: float = MUSIC_DUCK_DB) -> void:
	if _music_duck_tween != null and _music_duck_tween.is_valid():
		_music_duck_tween.kill()
	var player := _music_players[_music_active_index]
	var floor_db := _music_target_db() + depth
	_music_duck_tween = create_tween()
	_music_duck_tween.tween_property(player, "volume_db", floor_db, MUSIC_DUCK_ATTACK)
	_music_duck_tween.tween_interval(hold)
	# Reads `_music_target_db()` at release time, not at call time, so a duck
	# that outlives a lift toggling mid-flight still resolves to wherever the
	# bed is actually supposed to sit.
	_music_duck_tween.tween_callback(func() -> void:
		if _music_duck_tween == null:
			return
		var release := create_tween()
		release.tween_property(player, "volume_db", _music_target_db(), MUSIC_DUCK_RELEASE))


func _on_round_started_music(_round_number: int, _defender_slot: int) -> void:
	play_music("match")


func _on_match_won_music(_winning_slot: int) -> void:
	play_music("menu")


## ---------------------------------------------------------------------------
## VOICE OVER — loading, pooling, playback.
## ---------------------------------------------------------------------------

## Scans `assets/audio/vo/` for `vo_<id>_<name>.wav` and groups every take by
## `<id>`. Deliberately a directory scan rather than a hardcoded table: takes
## arrive per-recorder (`vo_tumbang_cy.wav`, `vo_tumbang_jo.wav`, ...) and the
## count per line is not known until the team's drive folder is committed —
## see docs/HUMAN.md's naming convention, which this reads exactly.
##
## Uses `ResourceLoader.list_directory()`, not `DirAccess`. In an exported PCK,
## `DirAccess.list_dir_begin()` on this folder returns the import-metadata
## stub names (`vo_clock_10_1.wav.import`) instead of the real resource names
## (`vo_clock_10_1.wav`), so the `.wav` suffix check never matched and every
## voice line silently failed to load outside the editor. `ResourceLoader`
## resolves the PCK's remap table and returns the real names in both cases.
func _load_vo() -> void:
	for file_name: String in ResourceLoader.list_directory(VO_DIR):
		if file_name.begins_with("vo_") and file_name.ends_with(".wav"):
			var line_id := _vo_id_from_filename(file_name)
			if line_id != "":
				var stream := load(VO_DIR + file_name) as AudioStream
				if stream != null:
					if not _vo_takes.has(line_id):
						_vo_takes[line_id] = []
					(_vo_takes[line_id] as Array).append(stream)


## `vo_<id>_<name>.wav` -> `<id>`. `<id>` itself may contain underscores
## (`clock_30`), so this strips the fixed `vo_` prefix and the LAST
## underscore-separated segment (the recorder's name) rather than splitting
## on every underscore.
func _vo_id_from_filename(file_name: String) -> String:
	var stem := file_name.get_basename() # drops ".wav"
	if not stem.begins_with("vo_"):
		return ""
	stem = stem.substr(3)
	var last_us := stem.rfind("_")
	if last_us <= 0:
		return stem
	return stem.substr(0, last_us)


func _build_vo_voices() -> void:
	for i in 3:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX" # No dedicated Voice bus yet — see class doc.
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_vo_voices.append(player)


## Public entry point. Safe to call for an id with zero delivered takes (every
## category right now): it is exactly the missing-asset no-op the SFX table
## already uses, so wiring an event to a line that has not been recorded yet
## costs nothing and starts working the moment the file lands.
func play_vo(line_id: String) -> void:
	var takes: Array = _vo_takes.get(line_id, [])
	if takes.is_empty():
		return
	var now := Time.get_ticks_msec()
	var cooldown: int = int(VO_COOLDOWN_MS.get(line_id, VO_DEFAULT_COOLDOWN_MS))
	if now < int(_vo_cooldown_until_ms.get(line_id, 0)):
		return
	_vo_cooldown_until_ms[line_id] = now + cooldown
	var index := randi() % takes.size()
	# No-repeat-last (checklist 3): re-roll once rather than looping, so a
	# 1-take line (nothing to vary yet) still plays instead of stalling.
	if takes.size() > 1 and index == int(_vo_last_take.get(line_id, -1)):
		index = (index + 1) % takes.size()
	_vo_last_take[line_id] = index
	var player := _vo_voices[_vo_next]
	_vo_next = (_vo_next + 1) % _vo_voices.size()
	player.stream = takes[index]
	# See VO_TRIM_DB. Set every play rather than once at build time because these
	# voices are pooled and reused, and a future per-line trim belongs here.
	player.volume_db = VO_TRIM_DB
	player.play()
	# Duck for as long as this take actually lasts, not for a countdown tick's 0.5 s,
	# and deeper: speech is masked by the bed's RMS rather than by its peaks.
	var take_length: float = VO_DUCK_MIN_HOLD
	var stream_length := player.stream.get_length() if player.stream != null else 0.0
	if stream_length > 0.0:
		take_length = maxf(take_length, stream_length)
	_duck_music(take_length, VO_DUCK_DB)


## ⚠️ THE 3-2-1 COUNTDOWN'S SFX **AND** ITS VOICE, IN ONE CALL, BECAUSE ONLY THE
## CALLER KNOWS WHICH NUMBER IT IS.
##
## `play("countdown_tick")` is the same string for "3", "2" and "1", so this lane
## could not tell the three apart from inside `play()` — and the delivered VO has
## a separate recording for each (docs/HUMAN.md TABLE A: `count_3`/`count_2`/
## `count_1`/`count_go`). The number lives in `hud.gd::show_countdown_tick`'s own
## argument and nowhere else.
##
## ⚠️ IT IS DERIVED FROM THE TEXT, NOT FROM A TICK COUNTER, AND THAT IS THE POINT.
## A counter in this file would be inferring another lane's loop shape
## (`main.gd::_run_ready_countdown`'s literal `["3", "2", "1"]`) and would speak a
## WRONG number the day that loop changes length — §6 trap 12's "do not infer a
## value from an action that has its own preconditions". Reading the digit means a
## 5-count asks for `count_5`, which is a real docs/HUMAN.md id with no take
## delivered, so it degrades to SILENCE rather than to a lie.
func play_countdown(tick_text: String) -> void:
	var is_go := tick_text == "GO!"
	# Unchanged behaviour, including the `countdown_tick` -> `play_music("match")`
	# hook inside `play()`. This wraps that call; it does not replace it.
	play("countdown_go" if is_go else "countdown_tick")
	if is_go:
		play_vo("count_go")
	elif tick_text.is_valid_int():
		play_vo("count_%d" % tick_text.to_int())


func _on_round_started_vo(round_number: int, _defender_slot: int) -> void:
	if round_number == 1:
		play_vo("taya")


func _on_match_won_vo(winning_slot: int) -> void:
	play_vo("match_draw" if winning_slot < 0 else "match_win")


func _on_lata_knocked_vo(_by_slot: int) -> void:
	play_vo("tumbang")


func _on_lata_restored_vo() -> void:
	play_vo("lata_restored")


func _on_attacker_tagged_vo(_defender_slot: int, _victim_slot: int) -> void:
	play_vo("taya")
	play_vo("ayos")


## Checklist 4's fifth silent event — MatchManager.score_changed carries the
## reason string (LATA DOWN / TAG / SABOTAGE / DEFENSE). ⚠️ DEFENSE fires every
## single second of every round and MUST NOT get a sound — see the class doc's
## note on retrigger guards; a per-second sound would be the buzzsaw case all
## over again, just louder because it would also duck the music every second.
func _on_score_changed_audio(_slot: int, _total: int, _delta: int, reason: String) -> void:
	if reason == "DEFENSE":
		return
	play("score_award")


## B-120 — see Handoff.md. `default_bus_layout.tres` has 20 voices (8 UI + 12
## world) all summing into Master at 0 dB with no ceiling anywhere in the
## chain. One or two sounds never clips; a real 2v2 fight regularly has half a
## dozen world voices ringing at once (bump, land, an ability, a lata impact,
## two characters' footsteps), and several of those are individually mixed
## close to full scale already (`generate_sfx.py`'s `soft_clip` drive runs as
## high as 1.9–2.2). Summed with no ceiling, that overs the Master bus and
## digitally clips — which is what "very loud" during actual play, as opposed
## to the menu or ambience, actually was.
##
## A limiter on Master is the standard fix for exactly this (see Godot's own
## audio-effects docs: "adding one in the Master bus is always recommended to
## reduce the effects of clipping") and only engages when the summed signal
## would otherwise exceed the ceiling — a single sound playing alone is
## untouched. `AudioEffectLimiter` is marked deprecated in favor of
## `AudioEffectHardLimiter` as of 4.3, but its properties (ceiling_db,
## threshold_db) are stable and documented back to 3.0; used here over the
## replacement because this session has no Godot binary to confirm the newer
## class's property names against, and a wrong property name silently doing
## nothing is worse than a working effect on a deprecated (not removed) class.
func _install_master_limiter() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx < 0:
		push_warning("AudioManager: no 'Master' bus — cannot install the clipping limiter.")
		return
	var limiter := AudioEffectLimiter.new()
	# Ceiling a hair below 0 dBFS rather than at it — the same headroom reason
	# _apply_bus() below doesn't trust an exact 0.0 either.
	limiter.ceiling_db = -0.3
	# 0 dB: only start reducing gain once the mix would actually exceed the
	# ceiling, so normal single- and double-sound moments pass through
	# untouched and only real pile-ups (the combat case above) get caught.
	limiter.threshold_db = 0.0
	AudioServer.add_bus_effect(master_idx, limiter)

	# ⚠️ B-121 — AND ONE ON **SFX**, WHICH IS WHERE THE CLIPPING ACTUALLY WAS.
	#
	# The Master limiter above was added for this report and could not have
	# fixed it: tools/audio_mix_probe.gd measured the SFX bus at peak +2.0 dBFS
	# while Master sat at -1.4, i.e. the limiter was doing its job and the
	# signal reaching it had ALREADY clipped one bus upstream. A limiter cannot
	# undo distortion, only prevent it, so it has to sit on the bus that
	# generates the overload.
	#
	# HEADROOM_DB is the real fix and this is the safety net under it: headroom
	# is sized for the normal busy case (four concurrent voices, measured), and
	# a limiter is what covers the tail where six land in the same 50 ms.
	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx < 0:
		push_warning("AudioManager: no 'SFX' bus — cannot install its clipping limiter.")
		return
	var sfx_limiter := AudioEffectLimiter.new()
	sfx_limiter.ceiling_db = -1.0
	sfx_limiter.threshold_db = 0.0
	AudioServer.add_bus_effect(sfx_idx, sfx_limiter)


## Loads every entry in SFX_NAMES. A missing file warns once and is then simply
## absent — `play()` no-ops on an unknown name rather than erroring, so a
## half-generated assets/audio/sfx/ can never crash a match.
func _load_streams() -> void:
	for sound_name in SFX_NAMES:
		var file_stem: String = SFX_ALIASES.get(sound_name, sound_name)
		var path := SFX_DIR + file_stem + ".wav"
		if not ResourceLoader.exists(path):
			push_warning("AudioManager: missing '%s' — run tools/audio/generate_sfx.py" % path)
			continue
		var stream := load(path) as AudioStream
		if stream == null:
			push_warning("AudioManager: '%s' did not load as an AudioStream" % path)
			continue
		_streams[sound_name] = stream
		_retrigger_ms[sound_name] = _retrigger_window(stream)


func _build_voices() -> void:
	for i in UI_VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = &"SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		_ui_voices.append(player)
	for i in WORLD_VOICES:
		var player := AudioStreamPlayer3D.new()
		player.bus = &"SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		player.unit_size = WORLD_UNIT_SIZE
		player.max_distance = WORLD_MAX_DISTANCE
		# Linear rather than the inverse-square default: an arena this small
		# with an inverse-square curve is either deafening at the base circle or
		# inaudible at the throwing line, and there is no unit size that is both.
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		_world_voices.append(player)


## ---------------------------------------------------------------------------
## PLAYBACK
## ---------------------------------------------------------------------------

## Non-positional. Use for UI, and for anything the local player must hear at a
## constant level wherever it happened — round/match results, the countdown.
func play(sound_name: String, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _take(sound_name)
	if stream == null:
		return
	var player := _ui_voices[_ui_next]
	_ui_next = (_ui_next + 1) % _ui_voices.size()
	player.stream = stream
	player.volume_db = volume_db + _trim(sound_name)
	player.pitch_scale = _pitch(sound_name)
	player.play()
	if sound_name in MUSIC_DUCK_TRIGGERS:
		_duck_music()
	# ⚠️ THE MATCH BED STARTS AT THE FIRST COUNTDOWN TICK, NOT AT ROUND_STARTED.
	# `hud.gd::show_countdown_tick`'s only call site is the pre-round 3-2-1-GO
	# (see main.gd's ready phase); `MatchManager.round_started` does not fire
	# until AFTER that countdown finishes (`begin_next_round()` is the last
	# call in main.gd's countdown coroutine). Filed bug: the menu bed was
	# still playing under the ENTIRE countdown and only crossfaded on "GO!" —
	# late by exactly the length of the countdown. `countdown_tick` is that
	# countdown's own SFX name, already unique to this one call site, so
	# hooking it here needs no other file touched, same as the duck above.
	if sound_name == "countdown_tick":
		# ⚠️ FADE 0.0, same reason as the menu bed above. 2026-08-01: *"Remove the
		# audio latency during round initialization. RoundMusic should begin playing
		# immediately when all 4 players click Ready."* `_poll_scene_state()` has
		# already `stop_music_now()`d the menu bed by this point (the "match" branch),
		# so again there is nothing to fade from and the 1.5 s was dead time over the
		# countdown — the exact window the round is supposed to feel like it starts in.
		play_music("match", 0.0)


## Positional. Everything that happens at a place in the arena goes through
## here, so a hit across the map reads as distance rather than as a sound in
## your ear.
##
## `where` is a WORLD position. Callers pass `character.global_position`
## directly; there is deliberately no overload that takes a Node, because a
## transient hitbox's node is routinely freed before its sound has finished and
## parenting audio to it would cut the sound off mid-clang.
func play_at(sound_name: String, where: Vector3, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _take(sound_name)
	if stream == null:
		return
	var player := _world_voices[_world_next]
	_world_next = (_world_next + 1) % _world_voices.size()
	player.stream = stream
	player.global_position = where
	player.volume_db = volume_db + _trim(sound_name)
	player.pitch_scale = _pitch(sound_name)
	player.play()


## Silences every pooled voice at once.
##
## ⚠️ EXISTS BECAUSE THE POOL OUTLIVES THE SCENE THAT STARTED A SOUND. The voices
## are children of this autoload, at PROCESS_MODE_ALWAYS, precisely so a sound
## survives the node that triggered it (a transient hitbox is routinely freed
## before its clang has finished — see play_at's own note). The cost is that a
## sound started on one screen keeps playing on the next one unless somebody says
## otherwise, which is exactly what a skipped boot sting would do: black the
## screen, load the title menu, and leave a chord ringing over it.
##
## Deliberately NOT called on every scene change. Most transitions WANT the tail
## to carry — a `ui_back` that is cut off the instant the panel closes reads as a
## click, not a sound. This is for the one case that is genuinely an interruption.
func stop_all() -> void:
	for player in _ui_voices:
		player.stop()
	for player in _world_voices:
		player.stop()
	# Clear the retrigger memory too, or the sound just stopped is barred from
	# playing again for the rest of its own length — which for the boot sting is
	# two and a half seconds of the title screen.
	_last_played_ms.clear()

## Shared front half of play()/play_at(): resolves the stream and applies the
## retrigger guard. Returns null when this call should be dropped.
func _take(sound_name: String) -> AudioStream:
	var stream: AudioStream = _streams.get(sound_name)
	if stream == null:
		return null
	# Real milliseconds, NOT delta — see the class doc's audio-clock note.
	var window: int = int(_retrigger_ms.get(sound_name, RETRIGGER_MS))
	var now := Time.get_ticks_msec()
	if now - int(_last_played_ms.get(sound_name, -window)) < window:
		return null
	_last_played_ms[sound_name] = now
	return stream


## The real fix for the buzzsaw case (see the ⚠️ note above RETRIGGER_MS): the
## guard has to keep the PREVIOUS voice of this same sound from still being
## audible when a new one starts, not just space out how often a new one is
## allowed to begin. Using the stream's own length means the window scales with
## what it's actually guarding — a 300 ms clang gets ~300 ms, a 40 ms UI tick
## gets ~40 ms — instead of one number that was only ever right for whichever
## sound it was tuned against.
##
## RETRIGGER_MS is kept as a floor, not dropped: `AudioStream.get_length()` can
## come back at or near 0 for a degenerate/corrupt asset, and this guard's
## other job — collapsing the two calls `_flash_hit()`/`_rpc_play_hit_vfx` can
## produce for the same hit inside a single frame (see character_base.gd) — is
## a same-frame guard that still needs to hold regardless.
func _retrigger_window(stream: AudioStream) -> int:
	var length_ms := int(roundf(stream.get_length() * 1000.0))
	return maxi(RETRIGGER_MS, length_ms)


## B-121: headroom + the per-sound trim, in one place so no call site can apply
## one and forget the other. The `minf(..., 0.0)` is a backstop, not decoration
## — a positive trim is exactly the bug this fixed, and clamping it here means
## re-introducing one costs volume rather than causing clipping.
func _trim(sound_name: String) -> float:
	return HEADROOM_DB + minf(float(_TRIM_DB.get(sound_name, 0.0)), 0.0)


func _pitch(sound_name: String) -> float:
	if sound_name in _NO_JITTER:
		return 1.0
	return randf_range(1.0 - PITCH_JITTER, 1.0 + PITCH_JITTER)


## ---------------------------------------------------------------------------
## BUS VOLUMES — the Settings panel's three sliders land here.
## ---------------------------------------------------------------------------
##
## SettingsManager owns the values and their persistence; this owns what they
## mean to the mixer. Split that way so the volume model can change (a fourth
## bus, a compressor on Master) without touching the settings file format.

## Called by SettingsManager on load and on every slider move. All three are
## 0..1 linear.
func apply_volumes(master: float, sfx: float, music: float) -> void:
	master_volume = clampf(master, 0.0, 1.0)
	sfx_volume = clampf(sfx, 0.0, 1.0)
	music_volume = clampf(music, 0.0, 1.0)
	_apply_bus("Master", master_volume)
	_apply_bus("SFX", sfx_volume)
	_apply_bus("Music", music_volume)


## ⚠️ MUTES AT ZERO RATHER THAN TRUSTING linear_to_db(0.0).
##
## `linear_to_db(0.0)` is -INF, and assigning that to a bus volume is undefined
## rather than silent — depending on the mixer path it is either -80 dB (audible
## in a quiet room, so "off" is not off) or a NaN that poisons the bus. An
## explicit mute is the only way a slider dragged to the left end is actually
## silence. The threshold is a slider step below the minimum, not exactly 0.0,
## so a float that lands on 0.0009 still counts as off.
func _apply_bus(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_warning("AudioManager: no '%s' bus — is default_bus_layout.tres registered "
			% bus_name + "in project.godot under audio/buses/default_bus_layout?")
		return
	if linear <= 0.001:
		AudioServer.set_bus_mute(index, true)
		return
	AudioServer.set_bus_mute(index, false)
	AudioServer.set_bus_volume_db(index, linear_to_db(linear))
