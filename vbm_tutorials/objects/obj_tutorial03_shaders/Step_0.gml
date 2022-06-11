/// @desc Move camera + Toggle Shader

// Toggle shader mode
shadermode ^= keyboard_check_pressed(vk_space);

#region Camera =============================================================

var _spd = 0.2;

// Middle mouse button is held or left mouse button + alt key is held
movingcamera = mouse_check_button(mb_middle) || (keyboard_check(vk_alt) && mouse_check_button(mb_left));

// Rotate Model
if ( keyboard_check(vk_shift) )
{
	if ( keyboard_check(vk_right) ) {zrot += 1;}
	if ( keyboard_check(vk_left) ) {zrot -= 1;}
	if ( keyboard_check(vk_up) ) {cameraxrot -= 1;}
	if ( keyboard_check(vk_down) ) {cameraxrot += 1;}
}
// Move model
else
{
	if ( keyboard_check(vk_right) ) {camerazrot += 1;}
	if ( keyboard_check(vk_left) ) {camerazrot -= 1;}
	if ( keyboard_check(vk_up) ) {cameradistance /= 1.01;}
	if ( keyboard_check(vk_down) ) {cameradistance *= 1.01;}
}

// Zoom with mouse wheel
if (mouse_wheel_up()) {cameradistance /= 1.1;}
if (mouse_wheel_down()) {cameradistance *= 1.1;}

// Set mouse anchors
if (movingcamera && (movingcamera != movingcameralast))	// In this frame, movingcamera JUST went active
{
	mouseanchor[0] = mouse_x;
	mouseanchor[1] = mouse_y;
	cameraxrotanchor = cameraxrot;
	camerazrotanchor = camerazrot;
}

// Move camera with mouse
if (movingcamera)
{
	camerazrot = camerazrotanchor - (mouse_x-mouseanchor[0]) * _spd;
	cameraxrot = cameraxrotanchor - (mouse_y-mouseanchor[1]) * _spd;
}

movingcameralast = movingcamera;

// Update view matrix
var fwrd = matrix_transform_vertex(
	matrix_build(0,0,0, cameraxrot,0,camerazrot, 1,1,1),	// Rotation matrix from zrot
	0,-1,0	// Direction to look in
	);

matview = matrix_build_lookat(
	cameraposition[0]-cameradistance*fwrd[0],
	cameraposition[1]-cameradistance*fwrd[1],
	cameraposition[2]-cameradistance*fwrd[2],
	cameraposition[0], cameraposition[1], cameraposition[2],
	0,0,1
	);

mattran = matrix_build(x, y, 0, 0, 0, zrot, 1, 1, 1);

#endregion
