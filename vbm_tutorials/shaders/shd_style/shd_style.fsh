/*
	Uses bright shading with rimlighting
*/

// Varyings - Passed in from vertex shader
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

varying vec3 v_dirtolight_cs;
varying vec3 v_dirtocamera_cs;
varying vec3 v_normal_cs;

vec3 ColorBurn(vec3 B, vec3 A, float fac)	// Used in image editors like Photoshop
{
	//return max(vec3(0.0), 1.0-((1.0-B)/A)) * fac + B * (1.0-fac); // Used in image editors like Photoshop
	return max(vec3(0.0), 1.0-((1.0-B)) / ( (1.0-fac) + (fac*A) ) ); // Used in Blender
}

void main()
{
	// Varyings -------------------------------------------------------
	vec3 n = normalize(v_normal_cs);		// Vertex Normal
	vec3 l = normalize(v_dirtolight_cs);	// Light Direction
	vec3 e = normalize(v_dirtocamera_cs);	// Camera Direction
	vec3 r = reflect(-l, n);				// Reflect Angle
	
	// Shadow value
	float dp = dot(n, l);
	dp = max(0.0, dp);
	
	// Specular/Shine Value
	float spe = clamp(dot(e, r), 0.0, 1.0);
	spe = pow(spe, 8.0)*0.1;
	
	// Rimlight Value
	float rim = clamp(dot(n, e), 0.0, 1.0);
	rim = pow(1.0-rim, 4.0)*0.5;
	
	// Output
	vec4 basecolor = (v_vColour * texture2D( gm_BaseTexture, v_vTexcoord ));
	
	gl_FragColor.rgb = ColorBurn(basecolor.rgb, vec3(0.5, 0.2, 1.0), (1.0-dp)*0.4) * (dp*0.2+0.8);
	
	gl_FragColor.rgb *= vec3(1.0+spe);
	gl_FragColor.rgb += vec3(rim);
	gl_FragColor.rgb = mix(gl_FragColor.rgb, basecolor.rgb, 1.0-basecolor.a);
	
	gl_FragColor.a = 1.0;
}
