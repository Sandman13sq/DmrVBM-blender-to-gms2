/*
	Renders vbs with skeletal animation 
	and basic shading with assistance from normal maps.
*/

// Passed from Vertex Shader
//varying vec3 v_pos;
//varying vec3 v_normal;
varying vec2 v_uv;
varying vec4 v_color;

varying vec3 v_dirtolight_cs;
varying vec3 v_dirtocamera_cs;
varying vec3 v_dirtolight_ts;
varying vec3 v_dirtocamera_ts;

// Uniforms passed in before draw call
uniform vec4 u_drawmatrix[4]; // [alpha emission shine sss colorblend[4] colorfill[4]]

void main()
{
	// Normal Map Texture ----------------------------------------
	
	vec3 texturenormal = texture2D(gm_BaseTexture, v_uv).xyz;
	texturenormal = mix(texturenormal, vec3(0.5, 0.5, 1.0), 
		float(texturenormal == vec3(1.0, 1.0, 1.0)));
	
	// Uniforms -------------------------------------------------------
	
	float alpha = u_drawmatrix[0][0];
	float emission = u_drawmatrix[0][1];
	float specular = u_drawmatrix[0][2];
	float sss = u_drawmatrix[0][3];
	vec4 colorblend = u_drawmatrix[1];
	vec4 colorfill = u_drawmatrix[2];
	
	// Varyings -------------------------------------------------------
	
	vec3 n = normalize((texturenormal * 2.0) - 1.0);
	vec3 l = normalize(v_dirtolight_ts);
	vec3 e = normalize(v_dirtocamera_ts);
	vec3 r = reflect(-l, n);				// Reflect Angle
	
	// Vars -------------------------------------------------------------
	
	float dp = clamp(dot(n, l), 0.0, 1.0);	// Dot Product
	float rim = 1.0-clamp(dot(n, e), 0.0, 1.0);	// Fake Fresnel
	float spe = clamp( dot(e, r), 0.0, 1.0);	// Specular
	
	spe = pow(spe, 32.0 * specular + 0.00001);
	rim = pow(rim, 3.0);
	
	// Colors ----------------------------------------------------------------
	
	// Use v_color if bottom left pixel is completely white (no texture given)
	vec4 diffusecolor = mix(texture2D(gm_BaseTexture, v_uv), v_color, 
		float(texture2D(gm_BaseTexture, vec2(0.0)) == vec4(1.0))
		);
	vec3 shadowtint = mix(vec3(0.1, 0.0, 0.5), vec3(.5, .0, .2), sss);
	vec3 shadowcolor = mix(diffusecolor.rgb * shadowtint, diffusecolor.rgb*0.5, 0.7);
	vec3 specularcolor = diffusecolor.rgb * vec3(1.0-(length(diffusecolor.rgb)*0.65));
	
	// Output ----------------------------------------------------------------
	
	vec3 outcolor = mix(shadowcolor, diffusecolor.rgb, dp);
	outcolor += (specularcolor * spe + vec3(0.5) * rim) * specular;
	
	// Emission
	outcolor = mix(outcolor, diffusecolor.rgb, emission);
	// Blend Color
	outcolor = mix(outcolor, colorblend.rgb*outcolor.rgb, colorblend.a);
	// Fill Color
	outcolor = mix(outcolor, colorfill.rgb, colorfill.a);
	
	// Alpha
    gl_FragColor = vec4(outcolor, alpha*diffusecolor.a);
	
	if (gl_FragColor.a <= 0.0) {discard;}
}
