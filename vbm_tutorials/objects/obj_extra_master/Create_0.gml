/// @desc 

// Camera ----------------------------------------------
viewposition = [0, 0, 10];	// Location to point the camera at
viewxrot = -10;	// Camera's vertical rotation
viewzrot = -10;	// Camera's horizontal rotation
viewdistance = 24;	// Distance from camera position

fieldofview = 50;	// Angle of vision
znear = 1;	// Clipping distance for close triangles
zfar = 200;	// Clipping distance for far triangles

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

// Model Controls
zrot = 0;	// Model rotation
lightpos = [8, 32, 48];	// Light position to pass to shader
lightmode = 1;

vbm_world = new VBMData();
vbm_world.Open("assets/world_lab.vbm");
