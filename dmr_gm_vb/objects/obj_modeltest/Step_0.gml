/// @desc

vbmode ^= keyboard_check_pressed(ord("M"));
isplaying ^= keyboard_check_pressed(vk_space);
keymode ^= keyboard_check_pressed(ord("K"));
wireframe ^= keyboard_check_pressed(ord("L"));

// Animation Playback
var lev = 0;
if isplaying {lev = trackposspeed;}
else {lev = trackposspeed*LevKeyPressed(VKey.greaterThan, VKey.lessThan);}

if lev != 0
{
	trackpos += lev;
	if trackpos < trackdata.positionrange[0] {trackpos = trackdata.positionrange[1];}
	if trackpos > trackdata.positionrange[1] {trackpos = trackdata.positionrange[0];}
	
	EvaluateAnimationTracks(lerp(trackdata.positionrange[0], trackdata.positionrange[1], trackpos), 
		1, keymode? vbx.bonenames: 0, trackdata, inpose);
	CalculateAnimationPose(
		vbx.bone_parentindices, vbx.bone_localmatricies, vbx.bone_inversematricies, 
		inpose, matpose);
}

// Pose Matrices
lev = LevKeyPressed(VKey.bracketClose, VKey.bracketOpen);
if lev != 0
{
	poseindex = Modulo(poseindex+lev, array_length(posemats));
	matpose = posemats[poseindex];
}

x += keyboard_check(vk_right) - keyboard_check(vk_left);
y += keyboard_check(vk_up) - keyboard_check(vk_down);

zrot += keyboard_check(ord("E")) - keyboard_check(ord("Q"));

mattran = matrix_build(x,y,z, 0,0,zrot, 1,1,1);

camera[3] = (0-camera[0]);
camera[4] = (0-camera[1]);
camera[5] = (8-camera[2]);
var d = point_distance_3d(0,0,0, camera[3], camera[4], camera[5]);
camera[3] /= d;
camera[4] /= d;
camera[5] /= d;

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

matview = matrix_build_lookat(
	camera[0], camera[1], camera[2], 
	camera[0]+fwrd[0], camera[1]+fwrd[1], camera[2]+fwrd[2], 
	0, 0, 1);
// Correct Yflip
matview = matrix_multiply(matrix_build(0,0,0,0,0,0,1,-1,1), matview);
