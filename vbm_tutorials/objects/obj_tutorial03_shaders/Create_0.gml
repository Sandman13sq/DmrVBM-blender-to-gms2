/// @desc Initializing Variables

// *Camera ----------------------------------------------
cameraposition = [2, -24, 12];
cameralookat = [0, 0, 8];

fieldofview = 50;
znear = 1;
zfar = 100;

matproj = matrix_build_projection_perspective_fov(
	fieldofview, window_get_width()/window_get_height(), znear, zfar);
// Y Values are flipped to fix Y flip
matview = matrix_build_lookat(
	cameraposition[0], -cameraposition[1], cameraposition[2], 
	cameralookat[0], -cameralookat[1], cameralookat[2], 
	0, 0, 1);
mattran = matrix_build_identity();

// *Vertex format --------------------------------------
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_simple = vertex_format_end();	// For shd_simple. Identical to GMS default

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_normal = vertex_format_end();	// For shd_normal

// *Load Vertex Buffers --------------------------------
vb_grid = OpenVertexBuffer("grid.vb", vbf_simple);
vb_axis = OpenVertexBuffer("axis.vb", vbf_simple);
vb_shinonoko_simple = OpenVertexBuffer("shinonoko_simple.vb", vbf_simple);
vb_shinonoko_normal = OpenVertexBuffer("shinonoko_normal.vb", vbf_normal);

// *Model Controls
zrot = 0;	// Model rotation
shadermode = 0;	// 0 = simple, 1 = normal
lightpos = [8, 32, 48];	// Light position to pass to shader

// *Shader Uniforms
u_normal_lightpos = shader_get_uniform(shd_normal, "u_lightpos"); // Get uniform handle of light position in shd_normal
