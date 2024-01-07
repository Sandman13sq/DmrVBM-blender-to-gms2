//
//	Transforms vertices by bone matrices. Uses color attribute as bones and weights
//
attribute vec3 in_Position;                  // (x,y,z)
attribute vec4 in_Colour;                    // (b1,b2,w1,w2)
attribute vec2 in_TextureCoord;              // (u,v)

varying vec2 v_vTexcoord;
varying vec4 v_vColour;

// Uniforms - Passed in in draw call
uniform vec3 u_lightpos;	// Passed in in draw call
uniform mat4 u_bonemats[128];

void main()
{
    vec4 object_space_pos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);
	
	// Pose Transform
	mat4 m = mat4(0.0);
	for (int i = 0; i < 2; i++)
	{
		m += u_bonemats[ int(in_Colour[i]) ] * in_Colour[i+1];
	}
	
	object_space_pos = m * object_space_pos;
	
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * object_space_pos;
    
	// Varyings ------------------------------------------------------------
    v_vColour = in_Colour;
    v_vTexcoord = in_TextureCoord;
}
