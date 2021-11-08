/*
	Renders vbs with simple colors. No shading
*/

// Passed from Vertex Shader
varying vec3 v_pos;
varying vec4 v_color;
varying vec2 v_uv;

// Uniforms passed in before draw call
uniform vec4 u_drawmatrix[4]; // [alpha emission shine ??? colorblend[4], colorfill[4]]

void main()
{
	// Colors ----------------------------------------------------------------
	
	vec4 diffusecolor = v_color * texture2D( gm_BaseTexture, v_uv);
	
	// Output ----------------------------------------------------------------
	
	vec3 outcolor = diffusecolor.rgb;
	
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
