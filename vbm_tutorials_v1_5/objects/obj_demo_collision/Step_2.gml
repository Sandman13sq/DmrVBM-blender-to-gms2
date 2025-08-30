/// @desc Update Camera

matproj = matrix_build_projection_perspective_fov(
	50,
	-window_get_width()/window_get_height(),
	0.1,
	1000.0
);

var _mlook = matrix_build(0,0,0, view_euler[0], view_euler[1], view_euler[2], 1,1,1);
var _eyedir = matrix_transform_vertex(_mlook, 0,1,0);
matview = matrix_build_lookat(
	view_location_offset[0] + view_location[0] - _eyedir[0] * view_distance, 
	view_location_offset[1] + view_location[1] - _eyedir[1] * view_distance, 
	view_location_offset[2] + view_location[2] - _eyedir[2] * view_distance,
	view_location_offset[0] + view_location[0], 
	view_location_offset[1] + view_location[1], 
	view_location_offset[2] + view_location[2],
	0,0,1
);


