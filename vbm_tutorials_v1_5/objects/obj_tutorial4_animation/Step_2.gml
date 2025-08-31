//// @desc Scene Controls

var _viewmatrot = matrix_build(0,0,0, view_euler[0],view_euler[1], view_euler[2], 1,1,1);
var _matviewinv = matrix_inverse(matview);
var _viewright = [_matviewinv[VBM_M00], _matviewinv[VBM_M10], _matviewinv[VBM_M20]];
var _viewup = [_matviewinv[VBM_M01], _matviewinv[VBM_M11], _matviewinv[VBM_M21]];
var _spd = 0.3;

// Rotate
var _rotspd = 5;
var _wheelspd = 1.01;
if ( !keyboard_check(vk_shift) ) {
	if ( keyboard_check(vk_right) )	{model_euler[2] += _rotspd;}
	if ( keyboard_check(vk_left) )	{model_euler[2] -= _rotspd;}
	if ( keyboard_check(vk_up) )	{view_euler[0] += _rotspd/2;}
	if ( keyboard_check(vk_down) )	{view_euler[0] -= _rotspd/2;}
}
// Move
else {
	if ( keyboard_check(vk_right) )	{view_euler[2] -= _rotspd;}
	if ( keyboard_check(vk_left) )	{view_euler[2] += _rotspd;}
	if ( keyboard_check(vk_up) )	{view_distance /= _wheelspd;}
	if ( keyboard_check(vk_down) )	{view_distance *= _wheelspd;}
}

// Hop
if ( keyboard_check_pressed(vk_space) && (model_location[2] <= 0.01) ) {
	model_velocity[2] += jump_velocity;
}

// Zoom with mouse wheel
if (mouse_wheel_up()) {view_distance /= 1.1;}
if (mouse_wheel_down()) {view_distance *= 1.1;}

// Middle mouse button is held or left mouse button + alt key is held
moving_model = (
	mouse_check_button(mb_left) || 
	mouse_check_button(mb_middle) || 
	(keyboard_check(vk_alt) && mouse_check_button(mb_left))
);

// Set mouse anchors
if (moving_model != 0 && (bool(moving_model) != bool(moving_model_last))) {	// In this frame, movingcamera JUST went active
	mouse_anchor = [window_mouse_get_x(), window_mouse_get_y()];
	view_position_anchor = [model_location[0], model_location[1], model_location[2]];
	view_euler_anchor = [model_euler[0], model_euler[1], model_euler[2]];
	cameramovemode = keyboard_check(vk_shift);
}

// Move camera with mouse
if (moving_model != 0) {
	// Pan
	if ( cameramovemode == 1 ) {
		_spd = view_distance * 0.002;
		var _mx = (window_mouse_get_x()-mouse_anchor[0]) * _spd;
		var _my = (window_mouse_get_y()-mouse_anchor[1]) * _spd;
		
		model_location[0] = view_position_anchor[0] - _viewright[0] * _mx - _viewup[0] * _my;
		model_location[1] = view_position_anchor[1] - _viewright[1] * _mx - _viewup[1] * _my;
		model_location[2] = view_position_anchor[2] - _viewright[2] * _mx - _viewup[2] * _my;
		model_velocity[2] = 0.0;
	}
	// Rotation
	else {
		model_euler[2] = view_euler_anchor[2] - (window_mouse_get_x()-mouse_anchor[0]) * _spd;
		//model_euler[1] = viewvrotanchor + (window_mouse_get_y()-mouse_anchor[1]) * _spd;
	}
}

moving_model_last = moving_model;

// Model Gravity
if ( model_location[2] <= 0.0 && model_velocity[2] <= 0.0 ) {
	if ( model_velocity[2] <= -0.02 ) {
		model_velocity[2] *= -0.5;
		model_location[2] = 0.0;
	}
	else {
		model_location[2] = 0.0;
		model_velocity[2] = 0.0;
	}
}
else {
	model_velocity[2] += jump_gravity;	// Gravity
}

model_location[0] += model_velocity[0];
model_location[1] += model_velocity[1];
model_location[2] += model_velocity[2];

// Update Projection matrix
var projection_yflip = (os_type==os_windows)? -1: 1;
matproj = matrix_build_projection_perspective_fov(
	fieldofview, 
	window_get_width()/window_get_height() * projection_yflip,
	znear, 
	zfar
);

// Update View matrix
var _eyedir = matrix_transform_vertex(
	matrix_build(0,0,0, view_euler[0],view_euler[1], view_euler[2], 1,1,1), 0,1,0, 0.0
);
matview = matrix_build_lookat(
	view_position[0]-view_distance*_eyedir[0],	// Eye x
	view_position[1]-view_distance*_eyedir[1],	// Eye y
	view_position[2]-view_distance*_eyedir[2],	// Eye z
	view_position[0], view_position[1], view_position[2],	// Target xyz
	0,0,1											// Up vector
	);

// Update Model matrix
var _proprotation = animation_props[$ "rot"][0];
var _zrotoffset = lerp(0, 90, _proprotation);

mattran = matrix_build(
	model_location[0], model_location[1], model_location[2], 
	model_euler[0], model_euler[1], model_euler[2]+_zrotoffset,
	1, 1, 1
);
