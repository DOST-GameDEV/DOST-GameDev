extends Control
class_name SplashScreen


const MAIN_MENU_PATH: String = "res://scenes/ui/MainMenu.tscn"

const MAX_WAIT: float = 6.0

const SKIP_ARMED_AFTER: float = 0.35

@onready var video: VideoStreamPlayer = %Video
@onready var fade: ColorRect = %Fade

var _elapsed: float = 0.0
var _leaving: bool = false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	video.finished.connect(_leave)
	video.play()
	AudioManager.play("boot_sting")
	fade.color = Color(0, 0, 0, 1)
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.35)

func _process(delta: float) -> void:
	_elapsed += delta
	if not _leaving and _elapsed >= MAX_WAIT:
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

func _leave() -> void:
	if _leaving:
		return
	_leaving = true
	set_process_unhandled_input(false)
	if video.is_playing():
		video.stop()
	AudioManager.stop_all()
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 1.0, 0.22)
	tween.tween_callback(func() -> void:
		get_tree().change_scene_to_file(MAIN_MENU_PATH))

