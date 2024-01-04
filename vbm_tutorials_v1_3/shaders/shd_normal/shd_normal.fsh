//
//	Makes use of normal attribute and shading
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec3 v_vNormal;
varying vec3 v_vLightDir;
varying vec3 v_vEyeDir;

void main()
{
	// Ratio that normal faces light value
	float dp = dot(normalize(v_vLightDir), normalize(v_vNormal));
	
	float r = dot(
		reflect(-normalize(v_vLightDir), normalize(v_vNormal)),
		normalize(v_vEyeDir)
		);
	r = clamp(r, 0.0, 1.0);
	r = pow(r, 64.0);
	
    gl_FragColor = v_vColour * texture2D( gm_BaseTexture, v_vTexcoord );	
	gl_FragColor.rgb *= dp; // Multiply color by dot product
	
	gl_FragColor.rgb += gl_FragColor.rgb * r;
}
