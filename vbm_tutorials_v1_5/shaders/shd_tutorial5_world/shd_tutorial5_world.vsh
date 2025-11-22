//
//	Makes use of normal attribute and shading
//
attribute vec3 in_Position;      // (x,y,z)
attribute vec3 in_Normal;        // (x,y,z)
attribute vec4 in_Colour;        // (r,g,b,a)
attribute vec2 in_TextureCoord;  // (u,v)

varying vec2 v_vTexcoord;
varying vec4 v_vColour;
varying vec3 v_vNormal;	// Normal vector to pass to fragment shader
varying vec3 v_vLightDir;	// Light vector to pass to fragment shader
varying mat4 v_axes;	// For some reason, can't have the same uniform in both vertex and fragment shader

uniform mat4 u_axes;	// <right, up, forward, position>

void main()
{
    vec4 object_space_pos = vec4( in_Position.xyz, 1.0);	// w value is 1 for positional vectors
    vec4 object_space_nor = vec4( in_Normal.xyz, 0.0);	// w value is 0 for directional vectors
	
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * object_space_pos;
    
	// Varyings ------------------------------------------------------------
    v_vColour = in_Colour;
    v_vTexcoord = in_TextureCoord;
	v_vNormal = (gm_Matrices[MATRIX_WORLD] * object_space_nor).xyz;	// Matrix MUST be first operand
	
	v_vLightDir = normalize(-u_axes[0].xyz+u_axes[2].xyz);
	v_axes = u_axes;
}
