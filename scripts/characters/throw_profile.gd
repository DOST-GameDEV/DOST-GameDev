extends Resource
class_name ThrowProfile

## How one particular tsinelas flies when it is thrown (Task 0, Option B).
##
## This is what became of the three Tsinelas-class specials. Before Task 0 they
## were self-propelled melee moves on a slipper that walked around under its own
## power — Bagsak Bomb leapt and slammed, Bakya Bash lunged, Flick Dash dashed.
## Now that the slipper is thrown BY a Person rather than being a character that
## charges in, the same three identities survive as launch behaviour:
##
##   Dyaryo / Bagsak Bomb  — high arc, bursts on impact. The lob.
##   Bakya / Bakya Bash    — heavy, flat, slow, knocks the lata flat outright.
##   Havaianas / Flick Dash— fast, low, long, but a lighter hit. The line drive.
##
## Deliberately a Resource and not a pile of constants: the roster is already
## built on "one CharacterBase scene + a different AbilityBase Resource per
## character" (docs/Dev_Plan.md §2), and a throw profile is the same idea. It is
## read off the slipper's own `ability` — see `carriable.gd::_profile()` — so a
## character-select screen that swaps the ability Resource gets the matching
## throw for free, with no branching anywhere.
##
## ⚠️ Duplicate these the same way abilities are duplicated (AI Execution
## Protocol rule 8). A ThrowProfile carries no mutable state today, so sharing
## one is currently harmless — but that is a property of this file right now,
## not a guarantee. If you add so much as a charge counter here, two slippers
## sharing an instance will share it.

## Metres/second at full charge. Charge scales this down to CHARGE_MIN_SCALE of
## it at a tap — see carrier.gd.
@export var launch_speed: float = 17.0
## Upward tilt applied to the thrower's aim, in degrees. This is what makes a lob
## a lob. 0 would be a flat rifle shot straight down the crosshair.
@export var arc_angle_deg: float = 14.0
## Multiplier on CharacterBase.GRAVITY during flight. Above 1 drops fast and
## heavy (Bakya), below 1 floats (a beach flip-flop).
@export var gravity_scale: float = 1.0
## Radius of the hitbox that rides along with the slipper in flight.
## ⚠️ Art_Direction.md §1 — every profile's hit_radius was tuned by eye against
## the old 1.35-unit tsinelas (this one, 0.7, was itself LARGER than the whole
## rescaled 0.432-unit mesh). Halved across all four .tres files for the
## rescaled props, keeping relative ordering (bagsak biggest/lob, flick
## smallest/line-drive). Still generous over the raw mesh, same margin the
## Person's own Hurtbox keeps over its body capsule — exact numbers are
## checklist 4.4's job once a human has actually thrown one.
@export var hit_radius: float = 0.7
## Whether a direct hit knocks the lata flat outright (Option B's Downed state)
## rather than just staggering it. True for every slipper by default — knocking
## the can down IS the game. Bakya keeps it; a lighter slipper could trade it
## away for speed.
@export var forces_downed: bool = true
## Visual spin while airborne, degrees/second. The moodboard's THE SLIPPER card
## calls for "thrown trajectory (spin + motion blur)".
@export var spin_speed_deg: float = 900.0
## How hard the slipper's own player can steer it mid-flight, in metres/second²
## of sideways acceleration. This is what keeps the Prop player a participant
## rather than cargo — see the Task 0 agreement. 0 makes the throw purely the
## thrower's problem.
@export var steer_strength: float = 6.0

## ---------------------------------------------------------------------------
## HEFT — how much this slipper shoves what it hits.
##
## ⚠️ `mass` IS NOT A RIGIDBODY MASS AND THERE IS NO RIGIDBODY HERE. A slipper
## is a CharacterBody3D moved by `move_and_collide` with gravity applied by
## hand (carriable.gd::_step_flying), so Godot never integrates a mass for it
## and setting one would do nothing on its own. This is the knockback
## coefficient the flight code actually reads — the number that decides whether
## a bakya feels like a plank and a havaianas feels like a flip-flop. Trajectory
## is `launch_speed` and `gravity_scale`; this is only impact.
@export var mass: float = 1.0
## Fraction of the slipper's flight speed handed to whatever it hits, as
## metres/second of horizontal velocity. Multiplied by `mass`.
@export var knockback_scale: float = 0.55
## Straight-up metres/second added on impact, so a hit pops the target off the
## floor instead of sliding it along. This is the "flop" half of the faceslop —
## without it a knockdown reads as a shove, not a comedy beat.
@export var knockback_lift: float = 3.2
## Extra multiplier applied only when the hit actually knocks the target DOWN
## (`forces_downed`, or an out-of-base hit — see hitbox.gd's `kind`). A
## staggering graze should nudge; a faceslop should launch.
@export var faceslop_multiplier: float = 1.8
## Degrees/second of TUMBLE about the axis across the direction of travel — the
## end-over-end flip. Distinct from `spin_speed_deg`, which spins the slipper
## about its own long axis; a real thrown slipper does both at once, and doing
## only the second is what made it read as "flying perfectly flat".
@export var tumble_speed_deg: float = 520.0
