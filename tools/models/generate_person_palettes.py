"""Emits assets/characters/persons/materials/person_<id>.tres — the roster palettes.

    python tools/models/generate_person_palettes.py    # run from the repo root

WHY THIS EXISTS. Checklist 2.3 / M-5 gave the two match Persons a palette-remap
material (`person_palette.gdshader`) precisely so "recolouring a Person is 16
colours in a .tres — text, diffable, no binary, and the CC0 .glb stays
pristine". The character-select roster is that sentence taken at its word: every
character below is one of the SAME twelve Kenney rigs wearing a different
palette. No new geometry, no new rig, no re-export.

⚠️ HUMAN INSTRUCTION, 2026-07-29: "dont create other models use existing ones,
js edit these models". That is what this file does, and it is also why there is
no .glb anywhere in this pipeline. Editing a model here means editing its
COLOURS, which is the only part of a Kenney mini that is ours to edit — the
meshes and the rig are CC0 assets we ship unmodified (see KENNEY_LICENSE.txt).

⚠️ AND IT IS WHY THE FPP/CAMERA WORK KEEPS WORKING. Second human instruction the
same day: "edit these models with what we did to our models (fpp view, camera
etc)". Because a roster character is the same .glb with a different material,
every system that was ever tuned against a Person still applies to it unchanged
and by construction, not by re-doing the work per character:
  * camera_rig.gd's FPP self-hide walks `Visual`'s GeometryInstance3D children
    and sets cast_shadow — it never names a mesh, so it covers any palette.
  * The viewmodel arms, the 1.25 eye height and the 1.6 capsule are properties
    of the Person ROLE, not of the model.
  * character_visual.gd's `_align_to_capsule_floor` measures the instanced model
    rather than assuming a height, so a roster pick cannot float or sink.
  * The hit flash still works because `albedo_color` stays a BLEND TARGET with
    alpha 0 at rest — see the shader's own note. Every palette below sets it.

THE ONE HARD CONSTRAINT — SLOT 8 STAYS DARK.

`person_palette.gdshader` documents it and it is not negotiable: eyes, eyebrows
and mouth are drawn in slot 8's cells, distinguished from the hair/top around
them only by position INSIDE a cell, which is below the shader's resolution. A
light slot 8 does not give you a light-haired character, it gives you a
character with no face. `_check()` below aborts the build rather than trusting
anyone to remember.
"""
import os
import sys

OUT_DIR = os.path.join("assets", "characters", "persons", "materials")
SHADER = "res://assets/characters/persons/materials/person_palette.gdshader"
COLORMAP = "res://assets/characters/persons/Textures/colormap.png"
OUTLINE = "res://assets/characters/persons/materials/person_outline.tres"

# The stock Kenney atlas, slot by slot — the baseline every palette starts from
# so an entry only has to state what it CHANGES. Measured from colormap.png by
# the shader's own table; do not retype it from memory.
#   0 cream   1 green    2 amber    3 orange
#   4 red     5 blue     6 pale     7 purple
#   8 dkgrey  9 bluegrey 10 slate   11 ltblue
#   12 white  13 skinmid 14 brown   15 skinlt
BASE = [
    "fde4c7", "61cb8b", "ffc044", "ff7e44",
    "cf534f", "6794d9", "d0e8ff", "a878e8",
    "38383d", "868ba1", "4f5260", "a0a8c9",
    "ffffff", "f1976c", "b06041", "f2bf99",
]

