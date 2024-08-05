//
// Simple passthrough fragment shader
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying float v_netweight;
varying vec3 v_position;

uniform float u_meshflash;	// Mesh flash time

void main()
{
	vec3 bonecolor = vec3(.13, .13, .5);
	bonecolor = mix(bonecolor, vec3(.13, .74, .13), min(v_netweight * 2.0, 1.0));
	bonecolor = mix(bonecolor, vec3(1., .13, .13), max(0.0, v_netweight * 2.0 - 1.0));
	
	float d = distance(v_position, vec3(0., 0., 1.5));
    gl_FragColor = v_vColour * texture2D( gm_BaseTexture, v_vTexcoord );
	if (gl_FragColor.a <= 0.1) {discard;}
	
	gl_FragColor.rgb *= mix(vec3(1.0), vec3(.4, .4, .7), min(pow(d, 2.0), 1.0));
	gl_FragColor.rgb = mix(gl_FragColor.rgb, bonecolor, float(v_netweight > -.5) * 0.9);
	
	gl_FragColor = mix(gl_FragColor, vec4(1.0), u_meshflash);
}
