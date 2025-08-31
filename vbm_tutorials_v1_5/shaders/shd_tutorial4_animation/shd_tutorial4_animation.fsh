//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec4 v_vBone;
varying vec4 v_vWeight;

varying float v_vWeightsum; // For weight visual

void main()
{
	gl_FragColor = v_vColour * texture2D( gm_BaseTexture, v_vTexcoord );
	
	// Show bone weights
	if ( v_vWeightsum >= 0.0 ) {
		float w = v_vWeightsum;
		vec3 weightcolor = vec3(
			clamp(w*3.0-1.5, 0.0, 1.0),
			max(0.0, 1.0-abs(w*2.0-1.0)),
			clamp(w*-1.5+0.75, 0.0, 1.0)
		);
		gl_FragColor = mix(gl_FragColor, vec4(weightcolor, 1.0), 0.9 + w*0.1);
	}
}
