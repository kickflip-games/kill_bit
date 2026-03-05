shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

uniform sampler2D sprite_texture : source_color;
uniform float active : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec4 col = texture(sprite_texture, UV);
	ALBEDO = mix(col.rgb, flash_color.rgb, active);
	ALPHA = col.a;
}
