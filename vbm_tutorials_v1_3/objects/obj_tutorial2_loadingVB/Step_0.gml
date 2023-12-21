/// @desc Camera controls

var _spd = 0.1;

// Move camera
if ( keyboard_check(vk_right) ) {viewposition[0] += _spd;}
if ( keyboard_check(vk_left) ) {viewposition[0] -= _spd;}
if ( keyboard_check(vk_up) ) {viewposition[1] += _spd;}
if ( keyboard_check(vk_down) ) {viewposition[1] -= _spd;}

// Update view matrix
matview = matrix_build_lookat(
	viewposition[0], viewposition[1], viewposition[2], 0, 0, 0, 0, 0, 1);

matproj = matrix_build_projection_perspective_fov(
	fieldofview, window_get_width()/window_get_height(), znear, zfar);
