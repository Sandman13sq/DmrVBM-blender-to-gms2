/// @desc 

// Camera controls =====================================================

middledown = mouse_check_button(mb_middle) || (keyboard_check(vk_alt) && mouse_check_button(mb_left));

// Zoom
var _wheelspeed = 1.2;
if (mouse_wheel_up()) {viewdistance /= _wheelspeed;}
if (mouse_wheel_down()) {viewdistance *= _wheelspeed;}

// Set anchors when middle mouse is pressed
if (middledown && middledown != middlelast)
{
	mouseanchor = [mouse_x, mouse_y];
	viewzrotanchor = viewzrot;
	viewxrotanchor = viewxrot;
	array_copy(viewlocationanchor, 0, viewlocation, 0, 3);
}

// While middle mouse is pressed
if (middledown)
{
	// Pan
	if (keyboard_check(vk_shift))
	{
		var _spd = viewdistance * 0.001;
		var _mx = (mouse_x-mouseanchor[0]) * _spd;
		var _my = (mouse_y-mouseanchor[1]) * _spd;
		viewlocation[0] = viewlocationanchor[0] + viewright[0] * _mx + viewup[0] * _my;
		viewlocation[1] = viewlocationanchor[1] + viewright[1] * _mx + viewup[1] * _my;
		viewlocation[2] = viewlocationanchor[2] + viewright[2] * _mx + viewup[2] * _my;
	}
	// Rotate
	else
	{
		var _spd = 0.5;
		viewzrot = viewzrotanchor + (mouse_x-mouseanchor[0]) * _spd;
		viewxrot = viewxrotanchor + (mouse_y-mouseanchor[1]) * _spd;
	}
}

middlelast = middledown;

// Reset Camera
if (keyboard_check_pressed(vk_numpad0) || keyboard_check_pressed(ord("C")))
{
	viewlocation = [0,0,10];
	viewforward = [0,-1,0];
	viewright = [1,0,0];
	viewup = [0,0,1];
	viewdistance = 24;
	viewzrot = 0;
	viewxrot = 10;
}

// Pose controls
if (keyboard_check_pressed(ord("M")))
{
	mode = (mode+1) mod 3;
}

var lev = keyboard_check_pressed(vk_right) - keyboard_check_pressed(vk_left);

if (lev != 0)
{
	poseindex += lev;
	if (poseindex < 0) {poseindex = trk_poses.MarkerCount()-1;}
	else if (poseindex >= trk_poses.MarkerCount()) {poseindex = 0;}
	
	matpose = trk_poses.GetFrameMatricesMarker(poseindex);
	
	playbackactive = false;
}

if (keyboard_check_pressed(ord("P")))
{
	matpose = Mat4ArrayFlat(VBM_MATPOSEMAX);
}

//viewzrot += 0.5;

// Playback
playbackactive ^= keyboard_check_pressed(vk_space);

if (playbackactive)
{
	playbackposition = (playbackposition+trk_gun.CalculateTimeStep(60)) mod 1;
	
	localpose = Mat4Array(VBM_MATPOSEMAX);
	matpose = Mat4ArrayFlat(VBM_MATPOSEMAX);
	
	EvaluateAnimationTracks(
		trk_gun,
		playbackposition,
		TRK_Intrpl.linear,
		vbm_curly_exportlist.BoneNames(),
		localpose
		);
	
	CalculateAnimationPose(
		vbm_curly_exportlist.BoneParentIndices(),
		vbm_curly_exportlist.BoneLocalMatrices(),
		vbm_curly_exportlist.BoneInverseMatrices(),
		localpose,
		matpose
		);
	
	CalculateAnimationPose(
		vbm_curly_complete.BoneParentIndices(),
		vbm_curly_complete.BoneLocalMatrices(),
		vbm_curly_complete.BoneInverseMatrices(),
		Mat4ArrayPartition(trk_gun.GetFrameMatricesPos(playbackposition)),
		matpose2
		);
}

mattran = Mat4Translate(x, y, 0);

