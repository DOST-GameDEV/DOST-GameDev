extends Node3D
## Isolates WHICH post-process is drawing the horizontal stripes reported
## 2026-07-29 ("why are there lines in what u made"). Renders one fixed view
## with a single effect disabled per shot, so the cause is identified by
## elimination instead of by guessing which slider to move.
const MAP := "res://scenes/maps/Eskinita.tscn"
var _out: String = ""
var _camera: Camera3D
var _env: Environment
var _index := 0
var _settle := 0
const CASES := ["baseline", "no_ssao", "no_ssil", "no_sdfgi", "no_shadow", "no_deband"]

func _ready() -> void:
	var argv := OS.get_cmdline_user_args()
	_out = argv[0] if argv.size() > 0 else ""
	var map: Node3D = load(MAP).instantiate()
	add_child(map)
	_env = (map.get_node("WorldEnvironment") as WorldEnvironment).environment
	_camera = Camera3D.new()
	_camera.fov = 75.0
	_camera.far = 400.0
	add_child(_camera)
	_camera.current = true
	_camera.global_position = Vector3(3.0, 1.7, 6.0)
	_camera.look_at(Vector3(7.5, 2.2, -3.0), Vector3.UP)
	_apply_case()

func _apply_case() -> void:
	var map: Node = get_child(0)
	var case: String = CASES[_index]
	_env.ssao_enabled = case != "no_ssao"
	_env.ssil_enabled = case != "no_ssil"
	_env.sdfgi_enabled = case != "no_sdfgi"
	var light := map.get_node("DirectionalLight3D") as DirectionalLight3D
	light.shadow_enabled = case != "no_shadow"
	ProjectSettings.set_setting("rendering/anti_aliasing/quality/use_debanding",
		case != "no_deband")
	_settle = 60

func _process(_delta: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(_out + "artifact_" + CASES[_index] + ".png")
	print("wrote ", CASES[_index])
	_index += 1
	if _index >= CASES.size():
		set_process(false)
		get_tree().quit(0)
		return
	_apply_case()
