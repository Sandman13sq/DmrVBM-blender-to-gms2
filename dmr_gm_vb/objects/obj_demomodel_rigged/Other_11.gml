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
for (var i = 0; i < trackdata.markercount; i++)
{
	l.DefineListItem(trackdata.markerpositions[i], trackdata.markernames[i]);
}

var e = layout.Enum("Interpolation")
	.Operator(OP_SetInterpolation)
	.DefineListItems([
		[AniTrack_Intrpl.constant, "Constant", "Floors keyframe position when evaluating pose"],
		[AniTrack_Intrpl.linear, "Linear", "Linearly keyframe position when evaluating pose"],
		[AniTrack_Intrpl.smooth, "Square", "Uses square of position difference when evaluating pose"]
		]);

var c = layout.Column();
c.Real().Label("Alpha").DefineControl(self, "alpha").SetBounds(0, 1, 0.1);
c.Real().Label("Emission").DefineControl(self, "emission").SetBounds(0, 1, 0.1);
c.Real().Label("Shine").DefineControl(self, "shine").SetBounds(0, 1, 0.1);
c.Real().Label("SSS").DefineControl(self, "sss").SetBounds(0, 1, 0.1);

c.Bool().Label("Wireframe").DefineControl(self, "wireframe");
c.Bool().Label("Use Textures").DefineControl(self, "usetextures");

c.Enum().Label("Cullmode").DefineControl(self, "cullmode").DefineListItems([
	[cull_noculling, "No Culling", "Draw all triangles"],
	[cull_clockwise, "Cull Clockwise", "Skip triangles facing away from screen"],
	[cull_counterclockwise, "Cull Counter", "Skip triangles facing towards the screen"],
	]);

var d = layout.Dropdown().Label("Color Uniforms");
var r;

d.Text("Blend Color");
r = d.Row();
r.Real().SetBounds(0, 1, 0.05).DefineControl(self, "colorblend", 0).draw_increments = false; 
r.Real().SetBounds(0, 1, 0.05).DefineControl(self, "colorblend", 1).draw_increments = false; 
r.Real().SetBounds(0, 1, 0.05).DefineControl(self, "colorblend", 2).draw_increments = false;
r.Real().SetBounds(0, 1, 0.05).DefineControl(self, "colorblend", 3).draw_increments = false;

d.Text("Fill Color");
r = d.Row();
r.Real().SetBounds(0, 1, 0.05).DefineControl(self, "colorfill", 0).draw_increments = false; 
r.Real().SetBounds(0, 1, 0.05).DefineControl(self, "colorfill", 1).draw_increments = false; 
r.Real().SetBounds(0, 1, 0.05).DefineControl(self, "colorfill", 2).draw_increments = false;
r.Real().SetBounds(0, 1, 0.05).DefineControl(self, "colorfill", 3).draw_increments = false;
