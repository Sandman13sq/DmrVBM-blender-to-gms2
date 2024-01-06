/// @desc Initializing Variables

// *Camera ----------------------------------------------
viewposition = [0, 0, 1];	// Location to point the camera at
viewhrot = 0;	// Camera's vertical rotation
viewvrot = 10;	// Camera's horizontal rotation
viewdistance = 2.4;	// Distance from camera position

fieldofview = 50;	// Angle of vision
znear = 0.1;	// Clipping distance for close triangles
zfar = 100;	// Clipping distance for far triangles

matproj = matrix_build_identity();	// Matrices are updated in Step Event
matview = matrix_build_identity();
mattran = matrix_build_identity();

viewforward = [0, 1, 0]
viewright = [1, 0, 0]
viewup = [0, 0, 1];

// Camera Controls
mouseanchor = [window_mouse_get_x(), window_mouse_get_y()];
viewpositionanchor = [0, 0, 0]
viewvrotanchor = viewhrot;	// Updated when middle mouse is pressed
viewhrotanchor = viewvrot;	// Updated when middle mouse is pressed
movingcamera = false;	// Middle mouse or left mouse + alt is held
movingcameralast = false;	// Used to check when middle has been pressed
cameramovemode = 0;	// 0 = Rotate, 1 = Pan

// *Vertex format --------------------------------------
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_native = vertex_format_end();	// For shd_native. Identical to GMS default

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_normal = vertex_format_end();	// For shd_normal

// *Load Vertex Buffers --------------------------------
vb_grid = OpenVertexBuffer("assets/grid.vb", vbf_native);
vb_axis = OpenVertexBuffer("assets/axis.vb", vbf_native);
vb_treat_native = OpenVertexBuffer("assets/treat_native.vb", vbf_native);
vb_treat_normal = OpenVertexBuffer("assets/treat_normal.vb", vbf_normal);

// *Model Controls
zrot = 0;	// Model rotation
shadermode = 0;	// 0 = simple, 1 = normal
lightpos = [4, -8, 8];	// Light position to pass to shader
eyepos = [0, 0, 0];	// View position to pass to shader. Calculated with matview

// *Shader Uniforms
u_normal_lightpos = shader_get_uniform(shd_normal, "u_lightpos"); // Get uniform handle for light position in shd_normal
u_normal_eyepos = shader_get_uniform(shd_normal, "u_eyepos"); // Get uniform handle for eye position in shd_normal

event_perform(ev_step, 0);	// Force an update