# ⚠️⚠️ WHICH SLOTS EACH RIG ACTUALLY USES — MEASURED, NEVER ASSUMED. ⚠️⚠️
#
# `person_palette.gdshader`'s slot table was measured against male-f and
# female-f ONLY, and it says so. The first version of this generator quietly
# treated it as universal — "slot 1 is the shirt, slot 9 is the shorts" — and
# assigned colours per slot on that basis. It rendered as stock Kenney colours on
# most of the roster, because the other ten rigs do not sample those cells at
# all: male-c has no slot 1 and male-d has neither 1 nor 9, so their "shirt
# colour" was being written into a cell nothing on the model reads.
#
# These counts are vertices-per-slot, dumped straight out of each .glb's UV set
# by walking `surface_get_arrays()` and binning by the shader's own
# `(col / 2) + (row >= 12 ? 8 : 0)`. Re-derive them the same way if the rigs are
# ever re-exported; do not edit them by hand.
MEASURED_SLOTS = {
    "character-male-a":   [1, 2, 5, 8, 11, 12, 13, 14],
    "character-male-b":   [4, 5, 8, 11, 13, 14, 15],
    "character-male-c":   [2, 5, 8, 9, 13, 15],
    "character-male-d":   [4, 8, 12, 13, 15],
    "character-male-e":   [2, 8, 9, 11, 12, 14, 15],
    "character-male-f":   [1, 8, 9, 13, 15],
    "character-female-a": [5, 7, 8, 11, 12, 13, 14, 15],
    "character-female-b": [2, 7, 8, 12, 13, 15],
    "character-female-c": [4, 5, 8, 9, 12, 13, 15],
    "character-female-d": [8, 9, 12, 13, 15],
    "character-female-e": [5, 8, 11, 12, 13, 15],
    "character-female-f": [2, 5, 7, 8, 9, 11, 12, 13, 14, 15],
}

# Slots a colourway must never be written into, whatever a rig uses them for.
#   8         the face — see the module docstring, this is the hard one.
#   13/14/15  the skin ramp. Which of the three is skin DIFFERS BY RIG (male-a
#             carries most of its skin in 14 and barely touches 13; male-f is the
#             other way round), so rather than guess per rig, all three take the
#             character's skin ramp and none is ever available as a garment.
#             That is also why a skin-family BROWN is right for 14 on every rig:
#             where it is hair instead of skin it reads as dark hair, which is
#             correct for all twelve.
#   12        stock white, and on several rigs it is the eye whites rather than
#             shoe soles. Painting a colourway into it gives a character coloured
#             eyeballs. Left alone.
RESERVED_SLOTS = {8, 12, 13, 14, 15}

# Skin ramps, darkest to lightest: slots 13, 14, 15. Three rather than two
# because 14 sits between them on every rig that uses it as skin, and reads as
# hair on the rest.
SKIN = {
    "fair":   ("e8a07a", "8a5a3e", "f7c9a6"),
    "warm":   ("d98a5f", "72452c", "f0b184"),
    "tan":    ("b9714a", "5e3722", "d99a6c"),
    "deep":   ("8a4f32", "42261a", "b0714a"),
}

# ⚠️ SLOT 8 IS ALWAYS ONE OF THESE. All are dark enough to keep a face readable;
# they differ only in hue so two characters do not read as identical from behind.
DARK = {
    "ink":    "38383d",
    "coffee": "31241d",
    "navy":   "22283a",
    "plum":   "31212b",
}

