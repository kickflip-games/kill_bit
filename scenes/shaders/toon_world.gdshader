shader_type spatial;
render_mode diffuse_lambert, specular_disabled;

// How many light bands — 2 is clean, 3 is classic cel
uniform int cuts : hint_range(1, 5) = 2;
// Soften band edges (0 = hard steps, 0.15 = slightly blended)
uniform float softness : hint_range(0.0, 0.3) = 0.05;

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D albedo_texture : source_color, hint_default_white;

void fragment() {
	ALBEDO = albedo.rgb * texture(albedo_texture, UV).rgb;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float NdotL = clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION;

	// Quantize into bands with a soft edge to avoid harsh slicing on brick geometry
	float cuts_f = float(cuts);
	float stepped = floor(NdotL * cuts_f + softness) / cuts_f;
	stepped = clamp(stepped, 0.0, 1.0);

	DIFFUSE_LIGHT += stepped * LIGHT_COLOR;
}
