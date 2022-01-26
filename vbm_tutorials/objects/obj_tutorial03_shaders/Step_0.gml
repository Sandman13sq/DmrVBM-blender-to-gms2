/// @desc Move camera + Toggle Shader

var _spd = 0.2;

// Rotate Model
if ( keyboard_check(vk_shift) )
{
	if ( keyboard_check(vk_right) ) {zrot += 1;}
	if ( keyboard_check(vk_left) ) {zrot -= 1;}
	if ( keyboard_check(vk_up) ) {cameraposition[2] += _spd;}
	if ( keyboard_check(vk_down) ) {cameraposition[2] -= _spd;}
}
// Move model
else
{
	if ( keyboard_check(vk_right) ) {cameraposition[0] += _spd;}
	if ( keyboard_check(vk_left) ) {cameraposition[0] -= _spd;}
	if ( keyboard_check(vk_up) ) {cameraposition[1] += _spd;}
	if ( keyboard_check(vk_down) ) {cameraposition[1] -= _spd;}
}

// Update view matrix
matview = matrix_build_lookat(
	cameraposition[0], -cameraposition[1], cameraposition[2], 
	cameralookat[0], -cameralookat[1], cameralookat[2], 
	0, 0, 1);
mattran = matrix_build(x, y, 0, 0, 0, zrot, 1, 1, 1);

// Toggle shader mode
shadermode ^= keyboard_check_pressed(vk_space);
