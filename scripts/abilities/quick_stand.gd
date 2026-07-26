extends AbilityBase
class_name QuickStand

## Sardinas — Quick Stand: instantly self-rights from Downed once/round.
## (See docs/Tumbang_Preso_2v2_GDD.md, Roster: 🥫 Can Class.)
## Session 6: now a real once-per-round charge (AbilityBase.once_per_round),
## reset every round via CharacterBase.reset_for_new_round() — set
## once_per_round = true on quick_stand.tres, `cooldown` no longer matters.

func _do_activate(character: CharacterBody3D) -> bool:
	var c := character as CharacterBase
	if c and c.state == CharacterBase.State.DOWNED:
		c.self_right()
		return true
	return false # B-11: not Downed — this press did nothing, don't burn the charge
