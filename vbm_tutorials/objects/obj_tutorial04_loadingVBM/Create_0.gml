/// @desc Initializing Variables

// *Camera ----------------------------------------------
cameraposition = [2, -24, 12];
cameralookat = [0, 0, 8]; // z value raised to 8

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

// Vertex formats --------------------------------------
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

// *Load Vertex Buffers --------------------------------
vb_grid = OpenVertexBuffer("grid.vb", vbf_simple);
vb_axis = OpenVertexBuffer("axis.vb", vbf_simple);

// *Open VBM -------------------------------------------
vbm_curly = new VBMData();	// Initialize new VBM data
OpenVBM(vbm_curly, "curly.vbm", vbf_normal);	// Read in VBM from file

// *Model Controls -------------------------------------
zrot = 0;
lightpos = [8, 32, 48];
meshindex = 0;	// Index of current vb
meshvisible = ~0; // Bit field of all 1's

// Shader Uniforms
u_style_light = shader_get_uniform(shd_style, "u_lightpos");
