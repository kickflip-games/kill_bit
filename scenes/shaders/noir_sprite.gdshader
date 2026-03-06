shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled;

// Matches hit_flash.gdshader interface exactly — enemy_base.gd needs NO changes
uniform sampler2D sprite_texture : source_color;
uniform float active : hint_range(0.0, 1.0) = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);

// Noir processing
uniform float contrast : hint_range(0.5, 4.0) = 2.2;
uniform float white_point : hint_range(0.3, 0.9) = 0.55;

void fragment() {
	vec4 tex = texture(sprite_texture, UV);
	if (tex.a < 0.05) discard;

	// Luminance desaturate
	float luma = dot(tex.rgb, vec3(0.299, 0.587, 0.114));

	// Contrast boost — pulls midtones toward white or black
	float c = clamp((luma - 0.5) * contrast + 0.5, 0.0, 1.0);

	// Strict red detection — only pure reds (blood, glowing eyes) pass; grays/browns excluded
	float red_dominant = step(0.25, tex.r - max(tex.g, tex.b));

	// Smoothstep on white threshold — prevents pixel crawl at edges when camera moves
	float is_white = smoothstep(white_point - 0.05, white_point + 0.05, c);
	float is_red   = red_dominant * (1.0 - is_white);
	// is_black: implicit (everything else)

	// No paper grain on sprites — keeps them crisp against the grainy world geometry
	vec3 color = vec3(0.0);
	color += is_white * vec3(1.0);          // Pure white — matches world hi_color exactly
	color += is_red   * vec3(0.75, 0.0, 0.0); // Blood red (strict sprites only)

	// Hit flash overlay (enemy_base.gd Tween: active 1→0 over 0.15s EASE_OUT)
	color = mix(color, flash_color.rgb, active);

	ALBEDO = color;
	ALPHA  = tex.a;
}
