//
// Simple passthrough vertex shader
//
attribute vec3 in_Position;		// (x, y, z)
attribute vec3 in_Normal;       // (x,y,z)
attribute vec3 in_Tangent;      // (x,y,z)
attribute vec4 in_Colour;		// (r,g,b,a)
attribute vec2 in_TextureCoord;	// (u,v)
attribute vec4 in_Bone;			// (b0, b1, b2, b3)
attribute vec4 in_Weight;		// (w0, w1, w2, w3)

varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec3 v_position;
varying float v_netweight;

// Uniforms - Passed in in draw call
uniform mat4 u_bonematrices[192];	// Bone transforms
uniform float u_boneselect;	// Index of bone to show weights for

void main()
{
	// Summation of bone matrices multiplied by bone weight
	mat4 m = mat4(0.0);
	for (int i = 0; i < 4; i++) {
		m += u_bonematrices[int(in_Bone[i])] * in_Weight[i];
	}
	
    vec4 object_space_pos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);
	object_space_pos = m * object_space_pos;	// Matrix MUST be left operand
	
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * object_space_pos;
    
	// Varyings ------------------------------------------------------------
    v_vColour = in_Colour;
    v_vTexcoord = in_TextureCoord;
	v_position = in_Position.xyz;
	
	// Net weight for bone selection. Color set in fragment shader
	float netweight = 0.0;
	for (int i = 0; i < 4; i++) {
		netweight += in_Weight[i] * max(0.0, (0.5-abs(u_boneselect-in_Bone[i])) * 2.0);
	}
	netweight = mix(-1.0, netweight, float(u_boneselect > 0.0));
	v_netweight = netweight;
}
