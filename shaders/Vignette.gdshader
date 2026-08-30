shader_type canvas_item;
// Screen-space vignette overlay - darkens toward the edges of the
// viewport. Resolution-independent (uses SCREEN_UV), so it holds up
// under the project's canvas_items/"expand" stretch mode.

uniform float intensity : hint_range(0.0, 2.0) = 0.55;
uniform float radius : hint_range(0.1, 1.5) = 0.85;
uniform float softness : hint_range(0.01, 1.5) = 0.6;

void fragment() {
	vec2 uv = SCREEN_UV - vec2(0.5);
	float dist = length(uv) * 2.0;
	float vignette = smoothstep(radius, radius - softness, dist);
	COLOR = vec4(0.0, 0.0, 0.0, (1.0 - vignette) * intensity);
}
