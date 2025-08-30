/// @desc Camera controls

var _spd = 0.1;

// Move camera
if ( keyboard_check(vk_right) ) {view_position[0] += _spd;}
if ( keyboard_check(vk_left) ) {view_position[0] -= _spd;}
if ( keyboard_check(vk_up) ) {view_position[1] += _spd;}
if ( keyboard_check(vk_down) ) {view_position[1] -= _spd;}

// Toggle yflip
yflip ^= keyboard_check_pressed(vk_space);

// Update view matrix
matview = matrix_build_lookat(view_position[0], view_position[1], view_position[2], 0, 0, 0, 0, 0, 1);

var projection_yflip = (yflip)? -1: 1;
matproj = matrix_build_projection_perspective_fov(
	fieldofview,
	window_get_width()/window_get_height() * projection_yflip,
	znear, 
	zfar
);
