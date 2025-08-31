/// @desc Scene controls

mproj = matrix_build_projection_perspective_fov(
	50.0,
	-window_get_width() / window_get_height(),
	0.1,
	100
);

mview = matrix_build_lookat(
	1, -2, 1, 
	0,0,1, 
	0,0,1
);

mtran = matrix_build(
	model_location[0], model_location[1], model_location[2], 
	model_euler[0], model_euler[1], model_euler[2], 
	1,1,1
);


