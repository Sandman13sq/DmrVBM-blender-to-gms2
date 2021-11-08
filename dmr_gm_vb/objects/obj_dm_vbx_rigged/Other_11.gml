/// @desc Layout

// Inherit the parent event
event_inherited();

layout.Label("Rigged VB");

// Mesh
var b = layout.Box("Meshes");
var l = b.List()
	.Operator(OP_MeshSelect)
	.DefineControl(self, "meshselect");
for (var i = 0; i < vbx.vbcount; i++)
{
	l.DefineListItem(i, vbx.vbnames[i], vbx.vbnames[i]);
}
b.Bool("Visible").SetIDName("meshvisible")
	.DefineControl(self, "meshvisible", meshselect);

// Pose
var l = layout.Dropdown("Poses").List().Operator(OP_PoseMarkerJump);
for (var i = 0; i < trackdata_poses.markercount; i++)
{
	l.DefineListItem(trackdata_poses.markerpositions[i], trackdata_poses.markernames[i]);
}

b.Bool("Play Animation").DefineControl(self, "isplaying");

var e = layout.Enum("Interpolation")
	.Operator(OP_SetInterpolation)
	.DefineListItems([
		[AniTrack_Intrpl.constant, "Constant", "Floors keyframe position when evaluating pose"],
		[AniTrack_Intrpl.linear, "Linear", "Linearly keyframe position when evaluating pose"],
		[AniTrack_Intrpl.smooth, "Square", "Uses square of position difference when evaluating pose"]
		]);

CommonLayout(true, true, false);
