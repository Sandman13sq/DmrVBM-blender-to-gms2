/*
	Supports skeletal animation
	
	NOTE: If you don't see any vertices rendering at all, 
	check that u_matpose is populated with some valid matrices.
*/

// Varyings - Passed in from vertex shader
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

varying vec3 v_dirtolight_cs;
varying vec3 v_dirtocamera_cs;
varying vec3 v_normal_cs;

vec3 ColorBurn(vec3 B, vec3 A, float fac)	// Used in image editors like Photoshop
{
	// return max(vec3(0.0), 1.0-((1.0-B)/A)) * fac + B * (1.0-fac); // Used in image editors like Photoshop
	return max(vec3(0.0), 1.0-((1.0-B)) / ( (1.0-fac) + (fac*A) ) ); // Used in Blender
}

void main()
{
	// Varyings -------------------------------------------------------
	vec3 n = normalize(v_normal_cs);		// Vertex Normal
	vec3 l = normalize(v_dirtolight_cs);	// Light Direction
	vec3 e = normalize(v_dirtocamera_cs);	// Camera Direction
	vec3 r = reflect(-l, n);				// Reflect Angle
	
	// Light value
	float dp = clamp( dot(n, l), 0.0, 1.0 );
	dp = sqrt(dp);
	
	// Shine Value
	float roughness = 0.5;
	float shine = clamp(dot(e, r), 0.0, 1.0);
	shine = pow(shine, 1.0/roughness);
	
	gl_FragColor.rgb = v_vColour.rgb;
	gl_FragColor.rgb *= mix(vec3(0.8, 0.8, 1.0), vec3(1.0), float(dp >= 0.7));
	gl_FragColor.rgb *= mix(vec3(0.8, 0.7, 0.9), vec3(1.0), float(dp >= 0.25));
	gl_FragColor.rgb += vec3(0.02) * float(shine >= 0.5);
	
	gl_FragColor.a = 1.0;
}
