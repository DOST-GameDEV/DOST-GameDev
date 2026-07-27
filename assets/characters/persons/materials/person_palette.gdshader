// Palette-remap toon material for the two match Persons. Checklist 2.3 / M-5 step 1.
//
// WHY THIS EXISTS RATHER THAN A MATERIAL RETINT
//
// M-5 step 1 says "retint their imported materials". That is not possible as
// written, and the reason is worth recording so nobody tries it again:
//
//   Every Kenney mini is ONE material named `colormap` shared by BOTH of its
//   meshes (`body-mesh`, `head-mesh`), and every colour on the character comes
//   from where its UVs land in a 512x512 palette atlas. Hair, skin, shirt and
//   shorts are the same material. Setting `albedo_color` on it tints the whole
//   character uniformly — it cannot make the shirt green and the hair black.
//
// So the retint has to happen where the colour is actually chosen: at the UV.
// This shader replaces the atlas lookup with a 16-entry palette indexed by
// which CELL of the atlas the UV lands in. Recolouring a Person is then 16
// colours in a .tres — text, diffable, no binary, and the CC0 .glb stays
// pristine, which M-5 step 1 also asks for.
//
// THE ATLAS, MEASURED (not assumed) FROM colormap.png AND THE TWO .glb UV SETS
//
// 512x512, a 16x16 grid of 32x32 cells. Columns come in PAIRS: an even column
// is a flat swatch and the odd column beside it is that swatch's 4-step shading
// ramp, which is where the minis' baked soft shading comes from. Rows come in
// BLOCKS of four. Only rows 8-15 carry the colours these two models use.
//
//   slot = (col / 2) + (row >= 12 ? 8 : 0)
//
// | slot | cells            | Kenney source | male-f (Person A) | female-f (Person B) |
// |------|------------------|---------------|-------------------|---------------------|
// |  0   | col 0-1,  row 8-11  | #fde4c7 cream    | —              | —                  |
// |  1   | col 2-3,  row 8-11  | #61cb8b green    | SHIRT          | —                  |
// |  2   | col 4-5,  row 8-11  | #ffc044 amber    | —              | SUSPENDERS         |
// |  3   | col 6-7,  row 8-11  | #ff7e44 orange   | —              | —                  |
// |  4   | col 8-9,  row 8-11  | #cf534f red      | —              | —                  |
// |  5   | col 10-11,row 8-11  | #6794d9 blue     | —              | SHORTS             |
// |  6   | col 12-13,row 8-11  | #d0e8ff pale     | —              | —                  |
// |  7   | col 14-15,row 8-11  | #a878e8 purple   | —              | SHOES + eye makeup |
// |  8   | col 0-1,  row 12-15 | #38383d dk grey  | HAIR + FACE    | TOP + FACE         |
// |  9   | col 2-3,  row 12-15 | #868ba1 bluegrey | SHORTS + BELT  | —                  |
// | 10   | col 4-5,  row 12-15 | #4f5260 slate    | —              | —                  |
// | 11   | col 6-7,  row 12-15 | #a0a8c9 lt blue  | —              | collar trim        |
// | 12   | col 8-9,  row 12-15 | #ffffff white    | —              | SHOE SOLES         |
// | 13   | col 10-11,row 12-15 | #f1976c skin mid | SKIN shadow    | SKIN shadow        |
// | 14   | col 12-13,row 12-15 | #b06041 brown    | —              | HAIR               |
// | 15   | col 14-15,row 12-15 | #f2bf99 skin lt  | SKIN light     | SKIN light         |
//
// ⚠️ SLOT 8 CARRIES THE FACE. Eyes, eyebrows and mouth are drawn in the same
// dark-grey ramp as male-f's hair and female-f's top, in the SAME cells — they
// differ only by position inside a cell, which is below this shader's
// resolution. So slot 8 must stay DARK on both Persons or the face vanishes
// into the skin. That is the one hard constraint on the palettes.
//
// ⚠️ SLOTS ARE FLAT ON PURPOSE. Collapsing each ramp to one colour throws away
// Kenney's baked gradient. That is the moodboard direction, not an oversight —
// `Design_Agent_Brief.md` §1 asks for "flat colour blocks with no texture
// detail" and names PEAK as the reference. Form comes from `diffuse_toon`'s
// 2-band lighting and the inverted-hull outline in `next_pass`, the same way
// M-4 already lights the Props.
//
// HOW THE HIT FLASH STILL WORKS — READ BEFORE CHANGING `albedo_color`
//
// `character_visual.gd::flash_hit()` sets `albedo_color` to Color.WHITE and
// tweens it back to whatever the material started at; `flash_blocked()` does
// the same with UiTheme.DEFENSE. It knows nothing about palettes and must not
// have to. So `albedo_color` here is not the albedo — it is a BLEND TARGET, and
// its ALPHA is the blend amount:
//
//     ALBEDO = mix(palette[slot], albedo_color.rgb, albedo_color.a)
//
// At rest the material stores Color(1, 1, 1, 0) — alpha 0, so the palette shows
// through untouched. A flash writes Color.WHITE, whose alpha is 1, and the
// tween back to (1,1,1,0) fades the flash out. Zero changes to the flash system.
//
// ⚠️ The .tres MUST set `shader_parameter/albedo_color` explicitly.
// `ShaderMaterial.get_shader_parameter()` returns null for a parameter that was
// never assigned — it does NOT fall back to the default declared here — and
// `_collect_meshes()` SKIPS any ShaderMaterial whose `albedo_color` reads null.
// Leave it out of the .tres and the Person silently stops flashing on hits.

shader_type spatial;
render_mode cull_back, diffuse_toon;

// Fallback for atlas rows 0-7, which neither match Person uses. Kept so the
// shader degrades to stock Kenney colours rather than to black if it is ever
// pointed at a roster model that samples them.
uniform sampler2D source_map : source_color, filter_nearest, repeat_disable;
uniform vec4 palette[16] : source_color;
uniform vec4 albedo_color : source_color = vec4(1.0, 1.0, 1.0, 0.0);

void fragment() {
	vec2 cell = floor(clamp(UV, vec2(0.0), vec2(0.9999)) * 16.0);
	int col = int(cell.x);
	int row = int(cell.y);

	vec3 base;
	if (row >= 8) {
		base = palette[(col / 2) + (row >= 12 ? 8 : 0)].rgb;
	} else {
		base = texture(source_map, UV).rgb;
	}

	ALBEDO = mix(base, albedo_color.rgb, albedo_color.a);
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
	SPECULAR = 0.0;
}
