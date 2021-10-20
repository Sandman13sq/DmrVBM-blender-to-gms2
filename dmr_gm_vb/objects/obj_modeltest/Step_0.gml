/// @desc

if window_get_width() != camerawidth
|| window_get_height() != cameraheight
{
	camerawidth = window_get_width();
	cameraheight = window_get_height();
	matproj = matrix_build_projection_perspective_fov(50, camerawidth/cameraheight, znear, zfar);
	
	surface_resize(application_surface, camerawidth, cameraheight);
	
	event_user(1);
}

vbmode ^= keyboard_check_pressed(ord("M"));
isplaying ^= keyboard_check_pressed(vk_space);

keymode ^= keyboard_check_pressed(ord("K"));
wireframe ^= keyboard_check_pressed(ord("L"));

if keyboard_check_pressed(vk_space)
{
	layout_model.FindElement("toggleplayback").Toggle();
}

// Controls
layout_model.Update();

var levplayback = 0;
if isplaying {levplayback = trackposspeed;}

if !layout_model.IsMouseOver() && !layout_model.active
{
	levplayback += trackposspeed*LevKeyPressed(VKey.greaterThan, VKey.lessThan);
	
	// Pose Matrices
	lev = LevKeyPressed(VKey.bracketClose, VKey.bracketOpen);
	if lev != 0
	{
		poseindex = Modulo(poseindex+lev, array_length(posemats));
		array_copy(matpose, 0, posemats[poseindex], 0, array_length(posemats[poseindex]));
	}

	mouselook.Update(mouse_check_button(mb_middle) || (mouse_check_button(mb_left) && keyboard_check(vk_alt)));
	var fwrd = mouselook.viewforward;
	var rght = mouselook.viewright;

	var lev = keyboard_check(ord("W")) - keyboard_check(ord("S"));
	lev += 4 * (mouse_wheel_up() - mouse_wheel_down());
	if lev != 0
	{
		camera[0] += fwrd[0] * lev;
		camera[1] += fwrd[1] * lev;
		camera[2] += fwrd[2] * lev;
	}

	var lev = keyboard_check(ord("D")) - keyboard_check(ord("A"));
	if lev != 0
	{
		camera[0] -= rght[0] * lev;
		camera[1] -= rght[1] * lev;
		//camera[2] += rght[2] * lev;
	}

	x += keyboard_check(vk_right) - keyboard_check(vk_left);
	y += keyboard_check(vk_up) - keyboard_check(vk_down);

	zrot += keyboard_check(ord("E")) - keyboard_check(ord("Q"));
}

// Animation Playback ================================================================

if levplayback != 0
{
	trackpos += levplayback;
	if trackpos < trackdata.positionrange[0] {trackpos = trackdata.positionrange[1];}
	if trackpos > trackdata.positionrange[1] {trackpos = trackdata.positionrange[0];}
	
	exectime[0] = get_timer();
	EvaluateAnimationTracks(lerp(trackdata.positionrange[0], trackdata.positionrange[1], trackpos), 
		2, keymode? vbx.bonenames: 0, trackdata, inpose);
	exectime[0] = get_timer()-exectime[0];
	
	exectime[1] = get_timer();
	CalculateAnimationPose(
		vbx.bone_parentindices, vbx.bone_localmatricies, vbx.bone_inversematricies, 
		inpose, matpose);
	exectime[1] = get_timer()-exectime[1];
}

// Rendering ==============================================================

drawmatrix = BuildDrawMatrix(
	1, 
	dm_emission, //*(string_pos("emi", vbx.vbnames[i]) != 0),
	dm_shine,
	dm_sss//(string_pos("skin", vbx.vbnames[i]) != 0),
	);

mattran = matrix_build(x,y,z, 0,0,zrot, 1,1,1);

camera[3] = (0-camera[0]);
camera[4] = (0-camera[1]);
camera[5] = (8-camera[2]);
var d = point_distance_3d(0,0,0, camera[3], camera[4], camera[5]);
camera[3] /= d;
camera[4] /= d;
camera[5] /= d;

var fwrd = mouselook.viewforward;
var rght = mouselook.viewright;
matview = matrix_build_lookat(
	camera[0], camera[1], camera[2], 
	camera[0]+fwrd[0], camera[1]+fwrd[1], camera[2]+fwrd[2], 
	0, 0, 1);
// Correct Yflip
matview = matrix_multiply(matrix_build(0,0,0,0,0,0,1,-1,1), matview);

