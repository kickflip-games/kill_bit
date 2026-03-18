shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

uniform sampler2D sprite_texture : source_color;

void fragment() {
	vec4 tex = texture(sprite_texture, UV);
	ALBEDO = vec3(1.0, 0.0, 0.0);
	ALPHA = step(0.1, tex.a);
}
