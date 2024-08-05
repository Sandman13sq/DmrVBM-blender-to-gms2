/// @desc Move camera + Toggle Shader

// Animation Controls ----------------------------------------

mesh_flash = max(0.0, mesh_flash - 0.05);

// Navigate Meshes
if ( keyboard_check_pressed(188) ) {	// "<"
	mesh_select = (mesh_select == 0)? VBM_Model_GetMeshCount(model)-1: (mesh_select-1);
	mesh_flash = 1.0;
}
if ( keyboard_check_pressed(190) ) {	// ">"
	mesh_select = (mesh_select+1) mod VBM_Model_GetMeshCount(model);
	mesh_flash = 1.0;
}
if ( keyboard_check_pressed(191) ) {	// "?"
	mesh_hide_bits ^= (1<<mesh_select);
}

// Navigate bones
if ( keyboard_check_pressed(0xDB) ) {	// "["
	bone_select = (bone_select == 0)? VBM_Model_GetBoneCount(model)-1: (bone_select-1);
}
if ( keyboard_check_pressed(0xDD) ) {	// "]"
	bone_select = (bone_select+1) mod VBM_Model_GetBoneCount(model);
}

// Navigate animation
if ( keyboard_check_pressed(0xBD) ) {	// "-"
	playback_index = (playback_index == 0)? VBM_Animator_GetAnimationCount(animator)-1: (playback_index-1);
	VBM_Animator_PlayAnimationIndex(animator, 0, playback_index);
	VBM_Animator_Update(animator, 0.0);
	VBM_Animator_SwingReset(animator);
}
if ( keyboard_check_pressed(0xBB) ) {	// "+"
	playback_index = (playback_index+1) mod VBM_Animator_GetAnimationCount(animator);
	VBM_Animator_PlayAnimationIndex(animator, 0, playback_index);
	VBM_Animator_Update(animator, 0.0);
	VBM_Animator_SwingReset(animator);
}

#region Camera =============================================================

var _spd = 0.2;

var matviewrot = matrix_build(0,0,0, viewvrot,0,viewhrot, 1,1,1);
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
	if ( keyboard_check(vk_up) )	{viewdistance /= 1.01; rotationspd = 0.0;}
	if ( keyboard_check(vk_down) )	{viewdistance *= 1.01; rotationspd = 0.0;}
}

// Zoom with mouse wheel
if (mouse_wheel_up()) {viewdistance /= 1.1;}
if (mouse_wheel_down()) {viewdistance *= 1.1;}

// Middle mouse button is held or left mouse button + alt key is held
movingcamera = mouse_check_button(mb_middle) || (keyboard_check(vk_alt) && mouse_check_button(mb_left));

// Set mouse anchors
if (movingcamera != 0 && (bool(movingcamera) != bool(movingcameralast))) {	// In this frame, movingcamera JUST went active
	mouseanchor[0] = window_mouse_get_x();
	mouseanchor[1] = window_mouse_get_y();
	viewhrotanchor = viewhrot;
	viewvrotanchor = viewvrot;
	viewpositionanchor[0] = viewposition[0];
	viewpositionanchor[1] = viewposition[1];
	viewpositionanchor[2] = viewposition[2];
	
	cameramovemode = keyboard_check(vk_shift);
}

// Move camera with mouse
if (movingcamera != 0) {
	// Pan
	if ( cameramovemode == 1 ) {
		_spd = viewdistance * 0.001;
		var _mx = (window_mouse_get_x()-mouseanchor[0]) * _spd;
		var _my = (window_mouse_get_y()-mouseanchor[1]) * _spd;
		viewposition[0] = viewpositionanchor[0] - viewright[0] * _mx + viewup[0] * _my;
		viewposition[1] = viewpositionanchor[1] - viewright[1] * _mx + viewup[1] * _my;
		viewposition[2] = viewpositionanchor[2] - viewright[2] * _mx + viewup[2] * _my;
	}
	// Rotation
	else {
		viewhrot = viewhrotanchor + (window_mouse_get_x()-mouseanchor[0]) * _spd;
		viewvrot = viewvrotanchor + (window_mouse_get_y()-mouseanchor[1]) * _spd;
	}
}

movingcameralast = movingcamera;

// Update view matrix
eyepos = [
	viewposition[0]-viewdistance*viewforward[0],
	viewposition[1]-viewdistance*viewforward[1],
	viewposition[2]-viewdistance*viewforward[2]
	];
matview = matrix_build_lookat(
	eyepos[0], eyepos[1], eyepos[2],
	viewposition[0], viewposition[1], viewposition[2],
	viewup[0], viewup[1], viewup[2]
	);

matproj = matrix_build_projection_perspective_fov(
	-fieldofview, 
	window_get_width()/window_get_height(),	// May need to be negated on certain devices
	znear, 
	zfar
	);

#endregion

zrot = max(zrot mod 360, (360+zrot) mod 360);

// Model matrix
VBM_Animator_SetRootTransform(animator, x,y,0, 0, 0, zrot*pi/180.0, 1,1,1);
VBM_Animator_Update(animator, 1.0);
