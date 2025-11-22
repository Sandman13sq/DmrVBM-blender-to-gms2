/// @desc

matview = matrix_build_lookat(
	r*w/2+1,-5,10, 
	r*w/2,0,0.0, 
	0,0,1
);

matproj = matrix_build_projection_perspective_fov(
	50,
	-window_get_width()/window_get_height(),
	0.1, 
	100
);
