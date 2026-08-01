extends Node
## Checklist 4.4 — proves the delivered voice-over actually reaches the pools and
## that the right line comes out of the right event.
##
##   Godot_v4.7.1-stable_win64_console.exe --headless --path . tools/audio/vo_probe.tscn
##
## Exits 0 on all-PASS, 1 on any FAIL, and writes user://vo_probe.txt.
##
## ⚠️ THIS PROBE IS BUILT TO BE ABLE TO GO RED, WHICH § 6 TRAP 3 SAYS IS THE ONLY
## KIND WORTH HAVING. Two of its checks are red proofs of failures that were live
## in this delivery rather than hypotheticals:
##
##   * CHECK 2 asserts the id parse on the names AS DELIVERED. `clock_10.wav`
##     copied in unchanged is read by `_vo_id_from_filename()` as the id
##     **`clock`** — that function strips the LAST underscore segment as the
##     recorder's name, and a bare id whose own name contains an underscore has
##     nothing else to give it. Eight of the eleven delivered files have that
##     shape. The check asserts BOTH directions: the delivered name resolves
##     wrong, the imported name resolves right.
##   * CHECK 1 asserts file count == pooled-stream count. The delivery was
##     AAC-in-3GP named `.wav`; Godot has no AAC decoder, so before
##     `tools/audio/vo_import.py` transcoded them every one of those `load()`
##     calls returned null and every pool stayed empty **while the files sat in
##     the folder**. A probe that only asked "does the folder have files in it"
##     would have been green for exactly the bug that mattered.
##
## It deliberately does NOT claim the recordings say the right words. Nothing in
## this repo can assert that `vo_count_3_1.wav` is somebody saying "Tatlo!" — see
## the § LOG entry, which says so in as many words.

## docs/HUMAN.md TABLE A, as delivered on 2026-08-01. id -> number of takes.
## Hardcoded rather than derived from the directory so that a file going MISSING
## is a failure instead of a smaller expectation.
const EXPECTED_TAKES: Dictionary = {
	"clock_10": 1, "clock_30": 1,
	"count_1": 1, "count_2": 1, "count_3": 1,
	"count_go": 2, "match_draw": 2, "match_win": 2,
}

## Ids that are wired to a live trigger and have NO take yet. Asserted empty on
## purpose: "an empty pool is expected, not a defect" is the lane's stated
## contract and a silent regression to a non-empty pool here would mean a file
## landed under a name nobody checked.
const EXPECTED_EMPTY: PackedStringArray = [
	"tumbang", "taya", "ayos", "bilis", "title", "lata_restored",
]

## A trimmed line. Anything outside this either kept its silence (the head-pad
## bug `vo_import.py` exists to fix) or is not a voice line at all.
const MIN_LEN_S: float = 0.30
const MAX_LEN_S: float = 3.00

var _log: PackedStringArray = []
var _fails: PackedStringArray = []


func _emit(line: String) -> void:
	print(line)
	_log.append(line)


func _check(label: String, ok: bool, detail: String = "") -> void:
	_emit("  %s %s%s" % ["PASS" if ok else "FAIL", label, "" if ok else "   <-- " + detail])
	if not ok:
		_fails.append(label)


