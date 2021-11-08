/*
	Renders vbs with skeletal animation and basic shading.
*/

// Passed from Vertex Shader
//varying vec3 v_pos;
//varying vec3 v_normal;
varying vec2 v_uv;
varying vec4 v_color;

varying vec3 v_dirtolight_cs;
varying vec3 v_dirtocamera_cs;
varying vec3 v_normal_cs;

// Uniforms passed in before draw call
uniform vec4 u_drawmatrix[4]; // [alpha emission shine sss colorfill[4], colorblend[4]]

void main()
{
	// Varyings -------------------------------------------------------
	
	vec3 n = normalize(v_normal_cs);		// Vertex Normal
	vec3 l = normalize(v_dirtolight_cs);	// Light Direction
	vec3 e = normalize(v_dirtocamera_cs);	// Camera Direction
	vec3 r = reflect(-l, n);				// Reflect Angle
	//e.y *= -1.0;
	
	// Vars -------------------------------------------------------------
	
	float dp = clamp(dot(n, l), 0.0, 1.0);	// Dot Product
	float rim = 1.0-clamp(dot(n, e), 0.0, 1.0);	// Fake Fresnel
	float shine = clamp( dot(e, r), 0.0, 1.0);	// Specular
	
	/*
	dp = pow(dp, 0.5);
	rim = clamp(pow(1.0-rim, 8.0), 0.0, 1.0);
	rim = float(rim > 0.05);
	shine = pow( shine + 0.02, 512.0 );
	*/
	shine = pow(shine, 32.0 * u_drawmatrix[0][2] + 0.00001);
	rim = pow(rim, 3.0);
	
	// Colors ----------------------------------------------------------------
	
	/*
	vec4 diffusecolor = v_color * texture2D( gm_BaseTexture, v_uv);
	vec3 shadowtint = mix(vec3(0.1, 0.0, 0.5), vec3(.5, .0, .2), u_drawmatrix[0].w);
	vec3 shadowcolor = mix(diffusecolor.rgb * shadowtint, diffusecolor.rgb, 0.7);
	vec3 shinecolor = diffusecolor.rgb * vec3(1.0-(length(diffusecolor.rgb)*0.65));
	*/
	
	vec4 diffusecolor = v_color;// * texture2D( gm_BaseTexture, v_uv);
	vec3 shadowtint = mix(vec3(0.1, 0.0, 0.5), vec3(.5, .0, .2), u_drawmatrix[0].w);
	vec3 shadowcolor = mix(diffusecolor.rgb * shadowtint, diffusecolor.rgb*0.5, 0.7);
	vec3 shinecolor = diffusecolor.rgb * vec3(1.0-(length(diffusecolor.rgb)*0.65));
	
	// Output ----------------------------------------------------------------
	
	vec3 outcolor = mix(shadowcolor, diffusecolor.rgb, dp);
	//outcolor += shinecolor * clamp(shine+rim, 0.0, 1.0) * u_drawmatrix[0][2];
	outcolor += (shinecolor * shine + vec3(0.5) * rim) * u_drawmatrix[0][2];
	
	// Emission
	outcolor = mix(outcolor, diffusecolor.rgb, u_drawmatrix[0][1]);
	// Blend Color
	outcolor = mix(outcolor, u_drawmatrix[1].rgb*outcolor.rgb, u_drawmatrix[1].a);
	// Fill Color
	outcolor = mix(outcolor, u_drawmatrix[2].rgb, u_drawmatrix[2].a);
	
	// Alpha
    gl_FragColor = vec4(outcolor, u_drawmatrix[0][0]*diffusecolor.a);
	
	if (gl_FragColor.a <= 0.0) {discard;}
}