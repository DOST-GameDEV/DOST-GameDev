extends Control
class_name SplashScreen

## The boot sting. `project.godot`'s `run/main_scene` points here, and this hands
## off to the title screen when the clip finishes.
##
## Human call, 2026-07-29: *"I want an opening animation to play every single
## time the game opens ... build a Splash Screen scene that plays at boot before
## transitioning to the Main Menu."* Every time is literal — there is no
## "seen it already" flag and no skip-on-second-launch.
##
## ⚠️ OGG THEORA, NOT MP4. Godot 4 ships exactly one video codec in core —
## `VideoStreamTheora` — and no h.264/webm support at all. The supplied
## `Opening Animation.mp4` (1920x1080, 60fps, 3s) is converted to
## `assets/video/opening_animation.ogv` at 1280x720/30fps, which is
## indistinguishable for a three-second sting and keeps the file at ~180 KB on a
## screen that plays on every single launch. Re-run the conversion with ffmpeg
## `-c:v libtheora -q:v 8 -r 30 -vf scale=1280:720 -an` if the source changes.
##
## ⚠️ IT MUST BE SKIPPABLE AND IT MUST NEVER STRAND THE PLAYER. Two independent
## exits, because a splash that hangs is worse than no splash:
##   1. Any key / click / gamepad button skips immediately.
##   2. `MAX_WAIT` is a hard watchdog. If the video fails to decode, the file is
##      missing from an export, or `finished` never fires on some driver, the
##      game still reaches the menu. A boot screen is exactly the place where a
##      silent failure costs you the whole session.

const MAIN_MENU_PATH: String = "res://scenes/ui/MainMenu.tscn"

## Longest the splash may hold the player, regardless of what the video does.
## The clip is 3.0s; this is that plus generous slack for a slow first-frame
## decode on a cold start.
const MAX_WAIT: float = 6.0

## Ignore input for a moment so a keypress still in the buffer from launching the
## game does not skip the sting before it is visible.
const SKIP_ARMED_AFTER: float = 0.35

@onready var video: VideoStreamPlayer = %Video
@onready var fade: ColorRect = %Fade

var _elapsed: float = 0.0
var _leaving: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	video.finished.connect(_leave)
	video.play()
	# ⚠️ THE STING IS A SEPARATE STREAM, NOT AUDIO ON THE VIDEO, AND IT HAS TO BE.
	#
	# `opening_animation.ogv` is converted with `-an` (see the class doc's ffmpeg
	# line): Godot 4 ships exactly one core video codec and putting audio through
	# Theora costs file size on a clip that plays on every single launch, for a
	# track that then cannot be skipped independently or mixed against the SFX
	# bus. Starting it here instead means it rides the same limiter and the same
	# volume slider as everything else, and `_leave()` fades it out with the
	# picture rather than cutting it dead.
	#
	# ⚠️ AND IT IS STARTED AFTER `video.play()`, DELIBERATELY. The first frame of
	# a cold Theora decode is the slowest thing on this screen; starting the audio
	# first would put the sting ahead of the picture by however long that took,
	# which is different on every machine. Started together, they drift by at most
	# one frame.
	AudioManager.play("boot_sting")
	# Start opaque and fade the black out, so a slow first decode reads as a
	# deliberate fade-in rather than as a frozen black screen.
	fade.color = Color(0, 0, 0, 1)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.35)

func _process(delta: float) -> void:
	_elapsed += delta
	if not _leaving and _elapsed >= MAX_WAIT:
		# See the watchdog note in the class doc — this is the path that fires
		# when the video never reports finishing.
		push_warning("SplashScreen: video did not finish within %.1fs; continuing." % MAX_WAIT)
		_leave()

func _unhandled_input(event: InputEvent) -> void:
	if _leaving or _elapsed < SKIP_ARMED_AFTER:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		_leave()
	elif event is InputEventMouseButton and event.pressed:
		_leave()
	elif event is InputEventJoypadButton and event.pressed:
		_leave()

## Guarded against running twice — `finished`, the watchdog and a skip press can
## all arrive in the same frame, and change_scene_to_file() twice in one frame
## leaves the tree in a state nothing else in this project expects.
func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	set_process_unhandled_input(false)
	if video.is_playing():
		video.stop()
	# The sting goes with the picture. A skip that blacks the screen and leaves
	# a chord playing over the title menu is worse than no sting at all, and
	# AudioManager's pooled voices outlive this scene by design, so stopping it
	# has to be explicit.
	AudioManager.stop_all()
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.22)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file(MAIN_MENU_PATH))
