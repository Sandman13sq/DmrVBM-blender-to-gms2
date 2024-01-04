//
//	Transforms vertices by bone matrices
//
attribute vec3 in_Position;                  // (x,y,z)
attribute vec3 in_Normal;                  // (x,y,z)
attribute vec4 in_Colour;                    // (r,g,b,a)
attribute vec2 in_TextureCoord;              // (u,v)
attribute vec4 in_Bone;						// (b1,b2,b3,b4)
attribute vec4 in_Weight;					// (w1,w2,w3,w4)

varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec3 v_vNormal;	// Normal vector to pass to fragment shader
varying vec3 v_vLightDir;	// Light vector to pass to fragment shader

// Uniforms - Passed in in draw call
uniform vec3 u_lightpos;	// Passed in in draw call
uniform mat4 u_bonemats[128];

void main()
{
    vec4 object_space_pos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);
    vec4 object_space_nor = vec4( in_Normal.x, in_Normal.y, in_Normal.z, 1.0);
	
	// Pose Transform
	mat4 m = mat4(0.0);
	for (int i = 0; i < 4; i++)
	{
		m += u_bonemats[ int(in_Bone[i]) ] * in_Weight[i];
	}
	
	object_space_pos = m * object_space_pos;
	object_space_nor = m * object_space_nor;
	
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * object_space_pos;
    
	// Varyings ------------------------------------------------------------
    v_vColour = in_Colour;
    v_vTexcoord = in_TextureCoord;
	v_vNormal = (gm_Matrices[MATRIX_WORLD] * object_space_nor).xyz;	// Matrix MUST be first operand
	
	v_vLightDir = (u_lightpos - object_space_pos.xyz);
}
