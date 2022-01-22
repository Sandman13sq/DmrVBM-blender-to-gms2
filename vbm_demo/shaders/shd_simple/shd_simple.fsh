/*
	Renders vbs with simple colors. No shading
*/

// Passed from Vertex Shader
varying vec3 v_pos;
varying vec4 v_color;
varying vec2 v_uv;

// Uniforms passed in before draw call
uniform vec4 u_drawmatrix[4]; // [alpha emission shine sss colorblend[4], colorfill[4]]

void main()
{
	// Uniforms -------------------------------------------------------
	
	float alpha = u_drawmatrix[0][0];
	float emission = u_drawmatrix[0][1];
	vec4 colorblend = u_drawmatrix[1];
	vec4 colorfill = u_drawmatrix[2];
	
	// Colors ----------------------------------------------------------------
	
	vec4 diffusecolor = v_color * texture2D( gm_BaseTexture, v_uv);
	
	// Output ----------------------------------------------------------------
	
	vec3 outcolor = diffusecolor.rgb;
	
	// Emission
	emission += (1.0-v_color.a);
	outcolor = mix(outcolor, diffusecolor.rgb, emission);
	// Blend Color
	outcolor = mix(outcolor, colorblend.rgb*outcolor.rgb, colorblend.a);
	// Fill Color
	outcolor = mix(outcolor, colorfill.rgb, colorfill.a);
	
	// Alpha
    gl_FragColor = vec4(outcolor, alpha);
	
	if (gl_FragColor.a <= 0.0) {discard;}
}
