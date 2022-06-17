/// @desc Matrices

var matviewrot = matrix_build(0,0,0, -viewxrot,0,-viewzrot, 1,1,1);
viewforward = matrix_transform_vertex(matviewrot, 0,-1,0);
viewright = matrix_transform_vertex(matviewrot, -1,0,0);
viewup = matrix_transform_vertex(matviewrot, 0,0,1);

matproj = matrix_build_projection_perspective_fov(
	fieldofview, window_get_width() / window_get_height(), znear, zfar);

matview = matrix_build_lookat(
	viewlocation[0]-viewdistance*viewforward[0],
	viewlocation[1]-viewdistance*viewforward[1],
	viewlocation[2]-viewdistance*viewforward[2],
	viewlocation[0],
	viewlocation[1],
	viewlocation[2],
	viewup[0],
	viewup[1],
	viewup[2]
	);

