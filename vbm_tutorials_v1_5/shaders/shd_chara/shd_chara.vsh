//
// Simple passthrough vertex shader
//
attribute vec3 in_Position;        // (x,y,z)
attribute vec4 in_Colour;          // Color = (r,g,b,a)
attribute vec2 in_TextureCoord;    // (u,v)
attribute vec4 in_Colour1;         // Normal = (nx, ny, nz, 0)
attribute vec4 in_Colour2;         // Bone = (b0, b1, b2, b3)
attribute vec4 in_Colour3;         // Weight = (w0, w1, w2, w3)

varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec3 v_vNormal;

varying vec3 v_axes[4];

uniform mat4 u_skinning[200];
uniform mat4 u_axes;

void main()
{
	// Input attributes
    vec4 position = vec4(in_Position, 1.0);
    vec4 normal = vec4(in_Colour1.xyz * vec3(2.0)-vec3(1.0), 0.0);	// Normalize to [-1.0:1.0] range
	ivec4 bone = ivec4(in_Colour2 * 255.0);	// Convert to integer vector
	vec4 weight = vec4(in_Colour3);
	
	// Vertex Skinning
	mat4 mskin = mat4( float(u_skinning[0][3][3]==0.0) );	// Identity matrix if uniform is not set
	for (int i = 0; i < 4; i++) {
		mskin += u_skinning[bone[i]] * weight[i];
	}
	position = mskin * position;
	normal = mskin * normal;
	
	// Apply world transformation
	position = gm_Matrices[MATRIX_WORLD] * position;
	normal = gm_Matrices[MATRIX_WORLD] * normal;
	
	// Output
    gl_Position = gm_Matrices[MATRIX_PROJECTION] * gm_Matrices[MATRIX_VIEW] * position;
    
    v_vColour = in_Colour.rgba;
    v_vNormal = normal.xyz;
    v_vTexcoord = in_TextureCoord.xy;
	
	v_axes[0] = u_axes[0].xyz;
	v_axes[1] = u_axes[1].xyz;
	v_axes[2] = u_axes[2].xyz;
}
