/// @desc 

var _spd = 0.1;

// Move model
if ( keyboard_check(vk_right) ) {cameraposition[0] += _spd;}
if ( keyboard_check(vk_left) ) {cameraposition[0] -= _spd;}
if ( keyboard_check(vk_up) ) {cameraposition[1] += _spd;}
if ( keyboard_check(vk_down) ) {cameraposition[1] -= _spd;}

// Update view matrix
matview = matrix_build_lookat(
	cameraposition[0], cameraposition[1], cameraposition[2], 0, 0, 0, 0, 0, 1);
