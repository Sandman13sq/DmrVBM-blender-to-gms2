//
// Applies vertex skinning
//
attribute vec3 in_Position;	// (x,y,z)
// attribute vec3 in_Normal;	// (x,y,z)
attribute vec4 in_Colour;	// (r,g,b,a)
attribute vec2 in_TextureCoord;	// (u,v)
attribute vec4 in_Bone;		// (b0,b1,b2,b3)
attribute vec4 in_Weight;	// (w0,w1,w2,w3)

varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec4 v_vNormal;

varying float v_vWeightsum; // For weight visual

// Uniforms - Passed in in draw call
uniform mat4 u_bonematrices[200];	// There is an upper-limit. It depends on platform

uniform float u_boneselect;	// For weight visual
uniform float u_showweights;	// For weight visual

void main()
{
    vec4 object_space_pos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);
	
	// Bone Transformations = Sum of bone.matrix * bone.weight for each bone
	ivec4 bone_indices = ivec4(in_Bone);
	vec4 bone_weights = in_Weight;
	mat4 mskinning = mat4(0.0);	// Start at 0.0. Sum will result in a valid matrix
	for (int i = 0; i < 4; i++) {
		mskinning += u_bonematrices[bone_indices[i]] * bone_weights[i];
	}
	object_space_pos = mskinning * object_space_pos;	// Apply skinning to vertex
	// object_space_nor = mskinning * object_space_nor; // Apply skinning to normal
	
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * object_space_pos;
    
    v_vColour = in_Colour;
    v_vTexcoord = in_TextureCoord;
	
	// Used for weight visual
	if ( u_showweights > 0.0 && u_boneselect >= 0.0 ) {
		float weightsum = 0.0;
		for (int i = 0; i < 4; i++) {
			weightsum += float(abs(u_boneselect-in_Bone[i]) <= 0.5) * in_Weight[i];
		}
		v_vWeightsum = weightsum;
	}
	else {
		v_vWeightsum = -1.0;
	}
}
