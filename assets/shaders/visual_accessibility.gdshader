shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform int profile_mode = 0;

vec3 simulated_protanopia(vec3 color) {
	return vec3(
		dot(color, vec3(0.152286, 1.052583, -0.204868)),
		dot(color, vec3(0.114503, 0.786281, 0.099216)),
		dot(color, vec3(-0.003882, -0.048116, 1.051998))
	);
}

vec3 simulated_deuteranopia(vec3 color) {
	return vec3(
		dot(color, vec3(0.367322, 0.860646, -0.227968)),
		dot(color, vec3(0.280085, 0.672501, 0.047413)),
		dot(color, vec3(-0.011820, 0.042940, 0.968881))
	);
}

vec3 simulated_tritanopia(vec3 color) {
	return vec3(
		dot(color, vec3(1.255528, -0.076749, -0.178779)),
		dot(color, vec3(-0.078411, 0.930809, 0.147602)),
		dot(color, vec3(0.004733, 0.691367, 0.303900))
	);
}

void fragment() {
	vec4 source = textureLod(screen_texture, SCREEN_UV, 0.0);
	vec3 color = source.rgb;
	float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
	if (profile_mode == 1) {
		color = clamp((color - vec3(0.5)) * 1.18 + vec3(0.5), vec3(0.0), vec3(1.0));
		color = clamp(mix(vec3(dot(color, vec3(0.2126, 0.7152, 0.0722))), color, 1.08), vec3(0.0), vec3(1.0));
	} else if (profile_mode == 2) {
		color = vec3(luma);
	} else if (profile_mode == 3) {
		color = simulated_protanopia(color);
	} else if (profile_mode == 4) {
		color = simulated_deuteranopia(color);
	} else if (profile_mode == 5) {
		color = simulated_tritanopia(color);
	}
	COLOR = vec4(clamp(color, vec3(0.0), vec3(1.0)), source.a);
}
