/*
	Industry-style shading (approximately)
*/

// Varyings - Passed in from vertex shader
varying vec2 v_uv;

varying vec3 v_dirtolight_ts;
varying vec3 v_dirtocamera_ts;

// Uniforms - Passed in in draw call
uniform vec4 u_skincolor;
uniform vec4 u_skinparams;
uniform float u_transitionblend;
uniform sampler2D u_tex_col;
uniform sampler2D u_tex_nor;
uniform sampler2D u_tex_prm;

void main()
{
	// Textures ---------------------------------------------
	vec4 tex_col = texture2D(u_tex_col, v_uv);
	vec4 tex_nor = texture2D(u_tex_nor, v_uv);
	vec4 tex_prm = texture2D(u_tex_prm, v_uv);
	
	vec3 texturenormal = vec3(tex_nor.xy, 1.0); // Normal from texture
	texturenormal.y = 1.0 - texturenormal.y;	// Flip y normal (GMS2 Only)
	
	// Varyings --------------------------------------------------------
	vec3 n = normalize((texturenormal * 2.0) - 1.0);	// Normal
	vec3 l = normalize(v_dirtolight_ts);	// Light Direction
	vec3 e = normalize(v_dirtocamera_ts);	// Camera Direction
	vec3 r = reflect(-l, n);				// Reflect Angle
	
	// Material Vars ---------------------------------------------------
	float transition = max(1.0-tex_nor.b, 0.01);
	float cavity = tex_nor.a;
	
	float metallic = tex_prm.r;	// Also skin multiplier
	float roughness = tex_prm.g;
	float ao = tex_prm.b;
	float specular = tex_prm.a;
	
	float skinstrength = u_skinparams.x;
	float skinshape = u_skinparams.y;
	
	// Calculated Vars -------------------------------------------------
	float dp = clamp(dot(n, l), 0.0, 1.0);	// Dot Product
	float sssblend = metallic * skinstrength;
	float skinshading = clamp(dp * (1.0/skinshape) * 0.5 + 0.5, 0.0, 1.0);
	float lightvalue = 1.0 - mix(dp, skinshading, sssblend);
	
	float metallicamt = metallic * float(skinstrength < 0.01);
	
	float roughnesssq = max(0.0001, roughness*roughness);
	float roughnesssqinvsq = 1.0/(roughnesssq*roughnesssq);
	float roughnessshape = ( 1.0/(roughnesssq*roughnesssq) ) * ((1.0-specular) * 0.5 + 0.5);
	float e_dot_r = dot(e, r);
	float roughnesssqrtinvt = 1.0-sqrt(roughnesssq);
	float specularamt = pow(roughnesssqrtinvt, 3.0) *
		pow(clamp(e_dot_r*e_dot_r, 0.0, 1.0), roughnessshape) * ao;
	
	float rim = pow(1.0 - (dot(n, e) - roughnesssqrtinvt * 0.1), 8.0) * cavity;
	
	// Output ----------------------------------------------------------------
	vec3 diffusecolor = mix(tex_col.rgb, u_skincolor.rgb, 0.5*sssblend*float(skinstrength > 0.01));	// Skin Mix
	vec3 metalliccolor = mix(diffusecolor, diffusecolor*diffusecolor, metallicamt);	// Metallic Multiply
	vec3 shadowcolor = mix(metalliccolor, metalliccolor * ao * 0.5, lightvalue);
	vec3 specularcolor = mix(vec3(0.5), diffusecolor, metallic);
	
	vec3 inkcolor = vec3(1.0, 0.4, 0.2) * (sqrt(dp)*0.5+0.5) + pow(max(e_dot_r, 0.0), 128.0) + rim;
	
	vec3 outcolor;
	outcolor = shadowcolor + specularcolor * specularamt;
	outcolor = outcolor + vec3(0.5) * rim;
	outcolor = mix(outcolor, inkcolor, float(u_transitionblend >= transition));
	
    gl_FragColor = vec4(outcolor, 1.0);
}
