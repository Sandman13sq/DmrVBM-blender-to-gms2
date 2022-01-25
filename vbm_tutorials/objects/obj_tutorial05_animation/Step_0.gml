/// @desc Move camera + Toggle Shader

var _spd = 0.2;

// Rotate Model
if ( keyboard_check(vk_shift) )
{
	if ( keyboard_check(vk_right) ) {zrot += 1;}
	if ( keyboard_check(vk_left) ) {zrot -= 1;}
	if ( keyboard_check(vk_up) ) {cameraposition[2] += _spd;}
	if ( keyboard_check(vk_down) ) {cameraposition[2] -= _spd;}
}
// Move model
else
{
	if ( keyboard_check(vk_right) ) {cameraposition[0] += _spd;}
	if ( keyboard_check(vk_left) ) {cameraposition[0] -= _spd;}
	if ( keyboard_check(vk_up) ) {cameraposition[1] += _spd;}
	if ( keyboard_check(vk_down) ) {cameraposition[1] -= _spd;}
}

// Update view matrix
matview = matrix_build_lookat(
	cameraposition[0], -cameraposition[1], cameraposition[2], 
	cameralookat[0], -cameralookat[1], cameralookat[2], 
	0, 0, 1);
mattran = matrix_build(x, y, 0, 0, 0, zrot, 1, 1, 1);

// Switch pose mode
if (keyboard_check_pressed(vk_space))
{
	playbackmode ^= 1;
}

// Playback
playbackposition = (playbackposition+playbackspeed) mod 1;

if (playbackmode == 0)
{
	matpose = trk.framematrices[playbackposition*trk.framecount];
}
else
{
	localpose = Mat4Array(DMRVBM_MATPOSEMAX);
	
	EvaluateAnimationTracks(
		playbackposition,
		TRK_Intrpl.linear,
		0,
		trk,
		localpose
		);
	
	CalculateAnimationPose(
		vbm_curly.bone_parentindices,
		vbm_curly.bone_localmatricies,
		vbm_curly.bone_inversematricies,
		localpose,
		matpose
		);
}