## The roster. `model` is the Kenney rig this character wears; `slots` is what it
## changes about the stock atlas. Names are Filipino and deliberately the kind a
## neighbourhood actually uses — nicknames and honorifics, not formal names,
## because this is a street game played by the people on that street.
## `colourway` is applied to whichever garment slots THAT RIG actually uses, in
## ascending slot order, cycling if the rig uses more slots than the colourway
## has colours. So an entry states a character's palette rather than a mapping
## onto cells it cannot know — which is the whole lesson of MEASURED_SLOTS above.
##
## Order the colours main-garment first: rigs differ in how many garment slots
## they carry (male-d has one, male-a has four), so the first colour is the one
## guaranteed to land on every character and should be the one you would name if
## asked what they wear.
ROSTER = [
    # ⚠️⚠️ person_a / person_b ARE EMITTED HERE NOW, AND THE COMMENT THAT SAID THEY
    # MUST NOT BE IS DELETED RATHER THAN AMENDED. It read: "they are the two match
    # Persons the art direction was signed off against, and Art_Direction.md pins
    # their look."
    #
    # That sign-off is from 2026-07-28, when a match had exactly TWO Persons. The
    # twelve-character roster landed the NEXT DAY (08efb6e, 2026-07-29) and generated
    # the other ten through this script — so for four days BERTO and MARING have been
    # the only two characters in the game wearing a palette authored against a
    # different brief, by a different method, for a game with a different player count.
    #
    # 🧑 2026-08-01, on seeing it in a live match: *"why is there one thats a
    # completely diff texture and no outline"* and *"that hand authored work is stale
    # work from the model overhaul that we stopped"*. Rendered side by side
    # (`tools/ui/person_lineup_shot.tscn`) the two of them read visibly flatter and
    # more washed-out than the ten beside them, which is what a hand-tuned palette
    # against a superseded moodboard looks like next to a generated set.
    #
    # ⚠️ THE FILENAMES ARE KEPT (`id="a"` / `id="b"` → person_a.tres / person_b.tres)
    # so `character_roster.gd` needs no edit and nothing else in the project has to
    # learn a new path. What changes is that all twelve palettes now come out of one
    # generator, one BASE table and one face-luminance check.
    dict(id="a", name="BERTO", tagline="Ang bida. Laging nasa kalye.",
         model="character-male-f", skin="warm", dark="ink",
         colourway=["3f8f5c", "b0864a", "3a4238"]),
    dict(id="b", name="MARING", tagline="Kalaro mula pagkabata. Mahirap talunin.",
         model="character-female-f", skin="fair", dark="coffee",
         colourway=["8a3446", "e8d8c0", "3a4a5c"]),
    dict(id="totoy", name="TOTOY", tagline="Palaboy ng eskinita. Mabilis tumakbo.",
         model="character-male-a", skin="warm", dark="ink",
         colourway=["2f7d4f", "d8b04a", "3b4252", "e0702c"]),
    dict(id="inday", name="INDAY", tagline="Tindera sa kanto. Walang takot.",
         model="character-female-a", skin="tan", dark="plum",
         colourway=["c2543f", "e0b43c", "7a3f5e"]),
    dict(id="kuya-boy", name="KUYA BOY", tagline="Panganay. Siya ang taya, lagi.",
         model="character-male-b", skin="deep", dark="coffee",
         colourway=["2a4a7a", "d8b04a", "2b2f38"]),
    dict(id="ate-girlie", name="ATE GIRLIE", tagline="Reyna ng patintero. Ngayon, tumbang preso.",
         model="character-female-b", skin="fair", dark="navy",
         colourway=["d94f6a", "2f5a7a", "e8d8c0"]),
    dict(id="tikboy", name="TIKBOY", tagline="Laging may tsinelas na isa lang.",
         model="character-male-c", skin="tan", dark="ink",
         colourway=["c25a3a", "6a9e4a", "4a4238"]),
    dict(id="bebang", name="BEBANG", tagline="Malakas ang tama. Wag mo lang asarin.",
         model="character-female-c", skin="warm", dark="coffee",
         colourway=["7ab04a", "8a3a3a", "e0c07a"]),
    dict(id="jun-jun", name="JUN-JUN", tagline="Bunso. Maliit pero mailap.",
         model="character-male-d", skin="fair", dark="navy",
         colourway=["e8c24a", "c24a4a", "3a4a5c"]),
    dict(id="lola-pacing", name="LOLA PACING", tagline="Nanonood sa may bintana. Minsan sumasali.",
         model="character-female-d", skin="fair", dark="ink",
         colourway=["8a7a6a", "b0a89a", "5c5248"]),
    dict(id="mang-kanor", name="MANG KANOR", tagline="Tricycle driver. Alam ang bawat kanto.",
         model="character-male-e", skin="deep", dark="coffee",
         colourway=["4a6a8a", "a85a2a", "2f2a24"]),
    dict(id="aling-nena", name="ALING NENA", tagline="May-ari ng sari-sari. Siya ang referee.",
         model="character-female-e", skin="tan", dark="plum",
         colourway=["e07a3a", "3a5c4a", "d0c0a8"]),
]


def rgb(hex_str):
    """'rrggbb' -> the four floats Godot's PackedColorArray literal wants."""
    h = hex_str.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)) + (1.0,)


