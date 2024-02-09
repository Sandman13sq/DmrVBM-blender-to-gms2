/// @desc Initializing Variables

// Camera ----------------------------------------------
viewposition = [0, 0, 1];	// Location to point the camera at
viewhrot = 20;	// Camera's vertical rotation
viewvrot = 10;	// Camera's horizontal rotation
viewdistance = 3;	// Distance from camera position

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

// *Vertex formats -------------------------------------
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_native = vertex_format_end();

/* Rigged format example for reference:

vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_normal();
vertex_format_add_color();
vertex_format_add_texcoord();
vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Indices
vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); // Bone Weights
vbf_rigged = vertex_format_end();

*/

// Load Vertex Buffers ---------------------------------
vb_grid = OpenVertexBuffer("grid.vb", vbf_native);
vb_axis = OpenVertexBuffer("axis.vb", vbf_native);

// *Open VBM -------------------------------------------
vbm_treat = OpenVBM("treat_rig.vbm");	// Format is handled automatically
animator = vbm_treat.CreateAnimator(2);	// Instance animator using skeleton from vbm

animator.Layer(0).SetAnimation(vbm_treat.AnimationGet(0), true);	// Set animation data directly
animator.Layer(1).PlayAnimation("blink");	// Or play animation using animation name

// *Texture from file ----------------------------------
spr_col = sprite_add("tex_treat_col.png", 1, false, false, 0, 0);
tex_col = sprite_get_texture(spr_col, 0);

// *Model Controls -------------------------------------
zrot = 0;
lightpos = [4, -8, 4];
meshselect = 0;

// *Playback Controls ----------------------------------
playbackspeed = 1;
playbackkeyindex = 0;

// *Shader Uniforms ------------------------------------
u_rigged_light = shader_get_uniform(shd_rigged, "u_lightpos");
u_rigged_matpose = shader_get_uniform(shd_rigged, "u_bonemats");	// Handler for pose matrix array

event_perform(ev_step, 0);	// Force an update
