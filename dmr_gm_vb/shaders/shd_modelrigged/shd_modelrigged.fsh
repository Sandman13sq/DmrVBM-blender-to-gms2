//
// Simple passthrough fragment shader
//

// Passed from Vertex Shader
varying vec3 v_pos;
varying vec2 v_uv;
varying vec4 v_color;
varying vec3 v_nor;

varying vec3 v_lightdir_cs;
varying vec3 v_eyedir_cs;
varying vec3 v_nor_cs;

// Uniforms passed in before draw call
uniform vec4 u_drawmatrix[4]; // [alpha emission shine ??? colorfill[4], colorblend[4]]

void main()
{
	vec3 l = normalize(v_lightdir_cs);	// Light Direction
	vec3 n = normalize(v_nor_cs);		// Vertex Normal
	vec3 e = normalize(v_eyedir_cs);	// Camera Direction
	vec3 r = reflect(l, n);				// Reflect Angle
	//c.y *= -1.0;
	
	// Dot Product
	float dp = clamp(dot(n, l), 0.0, 1.0);
	dp = pow(dp, 0.5);
	
	// Fake Fresnel
	float fresnel = dot(n, -e);
	fresnel = clamp(pow(1.0-fresnel, 8.0)+0.02, 0.0, 1.0);
	fresnel = float(fresnel > 0.1);
	
	// Specular
	//float shine = pow(dp + 0.01, 512.0);
	//float shine = pow(dp + 0.03, 512.0);
	float shine = pow( clamp( dot(e, r), 0.0, 1.0) + 0.02, 512.0 );
	
	vec4 diffusecolor = v_color * texture2D( gm_BaseTexture, v_uv);
	diffusecolor = mix(texture2D( gm_BaseTexture, v_uv), v_color, 
		float(texture2D( gm_BaseTexture, vec2(0.0))==vec4(1.0)));
	vec3 shadowtint = mix(vec3(0.1, 0.0, 0.5), vec3(.5, .0, .2), u_drawmatrix[0].w);
	vec3 shadowcolor = mix(diffusecolor.rgb * shadowtint, diffusecolor.rgb, 0.7);
	vec3 shinecolor = diffusecolor.rgb * vec3(1.0-(length(diffusecolor.rgb)*0.65));
	
	vec3 outcolor = mix(shadowcolor, diffusecolor.rgb, dp);
	//outcolor += (diffusecolor.rgb * 0.4) * clamp(shine+fresnel, 0.0, 1.0);
	outcolor += shinecolor * clamp(shine+fresnel, 0.0, 1.0) * u_drawmatrix[0][2];
	
	// Emission
	outcolor = mix(outcolor, diffusecolor.rgb, u_drawmatrix[0][1]);
	// Blend Color
	outcolor = mix(outcolor, u_drawmatrix[1].rgb*outcolor.rgb, u_drawmatrix[1].a);
	// Fill Color
	outcolor = mix(outcolor, u_drawmatrix[2].rgb, u_drawmatrix[2].a);
	
	// Alpha
    gl_FragColor = vec4(outcolor, u_drawmatrix[0][0]*diffusecolor.a);
	
	if (gl_FragColor.a <= 0.0) {discard;}
	
	//gl_FragColor = vec4(vec3(dp), 1.0);
	//gl_FragColor.r += fresnel;
	//gl_FragColor.b += shine;
	//gl_FragColor = vec4(vec3(fresnel), 1.0);
	//gl_FragColor = vec4(vec3(shine), 1.0);
	//gl_FragColor = vec4(vec2(v_vTexcoord), 0.0, 1.0);
	
}
