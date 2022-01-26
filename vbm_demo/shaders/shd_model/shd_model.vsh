/*
	Renders vbs with basic shading.
	
	Used by:
		obj_modeltest (world.vb)
		obj_demomodel_normal
		obj_demomodel_vbm
*/

const vec3 VEC3YFLIP = vec3(1.0, -1.0, 1.0);

// Vertex Attributes
attribute vec3 in_Position;	// (x,y,z)
attribute vec3 in_Normal;	// (x,y,z)     
attribute vec4 in_Color;	// (r,g,b,a)
attribute vec2 in_Uv;		// (u,v)

// Passed to Fragment Shader
//varying vec3 v_pos;
//varying vec3 v_normal;
varying vec2 v_uv;
varying vec4 v_color;

varying vec3 v_dirtolight_cs;	// Used for basic shading
varying vec3 v_dirtocamera_cs;	// ^
varying vec3 v_normal_cs;

uniform vec4 u_light;	// [x, y, z, strength]

void main()
{
	// Attributes
    vec4 vertexpos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);
	vec4 normal = vec4( in_Normal.x, in_Normal.y, in_Normal.z, 0.0);
	
	// Correct Y Flip
	vertexpos.y *= -1.0;
	normal.y *= -1.0;
	
	// Varyings ----------------------------------------------------------
    v_color = in_Color;
    v_uv = in_Uv;
	
	// Shading Variables ----------------------------------------------
	vec3 vertexpos_cs = (gm_Matrices[MATRIX_WORLD_VIEW] * vertexpos).xyz;
	v_dirtocamera_cs = vec3(0.0) - vertexpos_cs;
	
	vec3 lightpos_cs = (gm_Matrices[MATRIX_VIEW] * vec4(u_light.xyz*VEC3YFLIP, 1.0)).xyz;
	v_dirtolight_cs = lightpos_cs + v_dirtocamera_cs;
	
	v_normal_cs = (gm_Matrices[MATRIX_WORLD_VIEW] * normal).xyz;
	
	// Set draw position -------------------------------------------------
	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vertexpos;
}
