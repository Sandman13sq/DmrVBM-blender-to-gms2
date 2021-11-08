/// @desc

// Inherit the parent event
event_inherited();

layout.Label("Simple VB");

layout.Bool("Use GM Default Shader").DefineControl(self, "use_gm_default_shader");

var c = layout.Column();
c.Real().Label("Alpha").DefineControl(self, "alpha").SetBounds(0, 1, 0.1);

c.Bool().Label("Wireframe").DefineControl(self, "wireframe");

c.Enum().Label("Cullmode").DefineControl(self, "cullmode").DefineListItems([
	[cull_noculling, "No Culling", "Draw all triangles"],
	[cull_clockwise, "Cull Clockwise", "Skip triangles facing away from screen"],
	[cull_counterclockwise, "Cull Counter", "Skip triangles facing towards the screen"],
	]);

var d = layout.Dropdown().Label("Color Uniforms");
d.active = true;
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


