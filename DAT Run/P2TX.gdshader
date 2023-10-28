shader_type canvas_item;

uniform vec4 UppL_COL : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 UppR_COL : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 BotL_COL : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 BotR_COL : source_color = vec4(1.0, 1.0, 1.0, 1.0);

void fragment() {
	vec3 left_mask = vec3(UV.x,UV.x,UV.x);
	vec3 up_mask = vec3(UV.y,UV.y,UV.y);
	
	vec4 mixtop = mix(UppL_COL, UppR_COL, left_mask.g);
	vec4 mixbot = mix(BotL_COL, BotR_COL, left_mask.g);
	
	vec4 finalcolor = mix(mixtop, mixbot, up_mask.g);
	COLOR *= finalcolor;
}
