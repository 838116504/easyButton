shader_type canvas_item;

uniform vec2 scale = vec2(0.8);
uniform vec2 scalePivot = vec2(0.0);
uniform bool isMix = false;
uniform vec4 mixColor : hint_color = vec4(1.0);
uniform float mixRatio = 0.2;

void vertex()
{
	VERTEX = (VERTEX - scalePivot) * scale + scalePivot;
}

void fragment()
{
	COLOR = texture(TEXTURE, UV);
	if (isMix)
	{
		COLOR.rgb = mix(COLOR.rgb, mixColor.rgb, mixRatio);
	}
}