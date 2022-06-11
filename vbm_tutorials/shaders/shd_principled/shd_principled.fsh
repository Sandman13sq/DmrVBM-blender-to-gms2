/*
	Layered-shading
*/

// Constants
const float DP_EXP = 1.0;	// Higher values smooth(?), Lower values sharpen
const float SPE_EXP = 64.0;	// Higher values sharpen, Lower values smooth
const float RIM_EXP = 8.0;	// Higher values sharpen, Lower values smooth
const float EULERNUMBER = 2.71828;	// Funny E number used in logarithmic stuff

// Varyings - Passed in from vertex shader
varying vec2 v_uv;
varying vec4 v_color;
varying vec4 v_bone;
varying vec4 v_weight;

varying vec3 v_dirtolight_cs;
varying vec3 v_dirtocamera_cs;
varying vec3 v_normal_cs;

vec3 ColorBurn(vec3 B, vec3 A, float fac)	// Used in image editors like Photoshop
{
	return max(vec3(0.0), 1.0-((1.0-B)/A)) * fac + B * (1.0-fac); // Used in image editors like Photoshop
	//return max(vec3(0.0), 1.0-((1.0-B)) / ( (1.0-fac) + (fac*A) ) ); // Used in Blender
}

void main()
{
	// Uniforms -------------------------------------------------------
	float alpha = 1.0;
	float emission = 0.0;
	float roughness = 0.3;
	float rim = 1.0;
	
	// Varyings -------------------------------------------------------
	// There's some error when normalizing in vertex shader. Looks smoother here
	vec3 n = normalize(v_normal_cs);		// Vertex Normal
	vec3 l = normalize(v_dirtolight_cs);	// Light Direction
	vec3 e = normalize(v_dirtocamera_cs);	// Camera Direction
	vec3 r = reflect(-l, n);				// Reflect Angle
	
	// Vars -------------------------------------------------------------
	float dp = clamp(dot(n, l), 0.0, 1.0);	// Dot Product
	float fresnel = 1.0-clamp(dot(n, e), 0.0, 1.0);	// Fake Fresnel
	float shine = dot(e, r);	// Specular
	
	dp = pow(dp, DP_EXP);
	//dp *= mix(0.9, 1.0, v_color.z);
	shine = pow( sqrt((shine+1.0)*0.5), pow(1.0/(roughness+0.001), 4.0) ) * 1.0 * (1.0-roughness);
	fresnel = pow(fresnel, RIM_EXP)*rim;
	
	// Colors ----------------------------------------------------------------
	// Use only v_color if bottom left pixel is completely white (no texture given)
	vec4 diffusecolor = v_color;
	
	// Output ----------------------------------------------------------------
	vec3 outcolor = diffusecolor.rgb * (dp+1.0) / 2.0;	// Shadow
	vec3 ambient = vec3(0.01, 0.0, 0.05);
	//dp = (dp+1.0) / 2.0;
	dp = clamp(dp, 0.0, 1.0);
	float lightvalue = pow(1.0-dp, 2.0) * 0.5;
	outcolor = ColorBurn(diffusecolor.rgb, vec3(0.354214, 0.259524, 0.534183), lightvalue*0.5);
	outcolor = mix(outcolor, outcolor*vec3(0.5), lightvalue); 
	
	ambient = vec3(0.09, 0.04, 0.1);
	//outcolor += ambient * (1.0-dp);	// Ambient
	outcolor += (diffusecolor.rgb + (pow(1.0-roughness, SPE_EXP))) * shine*shine * (1.0-roughness);	// Specular
	outcolor += (diffusecolor.rgb + vec3(0.1)) * fresnel;	// Rim
	
	outcolor = mix(outcolor, diffusecolor.rgb, emission+(1.0-v_color.a-(1.0-v_color.a)*emission)); // Emission
	
    gl_FragColor = vec4(outcolor, alpha);
}

void main2()
{
	// Uniforms -------------------------------------------------------
	float alpha = 1.0;
	float emission = 0.0;
	float roughness = 0.3;
	float rim = 1.0;
	
	// Varyings -------------------------------------------------------
	// There's some error when normalizing in vertex shader. Looks smoother here
	vec3 n = normalize(v_normal_cs);		// Vertex Normal
	vec3 l = normalize(v_dirtolight_cs);	// Light Direction
	vec3 e = normalize(v_dirtocamera_cs);	// Camera Direction
	vec3 r = reflect(-l, n);				// Reflect Angle
	
	// Vars -------------------------------------------------------------
	float dp = clamp(dot(n, l), 0.0, 1.0);	// Dot Product
	float fresnel = 1.0-clamp(dot(n, e), 0.0, 1.0);	// Fake Fresnel
	float shine = dot(e, r);	// Specular
	
	dp = pow(dp, DP_EXP);
	dp *= mix(0.9, 1.0, v_color.z);
	shine = pow( sqrt((shine+1.0)*0.5), pow(1.0/(roughness+0.001), 4.0) ) * 1.0 * (1.0-roughness);
	fresnel = pow(fresnel, RIM_EXP)*rim;
	
	// Colors ----------------------------------------------------------------
	// Use only v_color if bottom left pixel is completely white (no texture given)
	vec4 diffusecolor = v_color;
	
	// Output ----------------------------------------------------------------
	vec3 outcolor = diffusecolor.rgb * (dp+1.0) / 2.0;	// Shadow
	vec3 ambient = vec3(0.01, 0.0, 0.05);
	ambient = vec3(0.09, 0.04, 0.1);
	outcolor += ambient * (1.0-dp);	// Ambient
	outcolor += (diffusecolor.rgb + (pow(1.0-roughness, SPE_EXP))) * shine*shine * (1.0-roughness);	// Specular
	outcolor += vec3(0.5) * fresnel;	// Rim
	
	outcolor = mix(outcolor, diffusecolor.rgb, emission+(1.0-v_color.a-(1.0-v_color.a)*emission)); // Emission
	
    gl_FragColor = vec4(outcolor, alpha);
}


