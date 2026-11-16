shader_type canvas_item;
// Вид из-под завала: темнота и несколько щелей, через которые виден мир.
// open растёт, когда с игрока снимают куски: щели шире. shake — рывок.

uniform float open : hint_range(0.0, 1.0) = 0.0;
uniform float shake = 0.0;

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.78;
	float light = 0.0;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float ang = 0.5 + fi * 1.9;
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 n = vec2(-dir.y, dir.x);
		vec2 p = uv - vec2(0.42 * sin(fi * 2.3 + 1.0), 0.24 * cos(fi * 1.7));
		p += shake * 0.012 * vec2(sin(TIME * 43.0 + fi), cos(TIME * 37.0 + fi * 2.0));
		float along = dot(p, dir);
		float across = dot(p, n) + 0.02 * sin(along * 21.0 + fi);
		float w = (0.006 + 0.05 * open) * (1.0 - smoothstep(0.0, 0.2 + 0.2 * open, abs(along)));
		light = max(light, 1.0 - smoothstep(w * 0.4, w, abs(across)));
	}
	COLOR = vec4(0.012, 0.01, 0.008, 1.0 - light * 0.9);
}
