/// @description Initialization

// *Vertex format -------------------------------------
vertex_format_begin();	// Tell GMS that we're defining a format
vertex_format_add_position_3d();	// Vertex Position
vertex_format_add_color();			// Vertex Color + Alpha
vertex_format_add_texcoord();		// Vertex Texture Coordinate/UV
vbf_native = vertex_format_end();	// Tell GM we're done defining the format

// *Triangle Vertex Buffer ------------------------------
vb_tri = vertex_create_buffer();
vertex_begin(vb_tri, vbf_native); // Tell GM to prepare for buffer writing

vertex_position_3d(vb_tri, 100, 200, 0); // First Vertex
vertex_color(vb_tri, c_red, 1);
vertex_texcoord(vb_tri, 0, 0);

vertex_position_3d(vb_tri, 300, 200, 0); // Second Vertex
vertex_color(vb_tri, c_green, 1);
vertex_texcoord(vb_tri, 0, 0);

vertex_position_3d(vb_tri, 200, 100, 0); // Third Vertex
vertex_color(vb_tri, c_blue, 1);
vertex_texcoord(vb_tri, 0, 0);

vertex_end(vb_tri); // Tell GM that the vertex buffer is finished
// vertex_freeze(vb_tri); // We can freeze it to up performance, but then we can't write to the buffer anymore
