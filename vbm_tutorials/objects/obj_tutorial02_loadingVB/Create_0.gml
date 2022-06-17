/// @desc Initializing Variables

// *Camera ----------------------------------------------
viewposition = [1, 4, 4]; // Camera position
cameralookat = [0, 0, 0];	// Camera eye target

fieldofview = 50;	// Angle of vision
znear = 1;	// Clipping distance for close triangles
zfar = 100;	// Clipping distance for far triangles

// Projection Matrix maps pixels to the screen
matproj = matrix_build_projection_perspective_fov(
	fieldofview,
	window_get_width()/window_get_height(),	// Screen ratio
	znear,
	zfar
	);
// View Matrix maps world to camera eye
matview = matrix_build_lookat(
	viewposition[0], viewposition[1], viewposition[2],	// Camera location 
	cameralookat[0], cameralookat[1], cameralookat[2],			// Camera eye target
	0, 0, 1														// "Up" orientation of camera
	);
mattran = matrix_build_identity(); // World/Model transform

// Vertex format ---------------------------------------
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_simple = vertex_format_end();

// *Load Vertex Buffer ----------------------------------
vb_axis = OpenVertexBuffer("axis.vb", vbf_simple); // Load "axis.vb" from file
