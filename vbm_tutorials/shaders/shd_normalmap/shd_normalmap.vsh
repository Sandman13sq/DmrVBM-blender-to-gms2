/*
	Shading with Normal map support
*/

// Vertex Attributes - From vertex buffer
attribute vec3 in_Position;     // (x,y,z)
attribute vec3 in_Normal;       // (nx,ny,nz)
attribute vec3 in_Tangent;		// (nx,ny,nz)
attribute vec3 in_Bitangent;	// (nx,ny,nz)
attribute vec4 in_Colour;       // (r,g,b,a)
attribute vec2 in_TextureCoord; // (u,v)

// Varyings - Passed to fragment shader
varying vec2 v_uv;
varying vec4 v_color;

varying vec3 v_dirtolight_ts;	// Used for normal map shading
varying vec3 v_dirtocamera_ts;	// ^

// Uniforms - Passed in in draw call
uniform vec3 u_lightpos;	// Passed in in draw call

// Matrices
mat4 u_matproj = gm_Matrices[MATRIX_PROJECTION];
mat4 u_matview = gm_Matrices[MATRIX_VIEW];
mat4 u_mattran = gm_Matrices[MATRIX_WORLD];

void main()
{
	// Attributes --------------------------------------------------------
    vec4 vertexpos = vec4( in_Position, 1.0);
	vec4 normal = vec4( in_Normal, 0.0);
	vec4 tangent = vec4( in_Tangent, 0.0);
	vec4 bitangent = vec4( in_Bitangent, 0.0);
	
	// Correct Y Flip
	vertexpos.y *= -1.0;
	normal.y *= -1.0;
	tangent.y *= -1.0;
	bitangent.y *= -1.0;
	
	// Varyings ----------------------------------------------------------
    v_color = in_Colour;
    v_uv = in_TextureCoord;
	
	// Shading Variables ----------------------------------------------
	vec3 vertexpos_cs = (u_matview * vertexpos).xyz;
	vec3 v_dirtocamera_cs = vec3(0.0) - vertexpos_cs;
	
	vec3 lightpos_cs = (u_matview * vec4(u_lightpos.xyz, 1.0)).xyz;
	vec3 v_dirtolight_cs = lightpos_cs + v_dirtocamera_cs;
	
	// Normal Map Variables ----------------------------------------------
	mat3 matmodelview = mat3(u_matview);
	vec3 normal_camspace = matmodelview * normalize(normal.xyz);
	vec3 tangent_camspace = matmodelview * normalize(tangent.xyz);
	vec3 bitangent_camspace = matmodelview * normalize(bitangent.xyz);
	
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
