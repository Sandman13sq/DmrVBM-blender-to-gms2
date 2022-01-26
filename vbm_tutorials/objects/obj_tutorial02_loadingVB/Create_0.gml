/// @desc Initializing Variables

// *Camera ----------------------------------------------
cameraposition = [1, 4, 4]; // Camera position
cameralookat = [0, 0, 0];	// Camera eye target

fieldofview = 50;
znear = 1;
zfar = 100;

matproj = matrix_build_projection_perspective_fov(
	fieldofview, window_get_width()/window_get_height(), znear, zfar);
matview = matrix_build_lookat(
	cameraposition[0], cameraposition[1], cameraposition[2], 
	cameralookat[0], cameralookat[1], cameralookat[2], 
	0, 0, 1);
mattran = matrix_build_identity(); // World/Model transform

// Vertex format ---------------------------------------
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_simple = vertex_format_end();

// *Load Vertex Buffer ----------------------------------
vb_axis = OpenVertexBuffer("axis.vb", vbf_simple); // Load "axis.vb" from file
