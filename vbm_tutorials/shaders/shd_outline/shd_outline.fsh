/*
	Shading with Normal map support
*/

// Varyings - Passed in from vertex shader
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

varying vec3 v_dirtolight_cs;
varying vec3 v_dirtocamera_cs;
varying vec3 v_normal_cs;

varying float v_outline;

void main()
{
	// Varyings -------------------------------------------------------
	vec3 n = normalize(v_normal_cs);		// Vertex Normal
	vec3 l = normalize(v_dirtolight_cs);	// Light Direction
	vec3 e = normalize(v_dirtocamera_cs);	// Camera Direction
	vec3 r = reflect(-l, n);				// Reflect Angle
	
	vec3 outcolor = v_vColour.rgb;
	outcolor = mix(outcolor, outcolor*1.1, float(dot(e, r) >= 0.9));	// Specular
	outcolor = mix(outcolor, v_vColour.rgb * vec3(0.8, 0.7, 0.9), float(dot(n, l) <= 0.1));	// Shadow
	
	outcolor = mix(outcolor, vec3(0.1), float(v_outline!=0.0));	// Outline Color
	
    gl_FragColor = vec4(outcolor, 1.0);
}