def luminance(hex_str):
    r, g, b, _ = rgb(hex_str)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


## ⚠️ SLOT 8 CARRIES THE FACE — see the module docstring. This is the check that
## makes that a build failure rather than a note somebody has to remember.
## 0.30 is comfortably above the darkest skin tone in SKIN (deep, ~0.10 shadow /
## ~0.20 light) so a face still reads against it, and comfortably below every
## shirt colour above, so it cannot fire on a legitimate palette.
MAX_FACE_LUMINANCE = 0.30


def _check(entry, palette):
    slot8 = palette[8]
    if luminance(slot8) > MAX_FACE_LUMINANCE:
        raise SystemExit(
            "\nFACE CONSTRAINT VIOLATION - build aborted, nothing written.\n"
            "  '%s' has slot 8 = #%s (luminance %.2f > %.2f).\n"
            "  Slot 8 draws the eyes, eyebrows and mouth in the same cells as\n"
            "  the hair/top around them. A light slot 8 does not give you a\n"
            "  light-haired character, it gives you one with no face.\n"
            "  See person_palette.gdshader's own note.\n"
            % (entry["id"], slot8, luminance(slot8), MAX_FACE_LUMINANCE))


def garment_slots(model):
    """The slots THIS rig uses that a colourway is allowed to paint.

    Measured minus reserved — see MEASURED_SLOTS and RESERVED_SLOTS. Sorted so
    the mapping from colourway position to slot is stable: regenerating must not
    reshuffle which colour lands where.
    """
    used = MEASURED_SLOTS.get(model)
    if used is None:
        raise SystemExit(
            "\nUNMEASURED RIG - build aborted, nothing written.\n"
            "  '%s' is not in MEASURED_SLOTS. Writing a palette for a rig whose\n"
            "  UVs have not been binned means guessing which cells it samples,\n"
            "  which is exactly the bug that shipped stock colours on ten of the\n"
            "  twelve characters. Dump its slots first.\n" % model)
    return [s for s in sorted(used) if s not in RESERVED_SLOTS]


def build(entry):
    palette = list(BASE)
    shadow, mid, light = SKIN[entry["skin"]]
    palette[13] = shadow
    palette[14] = mid
    palette[15] = light
    palette[8] = DARK[entry["dark"]]

    slots = garment_slots(entry["model"])
    if not slots:
        raise SystemExit(
            "\nNO GARMENT SLOTS - build aborted, nothing written.\n"
            "  '%s' (%s) uses no recolourable slot, so its palette would be\n"
            "  identical to stock and the character would be a duplicate.\n"
            % (entry["id"], entry["model"]))
    colourway = entry["colourway"]
    for i, slot in enumerate(slots):
        palette[slot] = colourway[i % len(colourway)]
    _check(entry, palette)

    floats = []
    for slot in palette:
        floats.extend("%g" % v for v in rgb(slot))
    return f'''[gd_resource type="ShaderMaterial" load_steps=4 format=3]

[ext_resource type="Shader" path="{SHADER}" id="1"]
[ext_resource type="Texture2D" path="{COLORMAP}" id="2"]
[ext_resource type="Material" path="{OUTLINE}" id="3"]

[resource]
resource_name = "person_{entry["id"]}"
shader = ExtResource("1")
shader_parameter/source_map = ExtResource("2")
shader_parameter/albedo_color = Color(1, 1, 1, 0)
shader_parameter/palette = PackedColorArray({", ".join(floats)})
next_pass = ExtResource("3")
'''


def main():
    if not os.path.isdir(OUT_DIR):
        raise SystemExit("run me from the repo root - '%s' not found" % OUT_DIR)
    for entry in ROSTER:
        path = os.path.join(OUT_DIR, "person_%s.tres" % entry["id"])
        with open(path, "w", newline="\n") as handle:
            handle.write(build(entry))
        print("  wrote %-52s %-12s %-20s slots=%s" % (path, entry["name"], entry["model"], garment_slots(entry["model"])))
    print("%d roster palettes written" % len(ROSTER))


if __name__ == "__main__":
    sys.exit(main())
