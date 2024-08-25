//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

uniform float u_offset;

void main()
{
	vec2 uv = -v_vTexcoord + vec2(1000.0, 1000.0);
	vec2 uv1 = uv;
	vec2 uv2 = uv * 2.0;
	
	uv1.x += (sin((uv.y + u_offset * 2.0) * 20.0)) * 0.008 + u_offset * 0.04;
	uv1.y += u_offset * 0.5;
	
	uv2.y += sin((uv.y + u_offset * 2.0) * 10.0) * 0.02 + u_offset * 0.02;
	
	vec2 c1 = mod(uv1 * vec2(16.0), vec2(1.0));
	vec2 i1 = floor(uv1 * vec2(16.0));
	float v1 = distance(c1, vec2(0.5, 0.5)) * 1.0;
	float r1 = fract(sin( dot(i1, vec2(12.9898, 78.233)) ) * 43758.5);
	
	vec2 c2 = mod(uv2 * vec2(16.0), vec2(1.0));
	vec2 i2 = floor(uv2 * vec2(16.0));
	float v2 = distance(c2, vec2(0.5, 0.5)) * 1.0;
	float r2 = fract(sin( dot(i2, vec2(12.9898, 78.233)) ) * 43758.5);
	
	vec3 color = vec3(0.04, 0.02, 0.13);
	
	gl_FragColor.rgb = color * 0.3;
	gl_FragColor.rgb = mix(gl_FragColor.rgb, color, 0.5 * float(v2 < 0.5 && r2 > 0.2));
	gl_FragColor.rgb = mix(gl_FragColor.rgb, color, 0.9 * float(v1 < 0.5 && r1 > 0.2));
	
	gl_FragColor.a = 1.0;
}
