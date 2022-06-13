/*
	All types of attributes in one shader.
	NOTE: Normal mapping is a little strange after applying pse transform
*/

// Constants
const vec3 DEFAULT_NORMAL = vec3(0.5, 0.5, 1.0);

// Varyings - Passed in from vertex shader
varying vec2 v_uv;
varying vec4 v_color;

varying vec3 v_dirtolight_ts;
varying vec3 v_dirtocamera_ts;
varying vec3 v_normal_cs;

uniform sampler2D u_normalmap;	// Sampler index to normal map

void main()
{
	// Normal Map Texture ---------------------------------------------
	vec3 texturenormal = texture2D(u_normalmap, v_uv).xyz;
	texturenormal.z = 1.0;
	
	// Uniforms -------------------------------------------------------
	float alpha = 1.0;
	float emission = 0.0;
	float roughness = 0.5;
	float rim = 1.0;
	
	// Varyings -------------------------------------------------------
	vec3 n = normalize((texturenormal * 2.0) - 1.0);	// Vertex Normal
	vec3 l = normalize(v_dirtolight_ts);	// Light Direction
	vec3 e = normalize(v_dirtocamera_ts);	// Camera Direction
	vec3 r = reflect(-l, n);				// Reflect Angle
	
	// Vars -------------------------------------------------------------
	float dp = clamp(dot(n, l), 0.0, 1.0);	// Dot Product
	float fresnel = 1.0-clamp(dot(n, e), 0.0, 1.0);	// Fake Fresnel
	float shine = dot(e, r);	// Specular
	
	dp *= mix(0.9, 1.0, v_color.z);
	shine = pow( sqrt((shine+1.0)*0.5), pow(1.0/(roughness+0.001), 4.0) ) * 1.0 * (1.0-roughness);
	fresnel = pow(fresnel, 8.0)*rim;
	
	// Colors ----------------------------------------------------------------
	vec4 diffusecolor = v_color;
	
	// Output ----------------------------------------------------------------
	vec3 outcolor = diffusecolor.rgb * (dp+1.0) / 2.0;	// Shadow
	vec3 ambient = vec3(0.01, 0.0, 0.05);
	ambient = vec3(0.09, 0.04, 0.1);
	outcolor += ambient * (1.0-dp);	// Ambient
	outcolor += (diffusecolor.rgb + (pow(1.0-roughness, 64.0))) * shine*shine * (1.0-roughness);	// Specular
	outcolor += vec3(0.5) * fresnel;	// Rim
	
	outcolor = mix(outcolor, diffusecolor.rgb, emission+(1.0-v_color.a-(1.0-v_color.a)*emission)); // Emission
	
    gl_FragColor = vec4(outcolor, alpha);
}
