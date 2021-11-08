/// @desc

// Inherit the parent event
event_inherited();

function UpdatePose()
{
	var _vbx = vbx;
	// Generate relative bone matrices for position in animation
	EvaluateAnimationTracks(trackpos, interpolationtype, 0, trackdata, inpose);
	// Convert relative bone matrices to model-space matrices
	CalculateAnimationPose(
		_vbx.bone_parentindices,	// index of bone's parent
		_vbx.bone_localmatricies,	// matrix of bone relative to parent
		_vbx.bone_inversematricies,	// matrix of bone relative to model origin
		inpose,	// relative transforms
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
	UpdatePose();
}

function OP_SetInterpolation(value, btn)
{
	interpolationtype = value;
	UpdatePose();
}
