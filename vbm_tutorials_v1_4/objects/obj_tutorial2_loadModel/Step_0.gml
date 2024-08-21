/// @desc Camera controls

var _spd = 0.1;

// Move camera
if ( keyboard_check(vk_right) ) {viewposition[0] += _spd;}
if ( keyboard_check(vk_left) ) {viewposition[0] -= _spd;}
if ( keyboard_check(vk_up) ) {viewposition[1] += _spd;}
if ( keyboard_check(vk_down) ) {viewposition[1] -= _spd;}

// Toggle yflip
yflip ^= keyboard_check_pressed(vk_space);

// Update view matrix
matview = matrix_build_lookat(
	viewposition[0], viewposition[1], viewposition[2], 0, 0, 0, 0, 0, 1);

var projection_yflip = (yflip)? -1: 1;
matproj = matrix_build_projection_perspective_fov(
	fieldofview * projection_yflip, 
	window_get_width()/window_get_height() * projection_yflip,
	znear, 
	zfar
);
