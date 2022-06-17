/*
	Shading with Normal map support
*/

// Varyings - Passed in from vertex shader
varying vec2 v_uv;
varying vec4 v_color;

varying vec3 v_dirtolight_ts;
varying vec3 v_dirtocamera_ts;

void main()
{
	// Normal Map Texture ---------------------------------------------
	vec3 texturenormal = texture2D( gm_BaseTexture, v_uv ).xyz; // Normal from texture
	texturenormal.y = 1.0 - texturenormal.y;	// Flip y normal (GMS2 Only)
	texturenormal.z = 1.0;	// z-coordinate needs to be 1.0
	
	// Varyings -------------------------------------------------------
	vec3 n = normalize((texturenormal * 2.0) - 1.0);	// Normal
	vec3 l = normalize(v_dirtolight_ts);	// Light Direction
	vec3 e = normalize(v_dirtocamera_ts);	// Camera Direction
	vec3 r = reflect(-l, n);				// Reflect Angle
	
	// Vars -------------------------------------------------------------
	float dp = clamp(dot(n, l), 0.0, 1.0);	// Dot Product
	
	// Output ----------------------------------------------------------------
	vec3 outcolor;
	outcolor = v_color.rgb * (dp+1.0) / 2.0;	// Shadow
	outcolor += pow(max(0.0, dot(e, r)), 32.0) * 0.5;	// Specular
	
    gl_FragColor = vec4(outcolor, 1.0);
}
