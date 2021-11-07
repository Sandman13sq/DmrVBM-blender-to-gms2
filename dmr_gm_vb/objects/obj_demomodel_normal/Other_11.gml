/// @desc

// Inherit the parent event
event_inherited();

layout.Label("Single VB");

var c = layout.Column();
c.Real().Label("Alpha").DefineControl(self, "alpha").SetBounds(0, 1, 0.1);
c.Real().Label("Emission").DefineControl(self, "emission").SetBounds(0, 1, 0.1);
c.Real().Label("Shine").DefineControl(self, "shine").SetBounds(0, 1, 0.1);
c.Real().Label("SSS").DefineControl(self, "sss").SetBounds(0, 1, 0.1);

c.Bool().Label("Wireframe").DefineControl(self, "wireframe");

c.Enum().Label("Cullmode").DefineControl(self, "cullmode").DefineListItems([
	[cull_noculling, "No Culling", "Draw all triangles"],
	[cull_clockwise, "Cull Clockwise", "Skip triangles facing away from screen"],
	[cull_counterclockwise, "Cull Counter", "Skip triangles facing towards the screen"],
	]);
