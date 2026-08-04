extends MeshInstance3D
class_name MotionBlur

## The node half of `assets/shaders/motion_blur.gdshader` — it exists only to hand
## the shader last frame's view-projection matrix and to stay attached to whichever
## camera is currently drawing.
##
## 🧑 2026-08-04: *"can u build ur own motion blur but keep it off unless ticked on
## in settings"*. Created and freed by `SettingsManager.apply_graphics()`; nothing
## else instantiates it, and with the tick off the node does not exist at all —
## which is stronger than `visible = false`, because a hidden fullscreen quad still
## costs a cull and still holds the screen-texture copy alive.
##
## ⚠️ IT REPARENTS ITSELF TO THE CURRENT CAMERA. This game changes camera constantly
## — FPP to TPP on the emote/spectate paths, a different rig every round as the taya
## rotates, and `debug_player_switcher.gd` on Tab. A quad parented to one camera at
## creation would blur that camera's view into everyone else's. `get_camera_3d()` is
## the viewport's own answer to "who is drawing", so it cannot disagree with what is
## on screen.
##
## ⚠️ THE MATRIX IS STAMPED IN `_process`, AFTER EVERYTHING ELSE HAS MOVED.
## `process_priority` is deliberately high: camera_rig.gd writes camera position in
## its own `_process`, so reading the transform before that would stamp a matrix one
## frame stale in a way that varies with node order — blur that flickers with the
## scene tree is worse than no blur.

const SHADER_PATH: String = "res://assets/shaders/motion_blur.gdshader"

var _camera: Camera3D = null
var _prev_view_proj: Projection = Projection()
var _has_prev: bool = false
var _material: ShaderMaterial = null

func _ready() -> void:
	process_priority = 5000
	# A 2x2 quad, because the vertex shader reads VERTEX.xy directly and turns it
	# into clip space. Nothing about this mesh's size or position reaches the screen.
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mesh = quad
	_material = ShaderMaterial.new()
	_material.shader = load(SHADER_PATH)
	material_override = _material
	# ⚠️ NEVER CULLED. The quad's real bounds are a 2 m square wherever the camera
	# happens to be, but it draws fullscreen — so any culling decision made from
	# those bounds is wrong. A large extra margin keeps it submitted.
	extra_cull_margin = 16384.0
	cast_shadow = SHADOW_CASTING_SETTING_OFF
	# ⚠️ AFTER EVERYTHING. It reads the screen texture, so it has to be the last
	# opaque thing drawn or it blurs a half-finished frame.
	_material.render_priority = 127
	set_notify_transform(false)

func _process(_delta: float) -> void:
	var vp := get_viewport()
	if vp == null:
		return
	var cam := vp.get_camera_3d()
	if cam == null:
		return
	if cam != _camera:
		_camera = cam
		# ⚠️ THE HISTORY IS DROPPED ON A CAMERA CHANGE, NOT CARRIED OVER. Reprojecting
		# the new camera's pixels against the old camera's matrix is a full-screen
		# smear on the first frame after every cut — see `max_travel` in the shader,
		# which is the second line of defence for the same failure.
		_has_prev = false
		var parent := get_parent()
		if parent != cam:
			if parent != null:
				parent.remove_child(self)
			cam.add_child(self)
	if not _has_prev:
		_prev_view_proj = _view_proj(cam)
		_has_prev = true
		# One frame with no history is one frame with no blur, which is correct.
		_material.set_shader_parameter("prev_view_proj", _prev_view_proj)
		return
	_material.set_shader_parameter("prev_view_proj", _prev_view_proj)
	_prev_view_proj = _view_proj(cam)

## ⚠️ `get_camera_projection()`, NOT a matrix rebuilt from fov/near/far. The rig
## changes FOV live (sprint, charge), and a hand-built projection would disagree
## with the one the frame was actually drawn with the moment it did.
func _view_proj(cam: Camera3D) -> Projection:
	return cam.get_camera_projection() * Projection(cam.global_transform.affine_inverse())
