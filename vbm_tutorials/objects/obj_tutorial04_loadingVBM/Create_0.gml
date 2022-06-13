/// @desc Initializing Variables

// Camera ----------------------------------------------
cameraposition = [0, 0, 8];	// Location to point the camera at
cameraxrot = -10;	// Camera's vertical rotation
camerazrot = 10;	// Camera's horizontal rotation
cameradistance = 24;	// Distance from camera position

fieldofview = 50;	// Angle of vision
znear = 1;	// Clipping distance for close triangles
zfar = 100;	// Clipping distance for far triangles

matproj = matrix_build_projection_perspective_fov(
	fieldofview, window_get_width()/window_get_height(), znear, zfar);

matview = matrix_build_identity();
mattran = matrix_build_identity();

// Camera Controls
mouseanchor = [window_mouse_get_x(), window_mouse_get_y()];
cameraxrotanchor = cameraxrot;	// Updated when middle mouse is pressed
camerazrotanchor = camerazrot;	// Updated when middle mouse is pressed
movingcamera = false;	// Middle mouse or left mouse + alt is held
movingcameralast = false;	// Used to check when middle has been pressed

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
OpenVBM(vbm_curly, "curly_normal.vbm", vbf_normal);	// Read in VBM from file

// *Model Controls -------------------------------------
zrot = 0;
lightpos = [8, 32, 48];
meshindex = 0;	// Index of current vb
meshvisible = ~0; // Bit field of all 1's

// Shader Uniforms
u_style_lightpos = shader_get_uniform(shd_style, "u_lightpos");

event_perform(ev_step, 0);	// Force an update
