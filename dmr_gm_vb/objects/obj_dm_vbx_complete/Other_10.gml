/// @desc Methods + Operators

// Inherit the parent event
event_inherited();

function UpdateAnim()
{
	var _vbx = vbx;
	
	// Generate relative bone matrices for position in animation
	EvaluateAnimationTracks(trackpos, 
		interpolationtype,	// Method to blend keyframes with (constant, linear, square)
		_vbx.bonenames,		// Keys to use for track mapping
		trackdata_anim,		// Track data with transforms
		posetransform		// 2D Array to write matrix data to
		);
	
	// Convert relative bone matrices to model-space matrices
	CalculateAnimationPose(
		_vbx.bone_parentindices,	// index of bone's parent
		_vbx.bone_localmatricies,	// matrix of bone relative to parent
		_vbx.bone_inversematricies,	// matrix of bone relative to model origin
		posetransform,				// relative transforms (from animation or pose)
		matpose						// flat array of matrices to write data to
		);
}

function UpdatePose()
{
	var _vbx = vbx;
	var _pos = trackdata_poses.markerpositions[poseindex];
	
	// Generate relative bone matrices for position in animation
	EvaluateAnimationTracks(_pos, 
		AniTrack_Intrpl.constant,	// Method to blend keyframes with (constant, linear, square)
		_vbx.bonenames,		// Keys to use for track mapping
		trackdata_poses,	// Track data with transforms
		posetransform		// 2D Array to write matrix data to
		);
	
	// Convert relative bone matrices to model-space matrices
	CalculateAnimationPose(
		_vbx.bone_parentindices,	// index of bone's parent
		_vbx.bone_localmatricies,	// matrix of bone relative to parent
		_vbx.bone_inversematricies,	// matrix of bone relative to model origin
		posetransform,				// relative transforms (from animation or pose)
		matpose						// flat array of matrices to write data to
		);
}

function OP_BindPose(value, btn)
{
	isplaying = false;
	Mat4ArrayFlatClear(matpose, Mat4());
	demo.modelzrot = 0;
	
	if keyboard_check_direct(vk_alt)
	{
		Mat4ArrayFlatClear(matpose, Mat4Rotate(0, 0, 180));
		demo.modelzrot = 180;
	}
}

function OP_MeshSelect(value, btn)
{
	meshselect = value;
	layout.FindElement("meshvisible").DefineControl(self, "meshvisible", value);
}

function OP_TogglePlayback(value, btn)
{
	posemode = 1;
	isplaying = value;
	UpdateAnim();
}

function OP_ChangeTrackPos(value, btn)
{
	posemode = 1;
	trackpos = value;
	UpdateAnim();
}

function OP_PoseMarkerJump(value, btn)
{
	poseindex = value;
	posemode = 0;
	isplaying = false;
	UpdatePose();
}

function OP_SetInterpolation(value, btn)
{
	interpolationtype = value;
	UpdateAnim();
}

function OP_ToggleAllVisibility(value, btn)
{
	var n = array_length(meshvisible);
	for (var i = 0; i < n; i++)
	{
		if meshvisible[i]
		{
			ArrayClear(meshvisible, 0);
			return;
		}
	}
	
	ArrayClear(meshvisible, 1);
}
