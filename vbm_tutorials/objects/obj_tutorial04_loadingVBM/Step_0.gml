/// @desc Move camera + Toggle Shader

// Toggle mesh visibility
if (keyboard_check_pressed(vk_space))
{
	meshvisible ^= (1 << meshindex);
}

// Navigate meshes
if (keyboard_check_pressed(vk_add) || keyboard_check_pressed(187)) 
{meshindex = (meshindex+1) mod vbm_kindle.Count();}
if (keyboard_check_pressed(vk_subtract) || keyboard_check_pressed(189)) 
{meshindex = meshindex==0? vbm_kindle.Count()-1: meshindex-1;}

#region Camera =============================================================

var _spd = 0.2;

var matviewrot = matrix_build(0,0,0, viewxrot,0,viewzrot, 1,1,1);
viewforward = matrix_transform_vertex(matviewrot, 0,-1,0);
viewright = matrix_transform_vertex(matviewrot, -1,0,0);
viewup = matrix_transform_vertex(matviewrot, 0,0,1);

// Middle mouse button is held or left mouse button + alt key is held
movingcamera = mouse_check_button(mb_middle) || (keyboard_check(vk_alt) && mouse_check_button(mb_left));

// Rotate Model
if ( keyboard_check(vk_shift) )
{
	if ( keyboard_check(vk_right) ) {zrot += 1;}
	if ( keyboard_check(vk_left) ) {zrot -= 1;}
	if ( keyboard_check(vk_up) ) {viewxrot -= 1;}
	if ( keyboard_check(vk_down) ) {viewxrot += 1;}
}
// Move model
else
{
	if ( keyboard_check(vk_right) ) {viewzrot += 1;}
	if ( keyboard_check(vk_left) ) {viewzrot -= 1;}
	if ( keyboard_check(vk_up) ) {viewdistance /= 1.01;}
	if ( keyboard_check(vk_down) ) {viewdistance *= 1.01;}
}

// Zoom with mouse wheel
if (mouse_wheel_up()) {viewdistance /= 1.1;}
if (mouse_wheel_down()) {viewdistance *= 1.1;}

// Set mouse anchors
if (movingcamera && (movingcamera != movingcameralast))	// In this frame, movingcamera JUST went active
{
	mouseanchor[0] = window_mouse_get_x();
	mouseanchor[1] = window_mouse_get_y();
	viewxrotanchor = viewxrot;
	viewzrotanchor = viewzrot;
	viewpositionanchor[0] = viewposition[0];
	viewpositionanchor[1] = viewposition[1];
	viewpositionanchor[2] = viewposition[2];
}

// Move camera with mouse
if (movingcamera)
{
	// Pan
	if ( keyboard_check(vk_shift) )
	{
		_spd = viewdistance * 0.001;
		var _mx = (window_mouse_get_x()-mouseanchor[0]) * _spd;
		var _my = (window_mouse_get_y()-mouseanchor[1]) * _spd;
		viewposition[0] = viewpositionanchor[0] + viewright[0] * _mx + viewup[0] * _my;
		viewposition[1] = viewpositionanchor[1] + viewright[1] * _mx + viewup[1] * _my;
		viewposition[2] = viewpositionanchor[2] + viewright[2] * _mx + viewup[2] * _my;
	}
	// Rotation
	else
	{
		viewzrot = viewzrotanchor - (window_mouse_get_x()-mouseanchor[0]) * _spd;
		viewxrot = viewxrotanchor - (window_mouse_get_y()-mouseanchor[1]) * _spd;
	}
}

movingcameralast = movingcamera;

// Update view matrix
matview = matrix_build_lookat(
	viewposition[0]-viewdistance*viewforward[0],
	viewposition[1]-viewdistance*viewforward[1],
	viewposition[2]-viewdistance*viewforward[2],
	viewposition[0], viewposition[1], viewposition[2],
	0,0,1
	);

mattran = matrix_build(x, y, 0, 0, 0, zrot, 1, 1, 1);

#endregion
