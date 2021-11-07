//
// Simple passthrough fragment shader
//

// Passed from Vertex Shader
varying vec3 v_pos;
varying vec4 v_color;
varying vec2 v_uv;

// Uniforms passed in before draw call
uniform vec4 u_drawmatrix[4]; // [alpha emission shine ??? colorfill[4] colorblend[4]]

void main()
{
	vec4 diffusecolor = v_color * texture2D( gm_BaseTexture, v_uv);
	diffusecolor = mix(texture2D( gm_BaseTexture, v_uv), v_color, 
		float(texture2D( gm_BaseTexture, vec2(0.0))==vec4(1.0)));
	
	vec3 outcolor = diffusecolor.rgb;
	
	// Emission
	outcolor = mix(outcolor, diffusecolor.rgb, u_drawmatrix[0][1]);
	// Fill Color
	outcolor = mix(outcolor, u_drawmatrix[1].rgb, u_drawmatrix[1].a);
	// Blend Color
	outcolor = mix(outcolor, u_drawmatrix[2].rgb*diffusecolor.rgb, u_drawmatrix[2].a);
	
	// Alpha
    gl_FragColor = vec4(outcolor, u_drawmatrix[0][0]*diffusecolor.a);
	
	if (gl_FragColor.a <= 0.0) {discard;}
}
