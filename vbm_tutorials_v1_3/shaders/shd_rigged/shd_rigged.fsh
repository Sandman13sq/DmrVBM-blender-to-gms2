//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec3 v_vNormal;
varying vec3 v_vLightDir;

void main()
{
	float dp = dot(normalize(v_vLightDir), normalize(v_vNormal));	// Ratio that normal faces light value
	dp = max(0.0, dp) * 0.5 + 0.5;
	
    gl_FragColor = v_vColour * texture2D( gm_BaseTexture, vec2(v_vTexcoord.x, v_vTexcoord.y) );	
	gl_FragColor.rgb *= dp; // Multiply color by dot product
}
