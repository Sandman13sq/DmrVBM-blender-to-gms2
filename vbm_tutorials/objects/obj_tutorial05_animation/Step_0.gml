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

// Switch between matrices and track evaluation
if (keyboard_check_pressed(vk_space)) {playbackmode ^= 1;}

// Progress Playback
playbackposition = (playbackposition+playbackspeed) mod 1;

	// Use pre-evaluated matrices
	if (playbackmode == 0)
	{
		// Use matrices for given frame
		matpose = trk.framematrices[playbackposition*trk.framecount];
	}
	// Evaluate matrices on the fly
	else
	{
		localpose = Mat4Array(VBM_MATPOSEMAX);
		matpose = Mat4ArrayFlat(VBM_MATPOSEMAX);
	
		EvaluateAnimationTracks(
			trk,				// TRK data
			playbackposition,	// Position in animation ([0-1] range)
			TRK_Intrpl.linear,	// Type of interpolation for blending transforms
			vbm_curly.bonenames,	// Keys for mapping tracks to indices. 0 for index only
			localpose			// 2D Array of matrices to write local transforms to
			);
	
		CalculateAnimationPose(
			vbm_curly.bone_parentindices,	// Indices of parent bones for each bone
			vbm_curly.bone_localmatricies,	// Bind pose local matrices for each bone
			vbm_curly.bone_inversematricies,	// Inverse model matrices for each bone
			localpose,	// 2D Array of local transform matrices
			matpose		// 1D Flat Array of object space transform matrices to give to shader
			);
	}