func _ready() -> void:
	_emit("=== VO PROBE — checklist 4.4 ===")
	_emit("")

	var takes: Dictionary = AudioManager._vo_takes

	# --- 1 · every file on disk became a pooled stream -----------------------
	_emit("1 · the delivery reached the pools")
	var on_disk := _wav_files()
	var pooled := 0
	for id in takes:
		pooled += (takes[id] as Array).size()
	_check("1a every .wav in %s loaded as a stream (%d on disk)" % [AudioManager.VO_DIR, on_disk.size()],
		pooled == on_disk.size(),
		"%d file(s) on disk but %d stream(s) pooled — a codec Godot cannot read loads as null" % [
			on_disk.size(), pooled])

	# --- 2 · the naming the pooling actually reads ---------------------------
	# The red proof. `_vo_id_from_filename()` strips `vo_` and the LAST segment.
	_emit("")
	_emit("2 · the id parse, including what the DELIVERED names would have done")
	_check("2a 'vo_clock_10_1.wav' -> 'clock_10'",
		AudioManager._vo_id_from_filename("vo_clock_10_1.wav") == "clock_10",
		"got '%s'" % AudioManager._vo_id_from_filename("vo_clock_10_1.wav"))
	_check("2b RED PROOF: the delivered 'vo_clock_10.wav' would have been 'clock'",
		AudioManager._vo_id_from_filename("vo_clock_10.wav") == "clock",
		"got '%s' — if this changed, vo_import.py's renaming rule needs revisiting" % \
			AudioManager._vo_id_from_filename("vo_clock_10.wav"))
	_check("2c 'vo_count_1_1.wav' -> 'count_1', not 'count'",
		AudioManager._vo_id_from_filename("vo_count_1_1.wav") == "count_1",
		"got '%s'" % AudioManager._vo_id_from_filename("vo_count_1_1.wav"))
	_check("2d 'vo_count_go_2.wav' -> 'count_go'",
		AudioManager._vo_id_from_filename("vo_count_go_2.wav") == "count_go",
		"got '%s'" % AudioManager._vo_id_from_filename("vo_count_go_2.wav"))

	# --- 3 · the pools hold what was delivered ------------------------------
	_emit("")
	_emit("3 · take counts per id")
	for id in EXPECTED_TAKES:
		var want: int = EXPECTED_TAKES[id]
		var got: int = (takes.get(id, []) as Array).size()
		_check("3·%-11s %d take(s)" % [id, want], got == want, "got %d" % got)

	# --- 4 · every stream is real and trimmed -------------------------------
	_emit("")
	_emit("4 · every pooled stream decodes and is trimmed")
	for id in takes:
		var i := 0
		for stream in (takes[id] as Array):
			var s := stream as AudioStream
			var len_s := s.get_length() if s != null else -1.0
			_check("4·%s[%d] %.2fs in [%.2f, %.2f]" % [id, i, len_s, MIN_LEN_S, MAX_LEN_S],
				s != null and len_s >= MIN_LEN_S and len_s <= MAX_LEN_S,
				"length %.3f" % len_s)
			i += 1

	# --- 5 · wired-but-undelivered stays empty and stays harmless -----------
	_emit("")
	_emit("5 · the empty pools are empty, and calling them is a no-op")
	for id in EXPECTED_EMPTY:
		_check("5·%-13s no take yet (trigger stays wired)" % id,
			(takes.get(id, []) as Array).is_empty(),
			"pool is not empty — did a file land under an unchecked name?")
		AudioManager.play_vo(id) # must not crash

	# --- 6 · the countdown says the right number ----------------------------
	# The behavioural check: `play_countdown()` is the only path from the HUD's
	# "3" to the announcer's "Tatlo!", and it is the one piece of this that a
	# reading cannot confirm.
	_emit("")
	_emit("6 · play_countdown() routes each tick to its own line")
	for pair in [["3", "count_3"], ["2", "count_2"], ["1", "count_1"], ["GO!", "count_go"]]:
		var text: String = pair[0]
		var want_id: String = pair[1]
		var slot: int = AudioManager._vo_next
		AudioManager.play_countdown(text)
		var got: AudioStream = AudioManager._vo_voices[slot].stream
		var want: Array = takes.get(want_id, [])
		_check("6·'%s' -> a %s take" % [text, want_id],
			got != null and want.has(got),
			"voice %d holds %s" % [slot, got])
		_check("6·'%s' plays at VO_TRIM_DB (%.1f dB)" % [text, AudioManager.VO_TRIM_DB],
			is_equal_approx(AudioManager._vo_voices[slot].volume_db, AudioManager.VO_TRIM_DB),
			"volume_db = %.2f — voice would sit ~%.1f dB over every SFX" % [
				AudioManager._vo_voices[slot].volume_db,
				AudioManager._vo_voices[slot].volume_db - AudioManager.HEADROOM_DB])

	# --- 7 · a tick nobody recorded is silence, not a wrong number -----------
	_emit("")
	_emit("7 · an unrecorded count degrades to silence")
	var slot5: int = AudioManager._vo_next
	var before: AudioStream = AudioManager._vo_voices[slot5].stream
	AudioManager.play_countdown("5") # count_5 is a real id with no take
	_check("7a a '5' tick plays no voice at all",
		AudioManager._vo_voices[slot5].stream == before,
		"something was assigned to voice %d" % slot5)

	_finish()


func _wav_files() -> PackedStringArray:
	var out: PackedStringArray = []
	var dir := DirAccess.open(AudioManager.VO_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var f := dir.get_next()
	while f != "":
		if not dir.current_is_dir() and f.begins_with("vo_") and f.ends_with(".wav"):
			out.append(f)
		f = dir.get_next()
	dir.list_dir_end()
	return out


func _finish() -> void:
	_emit("")
	if _fails.is_empty():
		_emit("VO PROBE: all checks PASS")
	else:
		_emit("VO PROBE: %d FAIL — %s" % [_fails.size(), ", ".join(_fails)])
	# Same reason music_probe.gd writes a file: the plain Windows exe does not
	# reliably deliver stdout to a redirected pipe.
	var file := FileAccess.open("user://vo_probe.txt", FileAccess.WRITE)
	if file != null:
		file.store_string("\n".join(_log) + "\n")
		file.close()
		print("wrote ", ProjectSettings.globalize_path("user://vo_probe.txt"))
	get_tree().quit(0 if _fails.is_empty() else 1)
