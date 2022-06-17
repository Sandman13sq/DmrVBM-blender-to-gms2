/*
	All types of attributes in one shader.
	NOTE: Normal mapping is a little strange after applying pose transform
*/

// Vertex Attributes - From vertex buffer
attribute vec3 in_Position;     // (x,y,z)
attribute vec3 in_Normal;       // (nx,ny,nz)
attribute vec3 in_Tangent;		// (nx,ny,nz)
attribute vec3 in_Bitangent;	// (nx,ny,nz)
attribute vec4 in_Colour;       // (r,g,b,a)
attribute vec2 in_TextureCoord; // (u,v)
attribute vec4 in_Bone;		// (b0,b1,b2,b3)
attribute vec4 in_Weight;	// (w0,w1,w2,w3)

// Varyings - Passed to fragment shader
varying vec2 v_uv;
varying vec4 v_color;

varying vec3 v_dirtolight_cs;	// Used for basic shading
varying vec3 v_dirtocamera_cs;	// ^
varying vec3 v_dirtolight_ts;	// Used for normal map shading
varying vec3 v_dirtocamera_ts;	// ^
varying vec3 v_normal_cs;

// Uniforms - Passed in in draw call
uniform vec3 u_lightpos;	// Passed in in draw call
uniform mat4 u_matpose[200];

void main()
{
	// Attributes --------------------------------------------------------
    vec4 vertexpos = vec4( in_Position, 1.0);
	vec4 vertexnormal = vec4( in_Normal, 0.0);
	
	// Weight & Bones ----------------------------------------------------
	mat4 m = mat4(0.0);
	for (int i = 0; i < 4; i++)
	{m += (u_matpose[ int(in_Bone[i]) ]) * in_Weight[i];}
	
	vertexpos = m * vertexpos;
	vertexnormal = m * vertexnormal;
	
	vertexpos.y *= -1.0;
	vertexnormal.y *= -1.0;
	
	// Varyings ----------------------------------------------------------
    v_color = in_Colour;
    v_uv = in_TextureCoord;
	
	// Shading Variables ----------------------------------------------
	vec3 vertexpos_cs = (gm_Matrices[MATRIX_WORLD_VIEW] * vertexpos).xyz;
	v_dirtocamera_cs = vec3(0.0) - vertexpos_cs;
	
	vec3 lightpos_cs = (gm_Matrices[MATRIX_VIEW] * vec4(u_lightpos.xyz, 1.0)).xyz;
	v_dirtolight_cs = lightpos_cs + v_dirtocamera_cs;
	
	v_normal_cs = normalize( (gm_Matrices[MATRIX_WORLD_VIEW] * vertexnormal).xyz);
	
	// Normal Map Variables ----------------------------------------------
	mat3 matmodelview = mat3(gm_Matrices[MATRIX_WORLD_VIEW]);
	vec3 normal_camspace = matmodelview * normalize(vertexnormal.xyz);
	vec3 tangent_camspace = matmodelview * normalize(in_Tangent);
	vec3 bitangent_camspace = matmodelview * normalize(in_Bitangent);
	
	mat3 tbn = mat3(tangent_camspace, bitangent_camspace, normal_camspace);
	
	tbn = mat3(
		tbn[0][0], tbn[1][0], tbn[2][0],
		tbn[0][1], tbn[1][1], tbn[2][1],
		tbn[0][2], tbn[1][2], tbn[2][2]
	);
	
	v_dirtolight_ts = tbn * v_dirtolight_cs;
	v_dirtocamera_ts = tbn * v_dirtocamera_cs;
	
	// Set draw position -------------------------------------------------
    gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vertexpos;
}
