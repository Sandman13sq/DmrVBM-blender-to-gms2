/*
	Calculates camera space normals and eye vector
*/

// Vertex Attributes - From vertex buffer
attribute vec3 in_Position;     // (x,y,z)
attribute vec3 in_Normal;       // (nx,ny,nz)
attribute vec4 in_Colour;       // (r,g,b,a)
attribute vec2 in_TextureCoord; // (u,v)
attribute float in_Outline; // (x)

// Varyings - Passed to fragment shader
varying vec2 v_vTexcoord;
varying vec4 v_vColour;

varying vec3 v_dirtolight_cs;	// Used for basic shading
varying vec3 v_dirtocamera_cs;	// ^
varying vec3 v_normal_cs;

varying float v_outline;

// Uniforms - Passed in in draw call
uniform vec3 u_lightpos;	// Passed in in draw call
uniform float u_outline;	// Distance to move normals

void main()
{
	// Attributes --------------------------------------------------------
    vec4 vertexpos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);
    vec4 vertexnormal = vec4( in_Normal.x, in_Normal.y, in_Normal.z, 0.0);
	
	vertexpos.y *= -1.0;
	vertexnormal.y *= -1.0;
	
	// Move vertex by outline, adjusted by camera distance
	float distancetocamera = distance(vertexpos.xyz, gm_Matrices[MATRIX_VIEW][3].xyz);
	vertexpos += vertexnormal * u_outline * u_outline * in_Outline * distancetocamera * 0.01;
	
	// Varyings ----------------------------------------------------------
    v_vColour = in_Colour;
    v_vTexcoord = in_TextureCoord;
	v_outline = u_outline;
	
	// Shading Variables ----------------------------------------------
	vec3 vertexpos_cs = (gm_Matrices[MATRIX_WORLD_VIEW] * vertexpos).xyz;
	v_dirtocamera_cs = vec3(0.0) - vertexpos_cs;
	
	vec3 lightpos_cs = (gm_Matrices[MATRIX_VIEW] * vec4(u_lightpos.xyz, 1.0)).xyz;
	v_dirtolight_cs = lightpos_cs + v_dirtocamera_cs;
	
	v_normal_cs = normalize( (gm_Matrices[MATRIX_WORLD_VIEW] * vertexnormal).xyz);
	
	// Set draw position -------------------------------------------------
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vertexpos;
}
