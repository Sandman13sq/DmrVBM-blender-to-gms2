//	Makes use of normal attribute and shading
//	Uses normal mapping techniques from learnopengl.com
//	https://learnopengl.com/Advanced-Lighting/Normal-Mapping 
attribute vec3 in_Position;       // (x,y,z)
attribute vec3 in_Normal;         // (x,y,z)
attribute vec3 in_Tangent;        // (x,y,z)
//attribute vec3 in_Bitangent;    // (x,y,z); Calculated with cross(normal, tangent)
attribute vec4 in_Colour;         // (r,g,b,a)
attribute vec2 in_TextureCoord;   // (u,v)

varying vec2 v_vTexcoord;
varying vec4 v_vColour;
//varying vec3 v_vNormal;	// Normal vector to pass to fragment shader
varying vec3 v_vLightDir;	// Light vector to pass to fragment shader
varying vec3 v_vEyeDir;	// Eye vector to pass to fragment shader

// Uniforms - Passed in in draw call
uniform vec3 u_lightpos;	// Passed in in draw call
uniform vec3 u_eyepos;	// Passed in in draw call

void main()
{
    vec4 object_space_pos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);	// w value is 1 for positional vectors
    //vec4 object_space_nor = vec4( in_Normal.x, in_Normal.y, in_Normal.z, 0.0);	// w value is 0 for directional vectors
	
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * object_space_pos;
    
	// Varyings ------------------------------------------------------------
    v_vColour = in_Colour;
    v_vTexcoord = in_TextureCoord;
	
	vec3 T = normalize( vec3(gm_Matrices[MATRIX_WORLD] * vec4(in_Tangent.xyz, 0.0)) );
	vec3 N = normalize( vec3(gm_Matrices[MATRIX_WORLD] * vec4(in_Normal.xyz, 0.0)) );
	T = normalize(T - dot(T,N) * N);	// re-orthogonalize T with respect to N
	vec3 B = cross(N, T);	// B = N x T
	mat3 tbn = mat3(T[0], B[0], N[0], T[1], B[1], N[1], T[2], B[2], N[2] ); // Manually transpose tbn matrix
	// ( transpose() function not available on OpenGL versions < 4.00. Game maker is ~3.00 )
	
	v_vLightDir = tbn * normalize(u_lightpos.xyz - (gm_Matrices[MATRIX_WORLD] * object_space_pos).xyz);
	v_vEyeDir = tbn * normalize(u_eyepos.xyz - (gm_Matrices[MATRIX_WORLD] * object_space_pos).xyz);
}
