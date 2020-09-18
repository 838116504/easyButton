shader_type canvas_item;

uniform vec2 scale = vec2(0.8);
uniform vec2 scalePivot = vec2(0.0);
uniform vec2 scale2 = vec2(1.0);
uniform vec2 scalePivot2 = vec2(0.0);
uniform bool isMix = false;
uniform vec4 mixColor : hint_color = vec4(1.0);
uniform float mixRatio = 0.2;

vec2 scale_with_pivot(vec2 p_pos, vec2 p_pivot, vec2 p_scale)
{
	return (p_pos - p_pivot) * p_scale + p_pivot;
}

void vertex()
{
	vec2 orgin = scale_with_pivot(vec2(0.0), scalePivot, scale);
	VERTEX = scale_with_pivot(scale_with_pivot(VERTEX, scalePivot, scale), scalePivot2 * scale - orgin, scale2);
}

void fragment()
{
	COLOR = texture(TEXTURE, UV);
	if (isMix)
	{
		COLOR.rgb = mix(COLOR.rgb, mixColor.rgb, mixRatio);
	}
}