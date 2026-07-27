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
