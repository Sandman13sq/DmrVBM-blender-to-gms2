/// @desc View stuff

limit_intermediate += 0.05*(mouse_wheel_up() - mouse_wheel_down());
limit_intermediate = clamp(limit_intermediate, 0.001, 1);

limit = lerp(limit, limit_intermediate, 0.1);

matview = matrix_build_lookat(
	1,-3,2, 
	0,0,0.5, 
	0,0,1
);

matproj = matrix_build_projection_perspective_fov(
	50,
	-window_get_width()/window_get_height(),
	0.1, 
	100
);

// Vertex Buffer ------------------------------------------------------------------
if (vb != -1) {
	vertex_delete_buffer(vb);
}

vb = vertex_create_buffer();
vertex_begin(vb, format);

// Axes
vertex_position_3d(vb, 0,0,0); vertex_color(vb,0xFF000077,1); vertex_texcoord(vb,0,0); 
vertex_position_3d(vb, 1,0,0); vertex_color(vb,0xFF000077,1); vertex_texcoord(vb,0,0); 
vertex_position_3d(vb, 0,0,0); vertex_color(vb,0xFF007700,1); vertex_texcoord(vb,0,0); 
vertex_position_3d(vb, 0,1,0); vertex_color(vb,0xFF007700,1); vertex_texcoord(vb,0,0); 

// Goal
vertex_position_3d(vb, rx,ry,rz); vertex_color(vb,c_gray,1); vertex_texcoord(vb,0,0); 
vertex_position_3d(vb, gx,gy,gz); vertex_color(vb,c_gray,1); vertex_texcoord(vb,0,0); 

// Particle
vertex_position_3d(vb, rx,ry,rz); vertex_color(vb,c_orange,1); vertex_texcoord(vb,0,0); 
vertex_position_3d(vb, lx,ly,lz); vertex_color(vb,c_maroon,1); vertex_texcoord(vb,0,0); 

vertex_position_3d(vb, rx,ry,rz); vertex_color(vb,c_orange,1); vertex_texcoord(vb,0,0); 
vertex_position_3d(vb, px,py,pz); vertex_color(vb,c_orange,1); vertex_texcoord(vb,0,0); 

// Cross
vertex_position_3d(vb, rx,ry,rz); vertex_color(vb,c_blue,1); vertex_texcoord(vb,0,0); 
vertex_position_3d(vb, cx,cy,cz); vertex_color(vb,c_blue,1); vertex_texcoord(vb,0,0); 

vertex_position_3d(vb, rx,ry,rz); vertex_color(vb,c_fuchsia,0.2); vertex_texcoord(vb,0,0); 
vertex_position_3d(vb, hx,hy,hz); vertex_color(vb,c_fuchsia,0.2); vertex_texcoord(vb,0,0); 

var angle = lerp(-pi/2, pi/2, limit);
var theta = 0;
var v;
var precision = 64;

// Limit = 0
for (var i = 0; i < precision; i++) {
	for (var j = 0; j < 2; j++) {
		v = matrix_transform_vertex(matrix_build(0,0,0, 0,0,theta, 1,1,1), bone_length-0.01,0,0);
		vertex_position_3d(vb, v[0],v[1],v[2]); vertex_color(vb,c_gray,1); vertex_texcoord(vb,0,0); 
		theta += (j==0)*180/(precision/2);
	}
}

// Limit
for (var i = 0; i < precision; i++) {
	for (var j = 0; j < 2; j++) {
		v = matrix_transform_vertex(matrix_build(0,0,0, 0,0,theta, 1,1,1), bone_length*cos(angle), 0, bone_length*sin(angle));
		vertex_position_3d(vb, v[0],v[1],v[2]); vertex_color(vb,c_orange,1); vertex_texcoord(vb,0,0); 
		theta += (j==0)*180/(precision/2);
	}
}

vertex_end(vb);


