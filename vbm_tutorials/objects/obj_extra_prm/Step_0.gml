/// @desc 

event_inherited();

if (keyboard_check(vk_add) || keyboard_check(187)) {transitionblend = min(1.0, transitionblend+0.02);}
if (keyboard_check(vk_subtract) || keyboard_check(189)) {transitionblend = max(0.0, transitionblend-0.02);}

// Switch between matrices and track evaluation
if (keyboard_check_pressed(vk_space)) {playbackmode ^= 1;}

// Progress Playback
playbackposition = (playbackposition+trk_gun.CalculateTimeStep(game_get_speed(gamespeed_fps))) mod 1;

// Use pre-evaluated matrices
if (playbackmode == 0)
{
	// Use matrices for given frame
	matpose = trk_gun.GetFrameMatricesByPosition(playbackposition);
}
// Evaluate matrices on the fly
else
{
	localpose = Mat4Array(VBM_MATPOSEMAX);
	matpose = Mat4ArrayFlat(VBM_MATPOSEMAX);
	
	EvaluateAnimationTracks(
		trk_gun,				// TRK data
		playbackposition,	// Position in animation ([0-1] range)
		TRK_Intrpl.linear,	// Type of interpolation for blending transforms
		vbm_curly_prm.BoneNames(),	// Keys for mapping tracks to indices. 0 for index only
		localpose			// 2D Array of matrices to write local transforms to
		);
	
	CalculateAnimationPose(
		vbm_curly_prm.BoneParentIndices(),	// Indices of parent bones for each bone
		vbm_curly_prm.BoneLocalMatrices(),	// Bind pose local matrices for each bone
		vbm_curly_prm.BoneInverseMatrices(),	// Inverse model matrices for each bone
		localpose,	// 2D Array of local transform matrices
		matpose		// 1D Flat Array of object space transform matrices to give to shader
		);
		
}
