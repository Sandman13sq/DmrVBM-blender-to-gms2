//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec3 v_vNormal;
varying vec3 v_vLightDir;

void main()
{
	float lightoffset = v_vColour.r;
	float dp = dot(normalize(v_vLightDir), normalize(v_vNormal));	// Ratio that normal faces light vector
	dp = clamp(dp + lightoffset * 2.0 - 0.9, 0.0, 1.0);
	
	vec3 colorDark = vec3(0.5, 0.3, 0.6);
    gl_FragColor = texture2D( gm_BaseTexture, vec2(v_vTexcoord.x, v_vTexcoord.y) );	// Texture Only
	
	// Multiply color by dark color with ratio of dot product
	gl_FragColor.rgb = mix(gl_FragColor.rgb * colorDark, gl_FragColor.rgb, dp);
}
