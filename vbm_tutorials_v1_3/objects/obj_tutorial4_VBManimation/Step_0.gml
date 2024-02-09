/// @desc Move camera + Toggle Shader

// Play/Pause
if (keyboard_check_pressed(vk_space)) 
{
	animator.PauseToggle();
}

// Navigate Animations
if (keyboard_check_pressed(ord("Z"))) 
{
	playbackkeyindex = (playbackkeyindex+1) mod animator.AnimationCount();
	animator.Layer(0).SetAnimation(vbm_treat.AnimationGet(playbackkeyindex), 1);
	animator.Layer(0).SetBlend(10);
}

// Switch between matrices and track evaluation
if (keyboard_check_pressed(ord("X"))) 
{
	if (!vbm_treat.AnimationGet(0).isbakedlocal)
	{
		var _t = get_timer();
		animator.BakeAnimations();	// Pre-evaluate animations
		_t = get_timer()-_t;
		
		show_debug_message("Animations baked in " + string(_t/1000000) + " mcs");
	}
	else
	{
		animator.Layer(0).forcelocalposes ^= 1;
	}
}

//if ( keyboard_check_pressed(vk_anykey) ) {show_debug_message(keyboard_lastkey);}

// Navigate Meshes
if ( keyboard_check_pressed(188) )	// [<]
{
	meshselect = (meshselect == 0)? vbm_treat.meshcount-1: meshselect-1;
}

if ( keyboard_check_pressed(190) )	// [>]
{
	meshselect = (meshselect+1) mod vbm_treat.meshcount;
}

if ( keyboard_check_pressed(191) )	// [?]
{
	vbm_treat.VisibleToggleIndex(meshselect);
}

// Playback Speed
if (keyboard_check_pressed(vk_add) || keyboard_check_pressed(187))	// [+] || [=]
{
	playbackspeed = min(10, (playbackspeed > 1)? playbackspeed+1: playbackspeed*2);
	if ( abs(playbackspeed-1) <= 0.1 ) {playbackspeed = 1;}
}

if (keyboard_check_pressed(vk_subtract) || keyboard_check_pressed(189))	// [-] || [_]
{
	playbackspeed = max(0.01, (playbackspeed > 1)? playbackspeed-1: playbackspeed/2);
	if ( abs(playbackspeed-1) <= 0.1 ) {playbackspeed = 1;}
}

#region Camera =============================================================

var _spd = 0.2;

var matviewrot = matrix_build(0,0,0, viewvrot,0,viewhrot, 1,1,1);
viewforward = matrix_transform_vertex(matviewrot, 0,1,0);
viewright = matrix_transform_vertex(matviewrot, 1,0,0);
viewup = matrix_transform_vertex(matviewrot, 0,0,1);

// Rotate Model
if ( keyboard_check(vk_shift) )
{
	if ( keyboard_check(vk_right) ) {zrot += 1;}
	if ( keyboard_check(vk_left) ) {zrot -= 1;}
	if ( keyboard_check(vk_up) ) {viewvrot -= 1;}
	if ( keyboard_check(vk_down) ) {viewvrot += 1;}
}
// Move model
else
{
	if ( keyboard_check(vk_right) ) {viewhrot += 1;}
	if ( keyboard_check(vk_left) ) {viewhrot -= 1;}
	if ( keyboard_check(vk_up) ) {viewdistance /= 1.01;}
	if ( keyboard_check(vk_down) ) {viewdistance *= 1.01;}
}

// Zoom with mouse wheel
if (mouse_wheel_up()) {viewdistance /= 1.1;}
if (mouse_wheel_down()) {viewdistance *= 1.1;}

// Middle mouse button is held or left mouse button + alt key is held
movingcamera = mouse_check_button(mb_middle) || (keyboard_check(vk_alt) && mouse_check_button(mb_left));

// Set mouse anchors
if (movingcamera != 0 && (bool(movingcamera) != bool(movingcameralast)))	// In this frame, movingcamera JUST went active
{
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
if (movingcamera != 0)
{
	// Pan
	if ( cameramovemode == 1 )
	{
		_spd = viewdistance * 0.001;
		var _mx = (window_mouse_get_x()-mouseanchor[0]) * _spd;
		var _my = (window_mouse_get_y()-mouseanchor[1]) * _spd;
		viewposition[0] = viewpositionanchor[0] - viewright[0] * _mx + viewup[0] * _my;
		viewposition[1] = viewpositionanchor[1] - viewright[1] * _mx + viewup[1] * _my;
		viewposition[2] = viewpositionanchor[2] - viewright[2] * _mx + viewup[2] * _my;
	}
	// Rotation
	else
	{
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
	0,0,1
	);

matproj = matrix_build_projection_perspective_fov(
	fieldofview, 
	-window_get_width()/window_get_height(),	// Aspect is negated to fix y-coordinate
	znear, 
	zfar
	);

#endregion

mattran = matrix_build(x, y, 0, 0, 0, zrot, 1, 1, 1);

// Update Animator
animator.Update(playbackspeed);
