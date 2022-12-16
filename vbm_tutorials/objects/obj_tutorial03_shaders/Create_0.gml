/// @desc Initializing Variables

// *Camera ----------------------------------------------
viewposition = [0, 0, 8];	// Location to point the camera at
viewxrot = -10;	// Camera's vertical rotation
viewzrot = 0;	// Camera's horizontal rotation
viewdistance = 24;	// Distance from camera position

fieldofview = 50;	// Angle of vision
znear = 1;	// Clipping distance for close triangles
zfar = 100;	// Clipping distance for far triangles

matproj = matrix_build_projection_perspective_fov(
	fieldofview, window_get_width()/window_get_height(), znear, zfar);

matview = matrix_build_identity();
mattran = matrix_build_identity();

viewforward = [0, -1, 0]
viewright = [1, 0, 0]
viewup = [0, 0, 1];

// Camera Controls
mouseanchor = [window_mouse_get_x(), window_mouse_get_y()];
viewpositionanchor = [0, 0, 0]
viewxrotanchor = viewxrot;	// Updated when middle mouse is pressed
viewzrotanchor = viewzrot;	// Updated when middle mouse is pressed
movingcamera = false;	// Middle mouse or left mouse + alt is held
movingcameralast = false;	// Used to check when middle has been pressed

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
vb_grid = OpenVertexBuffer("assets/grid.vb", vbf_simple);
vb_axis = OpenVertexBuffer("assets/axis.vb", vbf_simple);
vb_starcie_simple = OpenVertexBuffer("assets/starcie/model_simple.vb", vbf_simple);
vb_starcie_normal = OpenVertexBuffer("assets/starcie/model_normal.vb", vbf_normal);

// *Model Controls
zrot = 0;	// Model rotation
shadermode = 0;	// 0 = simple, 1 = normal
lightpos = [8, 32, 48];	// Light position to pass to shader

// *Shader Uniforms
u_normal_lightpos = shader_get_uniform(shd_normal, "u_lightpos"); // Get uniform handle of light position in shd_normal

event_perform(ev_step, 0);	// Force an update
