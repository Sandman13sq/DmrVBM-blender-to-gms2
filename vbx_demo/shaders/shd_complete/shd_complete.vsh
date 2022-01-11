/*
	Renders vbs with skeletal animation and normalmap shading.
*/

// Vertex Attributes
attribute vec3 in_Position;	// (x,y,z)
attribute vec3 in_Normal;	// (nx,ny,nz)     
attribute vec3 in_Tangent;	// (nx,ny,nz)
attribute vec3 in_Bitangent;// (nx,ny,nz)
attribute vec4 in_Color;	// (r,g,b,a)
attribute vec2 in_Uv;		// (u,v)
attribute vec4 in_Bone;		// (b0,b1,b2,b3)
attribute vec4 in_Weight;	// (w0,w1,w2,w3)

// Sent to Fragment Shader
varying vec2 v_uv;
varying vec4 v_color;

varying vec3 v_dirtolight_ts;	// Used for normal mapping
varying vec3 v_dirtocamera_ts;	// ^

// Uniforms passed in before draw call
uniform mat4 u_matpose[200];
uniform vec4 u_light;	// [x, y, z, strength]
uniform mat4 u_mattex;

const vec3 VEC3YFLIP = vec3(1.0, -1.0, 1.0);
const mat3 MAT3YFLIP = mat3(
	1.0,  0.0, 0.0,
	0.0, -1.0, 0.0,
	0.0,  0.0, 1.0
	);

void main()
{
	// Attributes --------------------------------------------------------
    vec4 vertexpos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);
	vec4 normal = vec4( in_Normal.x, in_Normal.y, in_Normal.z, 0.0);
	
	// Weight & Bones ----------------------------------------------------
	mat4 m = mat4(0.0);
	for (int i = 0; i < 4; i++)
	{m += (u_matpose[ int(in_Bone[i]) ]) * in_Weight[i];}
	
	vertexpos = m * vertexpos;
	normal = m * normal;
	
	// Correct Y Flip
	vertexpos.y *= -1.0;
	normal.y *= -1.0;
	
	// Set draw position -------------------------------------------------
	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vertexpos;
    
	// Varyings ----------------------------------------------------------
    v_color = in_Color;
    //v_uv = in_Uv;
    v_uv = ( u_mattex*vec4(in_Uv, 1.0, 1.0) ).xy;
	
	// Shading Variables ----------------------------------------------
	vec3 vertexpos_cs = (gm_Matrices[MATRIX_WORLD_VIEW] * vertexpos).xyz;
	vec3 dirtocamera_cs = vec3(0.0) - vertexpos_cs;
	
	vec3 lightpos_cs = (gm_Matrices[MATRIX_VIEW] * vec4(u_light.xyz, 1.0)).xyz;
	vec3 dirtolight_cs = lightpos_cs + dirtocamera_cs;
	
	// Normal Map Variables ----------------------------------------------
	mat3 matmodelview = mat3(gm_Matrices[MATRIX_WORLD_VIEW]);
	vec3 normal_camspace = matmodelview * normalize(normal.xyz);
	vec3 tangent_camspace = matmodelview * normalize(in_Tangent);
	vec3 bitangent_camspace = matmodelview * normalize(in_Bitangent);
	
	// Tangent, Bitangent, Normal
	mat3 tbn = mat3(tangent_camspace, bitangent_camspace, normal_camspace) * MAT3YFLIP;
	
	// Transpose Matrix
	tbn = mat3(
		tbn[0][0], tbn[1][0], tbn[2][0],
		tbn[0][1], tbn[1][1], tbn[2][1],
		tbn[0][2], tbn[1][2], tbn[2][2]
	);
	
	v_dirtolight_ts = tbn * dirtolight_cs;
	v_dirtocamera_ts = tbn * dirtocamera_cs;
}
