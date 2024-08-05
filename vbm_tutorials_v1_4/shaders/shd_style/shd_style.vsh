//
// Simple passthrough vertex shader
//
attribute vec3 in_Position;	// (x, y, z)
attribute vec2 in_TextureCoord;	// (u, v)
attribute vec4 in_Colour0;	// (b0, b1, b2, b3)
attribute vec4 in_Colour1;	// (w0, w1, w2, w3)
attribute vec4 in_Colour2;	// (nx, ny, nz, v)

varying vec2 v_uv;
varying vec3 v_position;
varying vec3 v_normal;
varying vec4 v_color;
varying float v_netweight;
varying float v_outline;

varying vec3 v_eyeforward;
varying vec3 v_eyeright;
varying vec3 v_eyeup;

// Uniforms - Passed in in draw call
uniform mat4 u_bonematrices[192];	// Bone transforms
uniform float u_boneselect;	// Index of bone to show weights for
uniform float u_outline;
uniform vec3 u_eyeforward;
uniform vec3 u_eyeright;
uniform vec3 u_eyeup;

void main()
{
	// Convert unit values [0.0-1.0] to appropriate values
	ivec4 bone = ivec4(in_Colour0 * 255.0);	// [0.0 : 1.0] -> [0 : 255]
	vec4 weight = in_Colour1;	// Already [0.0 : 1.0]
	vec4 normal = in_Colour2 * vec4(2.0) - vec4(1.0);	// [0.0 : 1.0] -> [-1.0 : 1.0]
	
	// Summation of bone matrices multiplied by bone weight
	mat4 m = mat4(0.0);
	for (int i = 0; i < 4; i++) {
		m += u_bonematrices[bone[i]] * weight[i];
	}
	
    vec4 object_space_pos = vec4( in_Position.xyz, 1.0);	// w = 1.0 since this is a position
    vec4 object_space_nor = vec4( normal.xyz, 0.0);	// w = 0.0 since this is a direction
	object_space_pos = m * object_space_pos;	// Matrix MUST be left operand
	object_space_nor = m * object_space_nor;	// Matrix MUST be left operand
	
	object_space_pos += object_space_nor * 0.004 * u_outline * in_Colour2.w;	// Offset outline shell
	
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * object_space_pos;
    
	// Varyings ------------------------------------------------------------
    v_uv = in_TextureCoord;
	v_position = (gm_Matrices[MATRIX_WORLD] * object_space_pos).xyz;
	v_normal =   (gm_Matrices[MATRIX_WORLD] * object_space_nor).xyz;
	v_color = vec4(0.5);
	
	v_eyeforward = u_eyeforward;
	v_eyeright = u_eyeright;
	v_eyeup = u_eyeup;
	
	// Net weight for bone selection. Color set in fragment shader
	float netweight = 0.0;
	for (int i = 0; i < 4; i++) {
		netweight += weight[i] * max(0.0, (0.5-abs(u_boneselect-bone[i])) * 2.0);
	}
	netweight = mix(-1.0, netweight, float(u_boneselect > 0.0));
	v_netweight = netweight;
	
	v_outline = float(u_outline > 0.01);
}
