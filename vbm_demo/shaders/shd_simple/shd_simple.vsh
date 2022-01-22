/*
	Renders vbs with simple colors. No shading
	
	Used by:
		obj_demomodel_simple
*/

// Vertex Attributes
attribute vec3 in_Position;	// (x,y,z)   
attribute vec4 in_Color;	// (r,g,b,a)
attribute vec2 in_Uv;		// (u,v)

// Passed to Fragment Shader
varying vec3 v_pos;
varying vec4 v_color;
varying vec2 v_uv;

void main()
{
	// Attributes
    vec4 vertexpos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);
	
	// Correct Y Flip
	vertexpos.y *= -1.0;
	
	// Set draw position
	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vertexpos;
    
	// Varyings
	v_pos = (gm_Matrices[MATRIX_WORLD] * vertexpos).xyz;
    v_color = in_Color;
	v_color.a = 1.0;
    v_uv = in_Uv;
}
