/// @desc Initializing Variables

// Camera ----------------------------------------------
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

// *Vertex formats -------------------------------------
vertex_format_begin();
vertex_format_add_position_3d();
vertex_format_add_color();
vertex_format_add_texcoord();
vbf_simple = vertex_format_end();

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
vb_grid = OpenVertexBuffer("assets/grid.vb", vbf_simple);
vb_axis = OpenVertexBuffer("assets/axis.vb", vbf_simple);

// *Open VBM -------------------------------------------
vbm_starcie = new VBMData();
OpenVBM(vbm_starcie, "assets/starcie/model_rigged.vbm");	// VBM creates and stores format needed to render if none is given.

// *Open TRK -------------------------------------------
trk_lean = new TRKData();	// Initialize new TRK data
OpenTRK(trk_lean, "assets/starcie/tutorial5.trk");	// Read in TRK from file

trk_blink = new TRKData();	// Initialize new TRK data
OpenTRK(trk_blink, "assets/starcie/blink.trk");	// Read in TRK from file

trkanimator = new TRKAnimator();	// Initialize animator
trkanimator.ReadTransformsFromVBM(vbm_starcie);	// Update bone indices by name

trkanimator.DefineAnimation("lean", trk_lean);	// Add animation to pool
trkanimator.DefineAnimation("blink", trk_blink);	// Add animation to pool

trkanimator.AddLayer().SetAnimationKey("lean");	// Create Layer 1 and set animation
trkanimator.AddLayer().SetAnimationKey("blink");	// Create Layer 2 and set animation

/*
	Layer 1 will evaluate first, Layer 2 second.
	The "blink" animation only contains tracks for the eye lids,
	meaning "blink" is overlayed on the "idle" animation.
*/

// *Texture from file ----------------------------------
spr_col = sprite_add("assets/starcie/starcie_col.png", 1, false, false, 0, 0);
tex_col = sprite_get_texture(spr_col, 0);

// *Model Controls -------------------------------------
zrot = 0;
lightpos = [8, 32, 32];

// *Playback Controls ----------------------------------
playbackmode = 0; // 0 = Tracks, 1 = Matrices
playbackspeed = 1;

// *Shader Uniforms ------------------------------------
u_rigged_light = shader_get_uniform(shd_rigged, "u_lightpos");
u_rigged_matpose = shader_get_uniform(shd_rigged, "u_matpose");	// Handler for pose matrix array

event_perform(ev_step, 0);	// Force an update
