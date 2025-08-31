//
//	Makes use of normal attribute and shading
//
varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec3 v_vNormal;
varying vec3 v_vLightDir;
varying vec3 v_vEyeDir;
varying mat3 v_tbn;	// Used to convert normalmap value from tangent space to world space

void main()
{
	// Normal sampled from normalmap and converted from [0-1] range to [-1,1]
	vec3 normal = texture2D( gm_BaseTexture, v_vTexcoord ).rgb*vec3(2.0)-vec3(1.0);
	
	vec3 incoming = normalize(v_vEyeDir);	// Direction of fragment to camera eye
	vec3 lightdir = normalize(v_vLightDir);	// Direction of fragment to light
	
	// Ratio that normal faces light value (Aligned = 1, Away = -1, Halfway = 0)
	float dp = dot(normal, lightdir);
	
	// Reflection of light direction bouncing off of normal into camera eye
	float dr = dot(reflect(-lightdir, normal), incoming);
	dr = clamp(dr, 0.0, 1.0);
	dr = pow(dr, 64.0);
	
	// Fragment Color
	vec4 color = v_vColour;	// Omit texture color
    gl_FragColor = color;
	gl_FragColor.rgb *= dp; // Multiply color by dot product to get shadow
	gl_FragColor.rgb += vec3(0.5) * dr;	// Add reflection value for specular
}
