/// @desc Initializing Variables

// *Camera ----------------------------------------------
view_position = [0, 0, 1];	// Location to point the camera at
viewhrot = 0;	// Camera's vertical rotation
viewvrot = 10;	// Camera's horizontal rotation
view_distance = 2.5;	// Distance from camera position

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
mouse_anchor = [window_mouse_get_x(), window_mouse_get_y()];
view_position_anchor = [0, 0, 0]
viewvrotanchor = viewhrot;	// Updated when middle mouse is pressed
viewhrotanchor = viewvrot;	// Updated when middle mouse is pressed
movingcamera = false;	// Middle mouse or left mouse + alt is held
movingcameralast = false;	// Used to check when middle has been pressed
cameramovemode = 0;	// 0 = Rotate, 1 = Pan
rotationspd = 0;

// *Load Vertex Buffers --------------------------------
model_native = VBM_Model_Create();	// Initialize model data
VBM_Open(model_native, "tutorial3_native.vbm");

model_normal = VBM_Model_Create();	// Initialize model data
VBM_Open(model_normal, "tutorial3_normal.vbm");

model_tangent = VBM_Model_Create();	// Initialize model data
VBM_Open(model_tangent, "tutorial3_tangent.vbm");

// *Model Controls
zrot = 0;	// Model rotation
shadermode = 0;	// 0 = simple, 1 = normal, 2 = tangent
lightpos = [2, -8, 8];	// Light position to pass to shader
eyepos = [0, 0, 0];	// View position to pass to shader. Calculated with matview

// *Shader Uniforms
u_normal_lightpos = shader_get_uniform(shd_tutorial3_normal, "u_lightpos"); // Get uniform handle for light position in shd_tutorial3_normal
u_normal_eyepos = shader_get_uniform(shd_tutorial3_normal, "u_eyepos"); // Get uniform handle for eye position in shd_tutorial3_normal

event_perform(ev_step, 0);	// Force an update
