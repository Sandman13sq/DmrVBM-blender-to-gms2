/// @desc 

zrot += LevKeyHeld(ord("E"), ord("Q"))

var levplayback = isplaying * trackposspeed;

levplayback += trackposspeed*LevKeyPressed(VKey.greaterThan, VKey.lessThan);

if keyboard_check_pressed(vk_up)
	{levplayback = ArrayNextPos(trackdata.markerpositions, trackpos)-trackpos;}
if keyboard_check_pressed(vk_down)
	{levplayback = ArrayPrevPos(trackdata.markerpositions, trackpos)-trackpos;}

if levplayback != 0
{
	var _vbx = vbx_model;
	
	trackpos += levplayback;
	
	// Wrap position around range
	if trackpos < trackdata.positionrange[0] {trackpos = trackdata.positionrange[1];}
	if trackpos > trackdata.positionrange[1] {trackpos = trackdata.positionrange[0];}
	
	// Matrix from animation position
	exectime[0] = get_timer();
	EvaluateAnimationTracks(lerp(trackdata.positionrange[0], trackdata.positionrange[1], trackpos), 
		interpolationtype, keymode? _vbx.bonenames: 0, trackdata, inpose);
	exectime[0] = get_timer()-exectime[0];
	
	// Bone-space matrices to model-space matrices
	exectime[1] = get_timer();
	CalculateAnimationPose(
		_vbx.bone_parentindices, _vbx.bone_localmatricies, _vbx.bone_inversematricies, 
		inpose, matpose);
	exectime[1] = get_timer()-exectime[1];
}

mattran = matrix_build(x+10,y,z, 0,0,zrot, 1,1,1);

visible ^= keyboard_check_pressed(ord("H"));
