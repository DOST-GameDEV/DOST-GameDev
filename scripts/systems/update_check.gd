extends Node
## Registered as the "UpdateCheck" autoload. Asks GitHub once, at boot, whether a
## newer build has been published, and says so on screen if one has.
##
## 🧑 2026-08-07: *"can we add a version checker so it prompts to install updates
## when pushed"*.
##
## ---------------------------------------------------------------------------
## ⚠️⚠️ WHY THIS DOES NOT READ `project.godot` OFF THE BRANCH, WHICH WAS THE
## OBVIOUS DESIGN.
## ---------------------------------------------------------------------------
## The tempting version of this is one HTTP GET of
## `raw.githubusercontent.com/.../main/project.godot`, parsing `config/version`
## and comparing it to our own. It needs no new files and reuses the number the
## docs already tell everyone to bump.
##
## It would also never have fired once. `config/version` has read **"4.68"** for
## the entire life of this branch — through the whole HARRYDAKS pivot, the model
## overhaul, the audio work and every merge into `main` — because the rule that
## says to bump it ("feature commits do not bump it; the merge does") is a rule
## somebody has to remember, and nobody did. A checker whose trigger depends on a
## remembered manual step is a checker that reports "you are up to date" forever,
## which is worse than no checker at all: it actively tells the player a lie.
##
## So the trigger is a MANIFEST that is written by the same script that publishes
## the build (`tools/release.py`), and the version bump is a side effect of
## publishing rather than a thing to remember. The manifest also carries the
## download URL and the release notes, which a version string cannot.
##
## ⚠️ IF THE MANIFEST IS MISSING OR MALFORMED THIS GOES QUIET, NEVER LOUD. Every
## failure path below ends in "no update banner": offline, DNS dead, GitHub 404,
## rate-limited, garbage JSON, a version we cannot parse. A false "you are up to
## date" is the safe wrong answer; a false "there is an update" sends somebody to
## download a build that does not exist.
## ---------------------------------------------------------------------------

## Where the manifest lives. `raw.githubusercontent.com` rather than the API:
## no rate limit worth worrying about, no token, and it is the same host the
## build zip itself is served from.
##
## ⚠️ POINTS AT `main`, DELIBERATELY, not at whatever branch this build came off.
## A player runs whatever is published; feature branches are not published.
const MANIFEST_URL: String = "https://raw.githubusercontent.com/DOST-GameDEV/DOST-GameDev/main/build/latest.json"

## Long enough for a slow cafe connection, short enough that nothing waits on it.
## Nothing does wait on it — the check is fire-and-forget and the UI subscribes.
const TIMEOUT_SECONDS: float = 8.0

## ⚠️ THE CHECK IS SKIPPED IN THE EDITOR AND IN EVERY PROBE. A hundred probe runs
## a session, each firing a request at GitHub, is rude and would eventually get
## the IP throttled — and no probe is testing the network. `OS.has_feature`
## reports "editor" for an editor/`--path` run and "template" for an exported
## build, which is exactly the distinction wanted: only a real shipped build asks.
const ONLY_IN_EXPORTED_BUILDS: bool = true

signal update_found(latest_version: String, notes: String)

var available: bool = false
var latest_version: String = ""
var download_url: String = ""
var notes: String = ""

var _request: HTTPRequest = null


func _ready() -> void:
	# Autoloads run before any scene, so this is the earliest the request can
	# start — and it costs the boot nothing, because nothing awaits it.
	if ONLY_IN_EXPORTED_BUILDS and OS.has_feature("editor"):
		return
	_request = HTTPRequest.new()
	_request.timeout = TIMEOUT_SECONDS
	# Survives the splash -> menu scene change like the rest of this autoload.
	_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_request)
	_request.request_completed.connect(_on_completed)
	# A failure to even START the request is as silent as a failed one.
	if _request.request(MANIFEST_URL) != OK:
		_request.queue_free()
		_request = null


## Forces a check regardless of the editor gate. For `tools/ui/update_probe.tscn`,
## which has to be able to exercise this from a non-exported run.
func check_now(url: String = MANIFEST_URL) -> void:
	if _request != null and is_instance_valid(_request):
		_request.queue_free()
	_request = HTTPRequest.new()
	_request.timeout = TIMEOUT_SECONDS
	_request.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_request)
	_request.request_completed.connect(_on_completed)
	if _request.request(url) != OK:
		_request.queue_free()
		_request = null


func _on_completed(result: int, code: int, _headers: PackedStringArray,
		body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return
	apply_manifest(body.get_string_from_utf8())


## ⚠️ SPLIT OUT OF `_on_completed()` SO IT CAN BE TESTED WITHOUT A NETWORK, and
## the split is a real improvement rather than a testing hook bolted on. Everything
## that can actually be WRONG here — the JSON shape, the missing key, the version
## comparison, the "went quiet on junk" contract — lives in this function, and
## none of it has anything to do with HTTP. `tools/ui/update_probe.tscn` calls it
## with fixtures.
##
## The first version of the probe tried to exercise the real transport by pointing
## `check_now()` at a `file://` URL, which Godot's `HTTPRequest` silently will not
## fetch — so the test failed for a reason that had nothing to do with the code
## under test. That is the tell that the seam was in the wrong place.
##
## Returns true when an update was accepted, so a caller can tell "no update" from
## "could not read that".
func apply_manifest(text: String) -> bool:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var manifest: Dictionary = parsed
	var remote := String(manifest.get("version", "")).strip_edges()
	if remote.is_empty():
		return false
	if not is_newer(remote, GameVersion.string()):
		return false
	latest_version = remote
	download_url = String(manifest.get("url", ""))
	notes = String(manifest.get("notes", ""))
	available = true
	update_found.emit(latest_version, notes)
	return true


## True when `remote` is a strictly later version than `local`.
##
## ⚠️ COMPARED PART BY PART AS INTEGERS, NOT AS STRINGS OR FLOATS. "4.9" and
## "4.10" are the case that breaks both shortcuts: as strings "4.10" < "4.9",
## and as floats 4.10 == 4.1 < 4.9. This project is at 4.68 and will cross 4.9
## within a few releases, so that is a live trap rather than a theoretical one.
##
## A part that is not an integer makes the whole comparison return false — the
## quiet answer — rather than guessing.
static func is_newer(remote: String, local: String) -> bool:
	var a := remote.split(".")
	var b := local.split(".")
	for i in range(maxi(a.size(), b.size())):
		var left_text: String = a[i] if i < a.size() else "0"
		var right_text: String = b[i] if i < b.size() else "0"
		if not left_text.is_valid_int() or not right_text.is_valid_int():
			return false
		var left := int(left_text)
		var right := int(right_text)
		if left != right:
			return left > right
	return false


## Sends the player to the download. `OS.shell_open` rather than downloading and
## unpacking over ourselves: replacing a running executable is a platform-specific
## job with a real chance of leaving a half-written install, and this is a jam
## build with a zip on GitHub. The browser is the installer.
func open_download() -> void:
	if download_url.is_empty():
		return
	OS.shell_open(download_url)
