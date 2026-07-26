extends AbilityBase
class_name QuickStand

## Sardinas — Quick Stand: instantly self-rights from Downed once/round.
## (See docs/Tumbang_Preso_2v2_GDD.md, Roster: 🥫 Can Class.)
## "Once/round" vs. the generic cooldown-based AbilityBase timer is a small design
## choice still open — for now this uses the standard cooldown (set cooldown to
## something long, e.g. 90s = the round timer, in the .tres resource to approximate
## "once per round" until RoundManager can reset ability charges on round start).

func _do_activate(character: CharacterBody3D) -> void:
	var c := character as CharacterBase
	if c and c.state == CharacterBase.State.DOWNED:
		c.self_right()
