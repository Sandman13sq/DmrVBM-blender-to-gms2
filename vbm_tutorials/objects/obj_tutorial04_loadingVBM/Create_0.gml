/// @desc Camera Setup

// Camera ----------------------------------------------
cameraposition = [2, -24, 12];
cameralookat = [0, 0, 8];

width = window_get_width();
height = window_get_height();

fieldofview = 50;
znear = 1;
zfar = 100;

matproj = matrix_build_projection_perspective_fov(
	fieldofview, window_get_width()/window_get_height(), znear, zfar);
matview = matrix_build_lookat(
	cameraposition[0], -cameraposition[1], cameraposition[2], 
	cameralookat[0], -cameralookat[1], cameralookat[2], 
	0, 0, 1);
mattran = matrix_build_identity();

// Vertex format ---------------------------------------
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_simple = vertex_format_end();

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_normal = vertex_format_end();

// Load Vertex Buffers ---------------------------------
vb_grid = OpenVertexBuffer("grid.vb", vbf_simple);
vb_axis = OpenVertexBuffer("axis.vb", vbf_simple);

// Open VBM
vbm_curly = new VBMData();
OpenVBM(vbm_curly, "curly.vbm", vbf_normal);

// Model Controls
zrot = 0;
meshindex = 0;
meshvisible = ~0; // Bit field of all 1's
