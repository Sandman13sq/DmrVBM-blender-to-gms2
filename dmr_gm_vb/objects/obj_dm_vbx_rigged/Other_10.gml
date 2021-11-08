/// @desc

// Inherit the parent event
event_inherited();

function UpdatePose(_inanimation)
{
	posemode = _inanimation;
	
	var _vbx = vbx;
	// Generate relative bone matrices for position in animation
	if !posemode
	{
		EvaluateAnimationTracks(trackpos, interpolationtype, 0, trackdata_poses, posetransform);
		isplaying = false;
	}
	else
	{
		EvaluateAnimationTracks(trackpos, interpolationtype, 0, trackdata_anim, posetransform);
		isplaying = true;
	}
	// Convert relative bone matrices to model-space matrices
	CalculateAnimationPose(
		_vbx.bone_parentindices,	// index of bone's parent
		_vbx.bone_localmatricies,	// matrix of bone relative to parent
		_vbx.bone_inversematricies,	// matrix of bone relative to model origin
		posetransform,	// relative transforms
		matpose	// flat array of matrices to write data to
		);	
}

function OP_MeshSelect(value, btn)
{
	meshselect = value;
	layout.FindElement("meshvisible").DefineControl(self, "meshvisible", value);
}

function OP_PoseMarkerJump(value, btn)
{
	trackpos = value;
	UpdatePose(false);
}

function OP_SetInterpolation(value, btn)
{
	interpolationtype = value;
	UpdatePose(posemode);
}
