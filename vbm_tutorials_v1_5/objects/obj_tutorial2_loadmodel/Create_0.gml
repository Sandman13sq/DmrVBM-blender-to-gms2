/// @desc Initializing Variables

// *Camera ----------------------------------------------
view_position = [1, -3, 6]; // Camera position
cameralookat = [0, 0, 0];	// Camera eye target

fieldofview = 50;	// Angle of vision
znear = 1;	// Clipping distance for close triangles
zfar = 100;	// Clipping distance for far triangles
yflip = (os_type==os_windows);	// Yflip if on Windows (no need on Linux)

// Projection Matrix maps pixels to the screen
matproj = matrix_build_projection_perspective_fov(
	fieldofview,
	-window_get_width()/window_get_height(),	// Screen ratio
	znear,
	zfar
);

// View Matrix maps world to camera eye
matview = matrix_build_lookat(
	view_position[0], view_position[1], view_position[2],	// Camera location 
	cameralookat[0], cameralookat[1], cameralookat[2],	// Camera eye target
	0, 0, 1												// "Up" orientation of camera
);
mattran = matrix_build_identity(); // World/Model transform

// *Load Vertex Buffer ----------------------------------
model = VBM_Model_Create();	// Initialize model data
VBM_Open(model, "tutorial2_axis.vbm");	// Load from file (NOTE: Syntax changed from v1.4)

/*
	NOTE: To load files outside of the "datafiles" folder, enable the option in the project:
	Game Options > [Platform] > Disable Filesystem Sandbox
*/
