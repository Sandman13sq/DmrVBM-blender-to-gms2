//
// Simple passthrough fragment shader
//

// Passed from Vertex Shader
varying vec3 v_pos;
varying vec2 v_uv;
varying vec4 v_color;
varying vec3 v_nor;

uniform vec3 u_camera[2]; // [pos, dir, light]
uniform vec4 u_drawmatrix[4]; // [alpha emission shine ??? colorfill[4] colorblend[4]]

void main()
{
	vec3 l = normalize(vec3(0.5, -3.0, 2.0));
	vec3 n = v_nor;
	vec3 c = normalize(u_camera[0]-v_pos);
	c.y *= -1.0;
	
	// Dot Product
	float dp = clamp(dot(n, l), 0.0, 1.0);
	dp = pow(dp, 0.5);
	
	// Fake Fresnel
	float fresnel = dot(n, c);
	fresnel = clamp(pow(1.0-fresnel, 8.0), 0.0, 1.0);
	fresnel = float(fresnel >= 0.02);
	
	// Specular
	float shine = pow(dp + 0.01, 512.0);
	
	vec4 diffusecolor = v_color * texture2D( gm_BaseTexture, v_uv);
	vec3 shadowcolor = mix(diffusecolor.rgb * vec3(0.1, 0.0, 0.5), diffusecolor.rgb, 0.7);
	
	vec3 outcolor = mix(shadowcolor, diffusecolor.rgb, dp);
	outcolor += (diffusecolor.rgb * 0.4) * clamp(shine+fresnel, 0.0, 1.0);
	
	// Emission
	outcolor = mix(outcolor, diffusecolor.rgb, u_drawmatrix[0][1]);
	// Fill Color
	outcolor = mix(outcolor, u_drawmatrix[1].rgb, u_drawmatrix[1].a);
	// Blend Color
	outcolor = mix(outcolor, u_drawmatrix[2].rgb*diffusecolor.rgb, u_drawmatrix[2].a);
	
    gl_FragColor = vec4(outcolor, u_drawmatrix[0][0]*diffusecolor.a);
	
	if (gl_FragColor.a == 0.0) {discard;}
	
	//gl_FragColor = vec4(vec3(dp), 1.0);
	//gl_FragColor.r += fresnel;
	//gl_FragColor.b += shine;
	//gl_FragColor = vec4(vec3(fresnel), 1.0);
	//gl_FragColor = vec4(vec3(shine), 1.0);
	//gl_FragColor = vec4(vec2(v_vTexcoord), 0.0, 1.0);
}
