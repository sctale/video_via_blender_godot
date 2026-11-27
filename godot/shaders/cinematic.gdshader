shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// 轻量电影化后期：只作用于 3D 画面，不污染 HUD。
uniform float vignette_strength : hint_range(0.0, 0.8) = 0.30;
uniform float grain_strength : hint_range(0.0, 0.10) = 0.018;
uniform float saturation : hint_range(0.5, 1.5) = 1.06;
uniform float contrast : hint_range(0.5, 1.5) = 1.05;
uniform float warmth : hint_range(-0.1, 0.1) = 0.018;
uniform float fade : hint_range(0.0, 1.0) = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 src = texture(SCREEN_TEXTURE, uv).rgb;

	// 轻暖调 + 对比/饱和
	src += vec3(warmth, warmth * 0.35, -warmth * 0.55);
	float luma = dot(src, vec3(0.2126, 0.7152, 0.0722));
	src = mix(vec3(luma), src, saturation);
	src = (src - 0.5) * contrast + 0.5;

	// 暗角
	vec2 q = uv - 0.5;
	float vig = smoothstep(0.18, 0.72, length(q));
	src *= 1.0 - vig * vignette_strength;

	// 细颗粒，避免大面积渐变出现色带
	float g = hash21(uv * vec2(1920.0, 1080.0) + fract(TIME) * 137.0) - 0.5;
	src += g * grain_strength;

	COLOR = vec4(clamp(src, 0.0, 1.0), fade);
}
