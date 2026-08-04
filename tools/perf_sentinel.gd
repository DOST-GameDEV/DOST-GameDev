extends Node
## One end of the bracket `tools/perf_attrib.gd` measures between. Stamps the
## clock once per frame and does nothing else, so the pair of them — one at the
## lowest `process_priority` in the tree, one at the highest — fence the frame's
## whole script `_process` pass between two timestamps.

var stamp: int = 0

func _process(_delta: float) -> void:
	stamp = Time.get_ticks_usec()
