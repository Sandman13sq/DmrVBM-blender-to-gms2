/*
	Industry-style shading (approximately)
	
	NOTE: If you don't see any vertices rendering at all, 
	check that u_matpose is populated with some valid matrices.
*/

// Vertex Attributes - From vertex buffer
attribute vec3 in_Position;     // (x,y,z)
attribute vec3 in_Normal;       // (nx,ny,nz)
attribute vec3 in_Tangent;		// (nx,ny,nz)
attribute vec2 in_TextureCoord; // (u,v)
attribute vec4 in_Bone;		// (b0,b1,b2,b3)
attribute vec4 in_Weight;	// (w0,w1,w2,w3)

// Varyings - Passed to fragment shader
varying vec2 v_uv;

varying vec3 v_dirtolight_ts;	// Used for normal map shading
varying vec3 v_dirtocamera_ts;	// ^

// Uniforms - Passed in in draw call
uniform vec3 u_lightpos;	// Passed in in draw call
uniform mat4 u_matpose[200];

// Matrices
mat4 u_matproj = gm_Matrices[MATRIX_PROJECTION];
mat4 u_matview = gm_Matrices[MATRIX_VIEW];
mat4 u_mattran = gm_Matrices[MATRIX_WORLD];

void main()
{
	// Attributes --------------------------------------------------------
    vec4 vertexpos = vec4( in_Position, 1.0);
	vec4 vertexnormal = vec4( in_Normal, 0.0);
	vec4 vertextangent = vec4( in_Tangent, 0.0);
	vec4 vertexbitangent = vec4(cross(vertexnormal.xyz, vertextangent.xyz), 0.0);	// Cross Product
		
	// Weight & Bones ----------------------------------------------------
	mat4 m = mat4(0.0);
	for (int i = 0; i < 4; i++)
	{m += (u_matpose[ int(in_Bone[i]) ]) * in_Weight[i];}
	
	vertexpos = m * vertexpos;
	vertexnormal = m * vertexnormal;
	vertextangent = m * vertextangent;
	vertexbitangent = m * vertexbitangent;
	
	// Correct Y Flip
	vertexpos.y *= -1.0;
	vertexnormal.y *= -1.0;
	vertextangent.y *= -1.0;
	vertexbitangent.y *= -1.0;
	
	// Varyings ----------------------------------------------------------
    v_uv = in_TextureCoord;
	
	// Shading Variables ----------------------------------------------
	vec3 vertexpos_cs = (u_matview * vertexpos).xyz;
	vec3 v_dirtocamera_cs = vec3(0.0) - vertexpos_cs;
	
	vec3 lightpos_cs = (u_matview * vec4(u_lightpos.xyz, 1.0)).xyz;
	vec3 v_dirtolight_cs = lightpos_cs + v_dirtocamera_cs;
	
	// Normal Map Variables ----------------------------------------------
	mat3 matmodelview = mat3(u_matview);
	vec3 normal_camspace = matmodelview * normalize(vertexnormal.xyz);
	vec3 tangent_camspace = matmodelview * normalize(vertextangent.xyz);
	vec3 bitangent_camspace = matmodelview * normalize(vertexbitangent.xyz);
	
	mat3 tbn = mat3(tangent_camspace, bitangent_camspace, normal_camspace);
	
	tbn = mat3(
		tbn[0][0], tbn[1][0], tbn[2][0],
		tbn[0][1], tbn[1][1], tbn[2][1],
		tbn[0][2], tbn[1][2], tbn[2][2]
	);
	
	v_dirtolight_ts = tbn * v_dirtolight_cs;
	v_dirtocamera_ts = tbn * v_dirtocamera_cs;
	
	// Set draw position -------------------------------------------------
	gl_Position = u_matproj * u_matview * (u_mattran * vertexpos);
	
}
