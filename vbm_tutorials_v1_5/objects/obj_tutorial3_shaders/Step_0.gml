/// @desc Move camera + Toggle Shader

// Toggle shader mode
if ( keyboard_check_pressed(vk_space) ) {
	shadermode = (shadermode+1) % 3;	
}

#region Camera =============================================================

var _spd = 0.2;

var matviewrot = matrix_build(0,0,0, 0,0,viewhrot, 1,1,1);
if ( keyboard_check(ord("M")) ) {
	vbm_mat4_compose(matviewrot, 0, 
		0,0,0,
		cos(viewhrot/2), 0, 0, sin(viewhrot/2),
		1,1,1
	);
}

viewforward = matrix_transform_vertex(matviewrot, 0,1,0);
viewright = matrix_transform_vertex(matviewrot, 1,0,0);
viewup = matrix_transform_vertex(matviewrot, 0,0,1);

// Rotate Model
if ( !keyboard_check(vk_shift) ) {
	if ( keyboard_check(vk_right) )	{zrot += 2; rotationspd = 0.0;}
	if ( keyboard_check(vk_left) )	{zrot -= 2; rotationspd = 0.0;}
	if ( keyboard_check(vk_up) )	{viewvrot -= 1; rotationspd = 0.0;}
	if ( keyboard_check(vk_down) )	{viewvrot += 1; rotationspd = 0.0;}
}
// Move model
else {
	if ( keyboard_check(vk_right) )	{viewhrot += 1; rotationspd = 0.0;}
	if ( keyboard_check(vk_left) )	{viewhrot -= 1; rotationspd = 0.0;}
	if ( keyboard_check(vk_up) )	{view_distance /= 1.01; rotationspd = 0.0;}
	if ( keyboard_check(vk_down) )	{view_distance *= 1.01; rotationspd = 0.0;}
}

// Zoom with mouse wheel
if (mouse_wheel_up()) {view_distance /= 1.1;}
if (mouse_wheel_down()) {view_distance *= 1.1;}

// Middle mouse button is held or left mouse button + alt key is held
movingcamera = mouse_check_button(mb_middle) || (keyboard_check(vk_alt) && mouse_check_button(mb_left));

// Set mouse anchors
if (movingcamera != 0 && (bool(movingcamera) != bool(movingcameralast))) {	// In this frame, movingcamera JUST went active
	mouse_anchor[0] = window_mouse_get_x();
	mouse_anchor[1] = window_mouse_get_y();
	viewhrotanchor = viewhrot;
	viewvrotanchor = viewvrot;
	view_position_anchor[0] = view_position[0];
	view_position_anchor[1] = view_position[1];
	view_position_anchor[2] = view_position[2];
	
	cameramovemode = keyboard_check(vk_shift);
}

// Move camera with mouse
if (movingcamera != 0) {
	// Pan
	if ( cameramovemode == 1 ) {
		_spd = view_distance * 0.001;
		var _mx = (window_mouse_get_x()-mouse_anchor[0]) * _spd;
		var _my = (window_mouse_get_y()-mouse_anchor[1]) * _spd;
		view_position[0] = view_position_anchor[0] - viewright[0] * _mx + viewup[0] * _my;
		view_position[1] = view_position_anchor[1] - viewright[1] * _mx + viewup[1] * _my;
		view_position[2] = view_position_anchor[2] - viewright[2] * _mx + viewup[2] * _my;
	}
	// Rotation
	else {
		viewhrot = viewhrotanchor + (window_mouse_get_x()-mouse_anchor[0]) * _spd;
		viewvrot = viewvrotanchor + (window_mouse_get_y()-mouse_anchor[1]) * _spd;
	}
}

movingcameralast = movingcamera;

// Update view matrix
eyepos = [
	view_position[0]-view_distance*viewforward[0],
	view_position[1]-view_distance*viewforward[1],
	view_position[2]-view_distance*viewforward[2]
	];
matview = matrix_build_lookat(
	eyepos[0], eyepos[1], eyepos[2],
	view_position[0], view_position[1], view_position[2],
	0,0,1
	);

var projection_yflip = (os_type==os_windows)? -1: 1;
matproj = matrix_build_projection_perspective_fov(
	fieldofview,
	window_get_width()/window_get_height() * projection_yflip,
	znear, 
	zfar
);

#endregion

// Slowly rotate model when no input
if (movingcamera) {
	rotationspd = 0;
}
else {
	rotationspd = lerp(rotationspd, 0.4, 0.008);
}
zrot += rotationspd;
zrot = max(zrot mod 360, (360+zrot) mod 360);

// Model matrix
mattran = matrix_build(x, y, 0, 0, 0, zrot, 1, 1, 1);
