/// @desc Initializing Variables

// *Camera ----------------------------------------------
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
	0, 0, 6,	// Camera location 
	0, 0, 0,	// Camera eye target
	0, 1, 0		// "Up" orientation of camera
	);

// *Vertex format ---------------------------------------
vertex_format_begin();	// Tell GMS that we're defining a format
vertex_format_add_position_3d();	// Vertex Position
vertex_format_add_color();			// Vertex Color + Alpha
vertex_format_add_texcoord();		// Vertex Texture Coordinate/UV
vbf_simple = vertex_format_end();	// Tell GMS we're done defining the format

// *Triangle Vertex Buffer ------------------------------
vb_tri = vertex_create_buffer();
vertex_begin(vb_tri, vbf_simple); // Tell GMS to prepare for writing

vertex_position_3d(vb_tri, -1, 0, 0); // First Vertex
vertex_color(vb_tri, c_red, 1);
vertex_texcoord(vb_tri, 0, 0);

vertex_position_3d(vb_tri, 1, 0, 0); // Second Vertex
vertex_color(vb_tri, c_green, 1);
vertex_texcoord(vb_tri, 0, 0);

vertex_position_3d(vb_tri, 0, 2, 0); // Third Vertex
vertex_color(vb_tri, c_blue, 1);
vertex_texcoord(vb_tri, 0, 0);

vertex_end(vb_tri); // Tell GMS that the vertex buffer is finished
// vertex_freeze(vb_tri); // We can freeze it to up performance, but then we can't write to the buffer anymore
