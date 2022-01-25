//
// Simple passthrough fragment shader
//

const vec3 VEC3YFLIP = vec3(1.0, -1.0, 1.0);

varying vec3 v_vNormal;
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

varying vec3 v_dirtolight_cs;
varying vec3 v_dirtocamera_cs;
varying vec3 v_normal_cs;

vec3 ColorBurn(vec3 B, vec3 A, float amt)
{
	return max( (1.0-( (1.0-B)/A) ), 0.0) * amt + B * (1.0-amt);
}

const vec3 BURNCOLOR = vec3(0.85, 0.73, 1.0);

void main()
{
	// Varyings -------------------------------------------------------
	vec3 n = normalize(v_normal_cs);		// Vertex Normal
	vec3 l = normalize(v_dirtolight_cs);	// Light Direction
	vec3 e = normalize(v_dirtocamera_cs);	// Camera Direction
	vec3 r = reflect(-l, n);				// Reflect Angle
	
	// Shadow value
	float dp = dot(n, l);
	dp = (dp+1.0)*0.5; // Map to 0-1 range
	dp = pow(dp, 1.0); // Soften shadows
	dp = float(dp > 0.5);
	
	// Specular/Shine Value
	float spe = clamp(dot(e, r), 0.0, 1.0);
	spe = float(spe >= 0.9)*0.04;
	
	// Rimlight Value
	float rim = clamp(dot(n, e), 0.0, 1.0);
	rim = float(rim < 0.3);
	
	// Output
	vec4 basecolor = (v_vColour * texture2D( gm_BaseTexture, v_vTexcoord ));
	vec3 darkcolor = ColorBurn(basecolor.rgb*BURNCOLOR, basecolor.rgb, 0.2);
	darkcolor = mix(darkcolor, darkcolor*basecolor.rgb, dp*0.1);
	
	gl_FragColor.rgb = mix(darkcolor, basecolor.rgb, dp);
	gl_FragColor.rgb *= vec3(1.0+spe);
	gl_FragColor.rgb += vec3(rim)*0.3;
	gl_FragColor.rgb = mix(gl_FragColor.rgb, basecolor.rgb, 1.0-basecolor.a);
	
	gl_FragColor.a = 1.0;
}
