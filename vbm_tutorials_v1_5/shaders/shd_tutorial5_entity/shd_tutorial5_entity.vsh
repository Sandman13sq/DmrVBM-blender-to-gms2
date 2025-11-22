//
// Applies vertex skinning
//
attribute vec3 in_Position;	// (x,y,z)
attribute vec3 in_Normal;	// (x,y,z)
attribute vec4 in_Colour;	// (r,g,b,a)
attribute vec2 in_TextureCoord;	// (u,v)
attribute vec4 in_Bone;		// (b0,b1,b2,b3)
attribute vec4 in_Weight;	// (w0,w1,w2,w3)

varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec3 v_vNormal;

uniform mat4 u_bonematrices[200];	// Matrix per bone

void main()
{
    vec4 object_space_pos = vec4( in_Position.xyz, 1.0);
    vec4 object_space_nor = vec4( in_Normal.xyz, 0.0);
	
	// Bone Transformations = Sum of bone.matrix * bone.weight for each bone
	if ( length(u_bonematrices[0][0].xyz) != 0.0 ) {
		ivec4 bone_indices = ivec4(in_Bone);
		vec4 bone_weights = in_Weight;
		mat4 mskinning = mat4(0.0);	// Start at 0.0. Sum will result in a valid matrix
		for (int i = 0; i < 4; i++) {
			mskinning += u_bonematrices[bone_indices[i]] * bone_weights[i];
		}
		object_space_pos = mskinning * object_space_pos;	// Apply skinning to vertex
		object_space_nor = mskinning * object_space_nor; // Apply skinning to normal
	}
	
	object_space_pos = gm_Matrices[MATRIX_WORLD] * object_space_pos;
	object_space_nor = gm_Matrices[MATRIX_WORLD] * object_space_nor;
	
    gl_Position = gm_Matrices[MATRIX_PROJECTION] * gm_Matrices[MATRIX_VIEW] * object_space_pos;
    
    v_vNormal = object_space_nor.xyz;
    v_vColour = in_Colour;
    v_vTexcoord = in_TextureCoord;
}
