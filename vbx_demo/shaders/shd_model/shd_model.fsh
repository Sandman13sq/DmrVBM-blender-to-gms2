/*
	Renders vbs with basic shading.
*/

// Constants
const float DP_EXP = 1.0;	// Higher values smooth(?), Lower values sharpen
const float SPE_EXP = 16.0;	// Higher values sharpen, Lower values smooth
const float RIM_EXP = 8.0;	// Higher values sharpen, Lower values smooth
const float EULERNUMBER = 2.71828;	// Funny E number used in logarithmic stuff

// Passed from Vertex Shader
varying vec2 v_uv;
varying vec4 v_color;

varying vec3 v_dirtolight_cs;
varying vec3 v_dirtocamera_cs;
varying vec3 v_normal_cs;

// Uniforms passed in before draw call
uniform vec4 u_drawmatrix[4]; // [alpha emission roughness rim colorblend[4] colorfill[4]]

void main()
{
	// Uniforms -------------------------------------------------------
	float alpha = u_drawmatrix[0][0];
	float emission = u_drawmatrix[0][1];
	float roughness = 1.0-u_drawmatrix[0][2];
	float rim = u_drawmatrix[0][3];
	vec4 colorblend = u_drawmatrix[1];
	vec4 colorfill = u_drawmatrix[2];
	
	// Varyings -------------------------------------------------------
	vec3 n = normalize(v_normal_cs);		// Vertex Normal
	vec3 l = normalize(v_dirtolight_cs);	// Light Direction
	vec3 e = normalize(v_dirtocamera_cs);	// Camera Direction
	vec3 r = reflect(-l, n);				// Reflect Angle
	
	// Vars -------------------------------------------------------------
	float dp = clamp(dot(n, l), 0.0, 1.0);	// Dot Product
	float fresnel = 1.0-clamp(dot(n, e), 0.0, 1.0);	// Fake Fresnel
	float shine = clamp( dot(e, r), 0.0, 1.0);	// Specular
	
	dp = pow(dp, DP_EXP);
	shine = pow(shine, max(EULERNUMBER, shine) * SPE_EXP * roughness + 0.00001 );
	fresnel = pow(fresnel, RIM_EXP)*rim;
		
	// Colors ----------------------------------------------------------------
	// Use only v_color if bottom left pixel is completely white (no texture given)
	vec4 diffusecolor = mix(
		texture2D(gm_BaseTexture, v_uv),	// Texture Color
		v_color,							// Vertex Color
		float(texture2D(gm_BaseTexture, vec2(0.0)) == vec4(1.0)) // Check pixel
		);
	
	// Output ----------------------------------------------------------------
	vec3 outcolor = diffusecolor.rgb * (dp+1.0) / 2.0;	// Shadow
	outcolor += vec3(0.01, 0.0, 0.05) * (1.0-dp);	// Ambient
	outcolor += diffusecolor.rgb * shine * roughness;	// Specular
	outcolor += vec3(0.5) * fresnel;	// Rim
	
	outcolor = mix(outcolor, diffusecolor.rgb, emission+(1.0-v_color.a)); // Emission
	outcolor = mix(outcolor, colorblend.rgb*outcolor.rgb, colorblend.a); // Blend Color
	outcolor = mix(outcolor, colorfill.rgb, colorfill.a); // Fill Color
	
    gl_FragColor = vec4(outcolor, alpha);
}
