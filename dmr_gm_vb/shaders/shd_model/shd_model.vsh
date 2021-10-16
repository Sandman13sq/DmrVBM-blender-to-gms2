//
// Simple passthrough vertex shader
//
attribute vec3 in_Position;	// (x,y,z)
attribute vec3 in_Normal;	// (x,y,z)     
attribute vec4 in_Color;	// (r,g,b,a)
attribute vec2 in_Uv;		// (u,v)

varying vec3 v_pos;
varying vec2 v_uv;
varying vec4 v_color;
varying vec3 v_nor;

void main()
{
    vec4 vertexpos = vec4( in_Position.x, in_Position.y, in_Position.z, 1.0);
	//vertexpos.z *= 0.1;
	
	//gl_Position = (u_matproj * u_matview) * u_mattran * vertexpos;
	gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vertexpos;
    //gl_Position = gm_Matrices[MATRIX_WORLD_VIEW_PROJECTION] * vertexpos;
    
	//v_pos = (u_mattran * vertexpos).xyz;
	v_pos = vertexpos.xyz;
    v_color = in_Color;
	v_color.a = 1.0;
    v_uv = in_Uv;
	v_nor = normalize( (vec4(in_Normal, 0.0)).xyz );
	//v_nor = normalize( (u_mattran * vec4(in_Normal, 0.0)).xyz );
}
