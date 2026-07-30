extends Node3D
## Bayan Plaza held to Eskinita's acceptance bar: five void shots plus a
## street-level view, and a scene-integrity read.
const MAP := "res://scenes/maps/BayanPlaza.tscn"
## ⚠️ FIVE VOID SHOTS, NOT THREE — this is Eskinita's acceptance bar, ported.
## tools/void_probe.tscn takes the y=30 overhead plus ALL FOUR corners, because
## the void it exists to catch does not have to appear on the two corners somebody
## happened to pick: each corner looks down a different diagonal, past a different
## part of the belt, with a different amount of fog in the way. This map had NE and
## SW only, so half its perimeter had never been looked at from eye level. That is
## R-20's "no five-shot void acceptance", and it was a missing pair of array rows.
const SHOTS := [
	["bp_overhead", Vector3(0, 30, 30), Vector3(0, 0, 0)],
	["bp_corner_ne", Vector3(12.0, 1.6, -12.0), Vector3(60, 6, -60)],
	["bp_corner_nw", Vector3(-12.0, 1.6, -12.0), Vector3(-60, 6, -60)],
	["bp_corner_se", Vector3(12.0, 1.6, 12.0), Vector3(60, 6, 60)],
	["bp_corner_sw", Vector3(-12.0, 1.6, 12.0), Vector3(-60, 6, 60)],
	["bp_eye", Vector3(0, 1.6, 11.0), Vector3(0, 1.4, -14.0)],
	# The monument, from the attacker's own spawn (SpawnPoints/Spawn2 is at
	# 0, y, 6) at FPP eye height. ⚠️ THIS SHOT EXISTS BECAUSE THE OTHER FOUR
	# CANNOT SEE THE THING THE MAP WAS REDRESSED FOR. The brief was "make it
	# seen and we're playing near it", and bp_eye looks straight down the long
	# axis with the monument off-frame to the left — so the map could have
	# shipped with the centrepiece invisible from every shot in the probe and
	# every shot would still have looked fine. Aimed from where a player
	# actually stands, not from a vantage chosen to flatter it.
	["bp_monument", Vector3(0, 1.25, 6.0), Vector3(-7.6, 2.2, 6.4)],
	# ⚠️ THE HAZARD, AIMED AT FROM WHERE A PLAYER MEETS IT. HazardZone is a live
	# 5x5 slow field (speed_multiplier 0.5, permanent) centred on (-6.5, -4.0) and
	# R-20 asks for it to be VISIBLE in a render — which no existing shot could
	# show, because bp_eye looks straight down the long axis and the hazard sits
	# off to one side. An invisible slow field is a player being punished by
	# something they cannot see or learn, so the tell gets its own shot rather
	# than being assumed from the fact that geometry was placed.
	["bp_hazard", Vector3(-1.5, 1.25, -1.0), Vector3(-6.5, 0.2, -4.0)],
	# The plaza read at eye height from the north approach, for the R-33 contrast
	# pair against Eskinita's street_eye: open, civic, paved, fought ACROSS.
	["bp_civic", Vector3(2.0, 1.6, 7.5), Vector3(-2.0, 3.0, -14.0)],
]
var _out := ""
var _cam: Camera3D
var _i := 0
var _settle := 0

func _ready() -> void:
	var a := OS.get_cmdline_user_args()
	_out = a[0] if a.size() > 0 else ""
	var m: Node3D = load(MAP).instantiate()
	add_child(m)
	await get_tree().process_frame
	var meshes := m.find_children("*", "MeshInstance3D", true, false)
	var missing := 0
	for n in meshes:
		if (n as MeshInstance3D).mesh == null:
			missing += 1
	print("MeshInstance3D: ", meshes.size(), "   null mesh: ", missing)
	print("wall east x = ", (m.get_node("Bounds/WallEast") as Node3D).global_position.x)
	print("markings    = ", m.get_node("Markings").get_child_count())
	_cam = Camera3D.new(); _cam.fov = 75.0; _cam.far = 400.0
	add_child(_cam); _cam.current = true
	_place()

func _place() -> void:
	_cam.global_position = SHOTS[_i][1]
	_cam.look_at(SHOTS[_i][2], Vector3.UP)
	_settle = 30

func _process(_d: float) -> void:
	if _settle > 0:
		_settle -= 1
		return
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out + String(SHOTS[_i][0]) + ".png")
	print("wrote ", SHOTS[_i][0])
	_i += 1
	if _i >= SHOTS.size():
		set_process(false)
		get_tree().quit(0)
		return
	_place()
