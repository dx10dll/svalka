shader_type spatial;
// Обводка предмета, на который навёлся игрок: вторая оболочка, раздутая по нормалям
// и вывернутая наизнанку. Толщина задана в метрах и чуть растёт с расстоянием.
render_mode unshaded, cull_front, shadows_disabled, fog_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.82, 0.45, 1.0);
uniform float width = 0.012;

void vertex() {
	float dist = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	VERTEX += NORMAL * width * clamp(dist * 0.6, 0.6, 2.0);
}

void fragment() {
	ALBEDO = color.rgb;
}
