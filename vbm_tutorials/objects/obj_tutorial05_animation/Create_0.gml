/// @desc Initializing Variables

// Camera ----------------------------------------------
viewposition = [0, 0, 0.8];	// Location to point the camera at
viewxrot = -10;	// Camera's vertical rotation
viewzrot = 10;	// Camera's horizontal rotation
viewdistance = 2.4;	// Distance from camera position

fieldofview = 50;	// Angle of vision
znear = 0.1;	// Clipping distance for close triangles
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

vbm_starcie = vbm_starcie.Duplicate();

// *Open TRK -------------------------------------------
trk_lean = new TRKData();	// Initialize new TRK data
OpenTRK(trk_lean, "assets/starcie/lean.trk");	// Read in TRK from file

trk_stand = new TRKData();	// Initialize new TRK data
OpenTRK(trk_stand, "assets/starcie/stand.trk");	// Read in TRK from file

trk_peace = new TRKData();	// Initialize new TRK data
OpenTRK(trk_peace, "assets/starcie/peace.trk");	// Read in TRK from file

trk_blink = new TRKData();	// Initialize new TRK data
OpenTRK(trk_blink, "assets/starcie/blink.trk");	// Read in TRK from file

trkanimator = new TRKAnimator();	// Initialize animator
trkanimator.ReadTransformsFromVBM(vbm_starcie);	// Update bone indices by name

trk_lean = trk_lean.Duplicate();

trkanimator.DefineAnimation("lean", trk_lean);	// Add animation to pool
trkanimator.DefineAnimation("stand", trk_stand);	// Add animation to pool
trkanimator.DefineAnimation("peace", trk_peace);	// Add animation to pool
trkanimator.DefineAnimation("blink", trk_blink);	// Add animation to pool

trkanimator.AddLayer().SetAnimationKey("lean");	// Create Layer 0 and set animation
trkanimator.AddLayer().SetAnimationKey("blink");	// Create Layer 1 and set animation

trkanimator.BakeAnimations();

/*
	Layer 0 will evaluate first, Layer 1 second.
	The "blink" animation only contains tracks for the eye lids,
	meaning "blink" is overlayed on the "lean" animation.
*/

// *Texture from file ----------------------------------
spr_col = sprite_add("assets/starcie/starcie_col.png", 1, false, false, 0, 0);
tex_col = sprite_get_texture(spr_col, 0);

// *Model Controls -------------------------------------
zrot = 0;
lightpos = [8, 32, 32];

// *Playback Controls ----------------------------------
playbackmode = TRK_AnimatorCalculation.track; // 0 = Evaluated, 1 = Pose, 2 = Tracks
playbackspeed = 1;
playbackkeys = ["lean", "stand", "peace"];
playbackkeyindex = 0;

// *Shader Uniforms ------------------------------------
u_rigged_light = shader_get_uniform(shd_rigged, "u_lightpos");
u_rigged_matpose = shader_get_uniform(shd_rigged, "u_matpose");	// Handler for pose matrix array

event_perform(ev_step, 0);	// Force an update
