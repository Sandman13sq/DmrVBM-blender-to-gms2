/// @desc Initializing Variables

// *Camera ----------------------------------------------
view_position = [0, 0, 1];	// Location to point the camera at
view_euler = [10,0,0];	// <xrot, yrot, zrot>
view_distance = 2.5;	// Distance from camera position

fieldofview = 50;	// Angle of vision
znear = 0.1;	// Clipping distance for close triangles
zfar = 100;	// Clipping distance for far triangles

matproj = matrix_build_identity();	// Matrices are updated in Step Event
matview = matrix_build_identity();
mattran = matrix_build_identity();

// Camera Controls
mouse_anchor = [window_mouse_get_x(), window_mouse_get_y()];
view_position_anchor = [0, 0, 0];
view_euler_anchor = [0,0,0];	// Updated when middle mouse is pressed
moving_model = false;	// Middle mouse or left mouse + alt is held
moving_model_last = false;	// Used to check when middle has been pressed
cameramovemode = 0;	// 0 = Rotate, 1 = Pan
rotationspd = 0;

// *Load Vertex Buffers --------------------------------
model = VBM_Model_Create();	// Initialize model data
VBM_Open(model, "tutorial4_animation.vbm");	// Animation comes packed into file
animation = VBM_Model_GetAnimation(model, 0);	// Animation exported with model

// *Model Controls -------------------------------------
model_location = [0,0,0];	// [x, y, z]
model_velocity = [0,0,0];
model_euler = [0,0,10];	// [xrot, yrot, zrot]

mesh_select = 0;	// Index of actively selected mesh
mesh_flash = 0.0;	// Step for flashing newly selected meshes
mesh_visible_layermask = ~0;	// Bitmask where active bits represent visible mesh layers. "~0" means all bits are set
bone_select = 0;	// Index of bone to show weights for
show_weights = 0;	// Toggle for showing weights

animation_index = 0;	// Active animation index
animation_blend = 1.0;	// Blend amount. 0 = last transform, 1 = new transform
animation_blend_time = 30;	// Number of frames to transition from last transform to new

jump_velocity = 0.1;
jump_gravity = -0.005;

// To minimize errors, all animation data blocks use flat arrays for transforms and matrices
bone_transforms = vbm_transform_identity_array_1d(VBM_BONECAPACITY);	// Transforms are sampled from animation
bone_particles = vbm_boneparticle_array_1d(VBM_BONECAPACITY);	// Particles represent swing bone transformations
bone_matrices = vbm_mat4_identity_array_1d(VBM_BONECAPACITY);	// Model-Space Matrices for each bone
bone_skinning = vbm_mat4_identity_array_1d(VBM_BONECAPACITY);	// Vertex-Space Matrices to send to shader	
// NOTE: If the submitted skinning array is larger than the matrix array size in the shader
//		 the game will eventually crash silently with a memory access violation error. (-1073741819, or -1073740940)
//		 Memory corruption can be detected beforehand with `Debug Overlay` > `Debug` > `Memory`.
//		 where the "Allocated memory" value will show some extraneous number. (Normal value is around ~16 MB).

animation_props = {};	// Updated with non-bone properties

// *Playback Controls ----------------------------------
playback_frame = 0;
playback_speed = 1;

// *Shader Uniforms
u_animation_bonematrices = shader_get_uniform(shd_tutorial4_animation, "u_bonematrices");	// For skinning matrices
u_animation_boneselect = shader_get_uniform(shd_tutorial4_animation, "u_boneselect");	// For weight visual

event_perform(ev_step, 0); // Force Step Update before first draw call
