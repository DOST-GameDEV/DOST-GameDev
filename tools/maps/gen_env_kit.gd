extends Node
## Regenerates the ENVIRONMENT KIT alone, as a SCENE, and then quits.
##
##     godot --headless --path <ABS> tools/maps/gen_env_kit.tscn
##
## ⚠️ THIS EXISTS BECAUSE `-s tools/models/generate_all.gd` HANGS FOREVER, and
## the hang is not a slow generator — it is a missing `quit()`. That file
## `extends SceneTree` and does all its work in `_initialize()`, but a SceneTree
## MainLoop keeps iterating after `_initialize()` returns unless something asks
## it to stop, and nothing does. So the documented command writes every mesh in a
## second or two and then idles until it is killed — and because a killed process
## loses its buffered stdout, the run also appears to have produced NO OUTPUT AT
## ALL. That combination reads exactly like "the generator is hanging on my new
## geometry" and is nothing of the kind.
##
## `tools/models/generate_all.gd` is outside this lane's write allowlist, so the
## missing `quit()` is REPORTED rather than fixed here. See the final report.
##
## ⚠️ AND IT IS A SCENE, NOT `-s`, WHICH IS THE SECOND REASON. `-s` does not load
## autoloads (machine note, and Concurrency_Protocol's own rule for probes), and
## every colour in env_kit.gd comes from the `UiTheme` autoload. Under `-s` those
## are unresolved at parse time; run as a scene they are simply there.
##
## Regenerating the kit ALONE is also the right scope: the lata, the tsinelas and
## the viewmodel arm are another lane's meshes and re-emitting them here would put
## their bytes in this lane's diffs. Determinism means a no-op run leaves
## `git status` clean, so re-running this cannot churn anything it does not own.

const EnvKit = preload("res://tools/models/env_kit.gd")
## The same constant generate_all.gd uses. Deliberately not imported from it —
## that file is a SceneTree and loading it would start its MainLoop.
const OUTPUT_DIR: String = "res://assets/models/"


func _ready() -> void:
	print("regenerating environment kit -> ", OUTPUT_DIR)
	EnvKit.new().build_all(OUTPUT_DIR)
	print("env kit: done")
	# The whole point. Without this the process idles exactly as generate_all.gd
	# does, and the next person spends twenty minutes deciding whether their
	# geometry is slow.
	get_tree().quit(0)
