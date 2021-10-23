//
// Simple passthrough vertex shader
//

// Vertex Attributes
attribute vec3 in_Position;	// (x,y,z)
attribute vec3 in_Normal;	// (x,y,z)     
attribute vec4 in_Color;	// (r,g,b,a)
attribute vec2 in_Uv;		// (u,v)
attribute vec4 in_Bone;		// (b0,b1,b2,b3)
attribute vec4 in_Weight;	// (w0,w1,w2,w3)

// Passed to Fragment Shader
varying vec3 v_pos;
varying vec2 v_uv;
varying vec4 v_color;
varying vec3 v_nor;

varying vec3 v_lightdir_cs;
varying vec3 v_eyedir_cs;
varying vec3 v_nor_cs;

// Uniforms passed in before draw call
uniform mat4 u_matpose[200];

const vec3 lightpos_ws = vec3(64.0, -128.0, 80.0);

void main()
{
	// Attributes
    vec4 vertexpos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);
	vec4 normal = vec4( in_Normal.x, in_Normal.y, in_Normal.z, 0.0);
	
	// Weight & Bones
	mat4 m = mat4(0.0);
	for (int i = 0; i < 4; i++)
	{m += (u_matpose[ int(in_Bone[i]) ]) * in_Weight[i];}
	
	vertexpos = m * vertexpos;
	normal = m * normal;
	
	// Set draw position
	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vertexpos;
    
	// Varyings
	v_pos = (gm_Matrices[MATRIX_WORLD] * vertexpos).xyz;
    v_color = in_Color;
	v_color.a = 1.0;
    v_uv = in_Uv;
	v_nor = normalize(gm_Matrices[MATRIX_WORLD] * normal).xyz;
	
	vec3 vertexpos_cs = vec3(0.0)-(gm_Matrices[MATRIX_WORLD_VIEW] * vertexpos).xyz;
	v_eyedir_cs = vec3(0.0) - vertexpos_cs;
	
	vec3 lightpos_cs = (gm_Matrices[MATRIX_VIEW] * vec4(lightpos_ws, 1.0)).xyz;
	v_lightdir_cs = lightpos_cs + v_eyedir_cs;
	
	v_nor_cs = normalize( (gm_Matrices[MATRIX_WORLD_VIEW] * normal).xyz);
	
	//v_eyedir_cs = normalize(v_eyedir_cs);
	//v_lightdir_cs = normalize(v_lightdir_cs);
}
