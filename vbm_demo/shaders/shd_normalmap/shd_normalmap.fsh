/*
	Renders vbs with normal map.
*/

// Constants
const float DP_EXP = 0.7;	// Higher values smooth(?), Lower values sharpen
const float SPE_EXP = 16.0;	// Higher values sharpen, Lower values smooth
const float RIM_EXP = 8.0;	// Higher values sharpen, Lower values smooth
const float EULERNUMBER = 2.71828;	// Funny E number used in logarithmic stuff

// Passed from Vertex Shader
varying vec2 v_uv;
varying vec4 v_color;

varying vec3 v_dirtolight_ts;
varying vec3 v_dirtocamera_ts;

// Uniforms passed in before draw call
uniform vec4 u_drawmatrix[4]; // [alpha emission roughness rim colorblend[4] colorfill[4]]
uniform sampler2D u_texnormal;	// Sampler index to normal map

const vec3 DEFAULT_NORMAL = vec3(0.5, 0.5, 1.0);

void main()
{
	// Normal Map Texture ---------------------------------------------
	vec3 texturenormal = texture2D(u_texnormal, v_uv).xyz;
	// Use default normal if texture is completely white (no texture given)
	texturenormal = mix(texturenormal, DEFAULT_NORMAL, 
		float(texturenormal == vec3(1.0, 1.0, 1.0)));
	texturenormal.z = 1.0;
	
	// Uniforms -------------------------------------------------------
	float alpha = u_drawmatrix[0][0];
	float emission = u_drawmatrix[0][1];
	float roughness = u_drawmatrix[0][2];
	float rim = u_drawmatrix[0][3];
	vec4 colorblend = u_drawmatrix[1];
	vec4 colorfill = u_drawmatrix[2];
	
	// Varyings -------------------------------------------------------
	vec3 n = normalize((texturenormal * 2.0) - 1.0);	// Vertex Normal
	vec3 l = normalize(v_dirtolight_ts);	// Light Direction
	vec3 e = normalize(v_dirtocamera_ts);	// Camera Direction
	vec3 r = reflect(-l, n);				// Reflect Angle
	
	// Vars -------------------------------------------------------------
	float dp = clamp(dot(n, l), 0.0, 1.0);	// Dot Product
	float fresnel = 1.0-clamp(dot(n, e), 0.0, 1.0);	// Fake Fresnel
	float shine = dot(e, r);	// Specular
	
	dp = pow(dp, DP_EXP);
	shine = pow( sqrt((shine+1.0)*0.5), pow(1.0/(roughness+0.001), 4.0) ) * 1.0 * (1.0-roughness);
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
	outcolor += (diffusecolor.rgb + (pow(1.0-roughness, 8.0))) * shine*shine;	// Specular
	outcolor += vec3(0.5) * fresnel;	// Rim
	
	outcolor = mix(outcolor, diffusecolor.rgb, emission+(1.0-v_color.a-(1.0-v_color.a)*emission)); // Emission
	outcolor = mix(outcolor, colorblend.rgb*outcolor.rgb, colorblend.a); // Blend Color
	outcolor = mix(outcolor, colorfill.rgb, colorfill.a); // Fill Color
	
    gl_FragColor = vec4(outcolor, alpha);
}
