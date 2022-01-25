//
// Simple passthrough fragment shader
//

varying vec3 v_vNormal;
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

void main()
{
	vec3 n = normalize(v_vNormal);	// Normal vector for fragment
	vec3 l = normalize(vec3(0.1, 0.5, 0.5));	// Light vector
	float dp = dot(n, l);
	
    gl_FragColor = v_vColour * texture2D( gm_BaseTexture, v_vTexcoord );
	gl_FragColor.rgb *= dp;
}
