/// @desc Initializing Variables

// *Camera ----------------------------------------------
viewposition = [0, 0, 1];	// Location to point the camera at
viewhrot = 0;	// Camera's vertical rotation
viewvrot = 10;	// Camera's horizontal rotation
viewdistance = 2.5;	// Distance from camera position

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
rotationspd = 0;

// *Load Vertex Buffers --------------------------------
model = VBM_Model_Create();	// Initialize model data
VBM_OpenVBM("tutorial5_model.vbm", model);

model_rotation = VBM_Model_Create();	// Shape to draw for swing bones
VBM_OpenVBM("rotation.vbm", model_rotation, 0);

animator = VBM_Animator_Create();	// Initialize animator
VBM_Animator_ResizeLayers(animator, 2);	// Ensure that there are two layers
VBM_Animator_PlayAnimationIndex(animator, 0, 0);	// Layer 0 animation = First animation
VBM_Animator_PlayAnimationKey(animator, 1, "taroh-blink");	// Layer 1 animation = Blink

VBM_Animator_SwingReset(animator, model);

// *Model Controls -------------------------------------
zrot = 0;
lightpos = [4, -8, 4];
mesh_select = 0;
mesh_flash = 0;
mesh_hide_bits = 0;
bone_select = 0;
show_bones = 0;
animcurve = -1;

// *Playback Controls ----------------------------------
playback_speed = 1;
playback_index = 0;
benchmark_count = 0;
benchmark_net = [0,0,0];

// *Shader Uniforms
u_style_bonematrices = shader_get_uniform(shd_tutorial5_style, "u_bonematrices"); // Get uniform handle for transform array in shd_tutorial5_style
u_style_boneselect = shader_get_uniform(shd_tutorial5_style, "u_boneselect"); // Get uniform handle for bone selection in shd_tutorial5_style
u_style_meshflash = shader_get_uniform(shd_tutorial5_style, "u_meshflash"); // Get uniform handle for mesh selection in shd_tutorial5_style
u_style_outline = shader_get_uniform(shd_tutorial5_style, "u_outline"); // Get uniform handle for outline value in shd_tutorial5_style
u_style_eyeforward = shader_get_uniform(shd_tutorial5_style, "u_eyeforward"); // Get uniform handle for forward vector in shd_tutorial5_style
u_style_eyeright = shader_get_uniform(shd_tutorial5_style, "u_eyeright"); // Get uniform handle for right vector in shd_tutorial5_style
u_style_eyeup = shader_get_uniform(shd_tutorial5_style, "u_eyeup"); // Get uniform handle for up vector in shd_tutorial5_style

event_perform(ev_step, 0);	// Force an update
