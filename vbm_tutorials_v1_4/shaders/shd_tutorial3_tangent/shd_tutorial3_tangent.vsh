//
//	Makes use of normal attribute and shading
//
attribute vec3 in_Position;                  // (x,y,z)
attribute vec3 in_Normal;                  // (x,y,z)
attribute vec3 in_Tangent;                  // (x,y,z)
attribute vec3 in_Bitangent;                  // (x,y,z)
attribute vec4 in_Colour;                    // (r,g,b,a)
attribute vec2 in_TextureCoord;              // (u,v)

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
	mat3 matmodelview = mat3(gm_Matrices[MATRIX_VIEW]);
	
    vec4 object_space_pos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);	// w value is 1 for positional vectors
    vec4 object_space_nor = vec4( in_Normal.x, in_Normal.y, in_Normal.z, 0.0);	// w value is 0 for directional vectors
	
	vec4 object_space_tangent = vec4( in_Tangent.xyz, 0.0 );
	vec4 object_space_bitangent = vec4( in_Bitangent.xyz, 0.0 );
	//vec4 object_space_bitangent = vec4(cross(object_space_nor.xyz, object_space_tangent.xyz), 0.0);
	
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * object_space_pos;
    
	// Varyings ------------------------------------------------------------
    v_vColour = in_Colour;
    v_vTexcoord = in_TextureCoord;
	
	mat3 tbn = mat3(
		matmodelview * object_space_tangent.xyz,
		matmodelview * object_space_bitangent.xyz, 
		matmodelview * object_space_nor.xyz
	);
	tbn = mat3(	// transpose matrix by hand
		tbn[0][0], tbn[1][0], tbn[2][0],
		tbn[0][1], tbn[1][1], tbn[2][1],
		tbn[0][2], tbn[1][2], tbn[2][2]
	);
	v_vLightDir = tbn * normalize(u_lightpos.xyz - (gm_Matrices[MATRIX_WORLD] * object_space_pos).xyz);
	v_vEyeDir = tbn * normalize(u_eyepos.xyz - (gm_Matrices[MATRIX_WORLD] * object_space_pos).xyz);
}
