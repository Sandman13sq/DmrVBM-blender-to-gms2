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
VBM_OpenVBM("tutorial4_model.vbm", model);	// Animation comes packed into file

// *Model Controls -------------------------------------
zrot = 0;
lightpos = [4, -8, 4];	// Position of light for shader calculations
mesh_select = 0;	// Index of actively selected mesh
mesh_flash = 0.0;	// Step for flashing newly selected meshes
mesh_hide_bits = 0;	// Bitmask where active bits represent hidden meshes
bone_select = 0;	// Index of bone to show weights for
bone_matrices = VBM_CreateMatrixArrayFlat(VBM_BONECAPACITY);	// Flat array of matrices to send to shader

// *Playback Controls ----------------------------------
playback_frame = 0;
playback_speed = 1;

// *Shader Uniforms
u_rigged_boneselect = shader_get_uniform(shd_tutorial4_rigged, "u_boneselect"); // Get uniform handle for bone selection in shd_tutorial4_rigged
u_rigged_meshflash = shader_get_uniform(shd_tutorial4_rigged, "u_meshflash"); // Get uniform handle for mesh selection in shd_tutorial4_rigged
u_rigged_transforms = shader_get_uniform(shd_tutorial4_rigged, "u_bonematrices"); // Get uniform handle for transform array in shd_tutorial4_rigged

event_perform(ev_step, 0);	// Force an update
