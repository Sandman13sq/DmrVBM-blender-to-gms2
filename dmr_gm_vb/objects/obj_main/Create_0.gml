/// @desc

show_debug_overlay(1);
event_user(0);

layout = new Layout();
layout.SetPosXY(16, 16, 256, 256).SetUIScale(1.5);
layout.Label("Editor");

var r = layout.Column();
r.Button().Label("OPEN");
r.Button().Label("SANS");
r.Real().Label("LV");

var c = layout.Row();
c.Button().Label("x");
c.Button().Label("y");
c.Button().Label("z");

var d = layout.Dropdown().Label("OPTIONS");
d.Button().Label("Continue").Operator(Op_Restart);
d.Button().Label("Quit").Operator(Op_End);
d.Bool().Label("Simplify");

//display_set_gui_size(room_width, room_height);
display_set_gui_maximize(1, 1);
draw_set_font(fnt_default);

RENDERING = new Rendering();
RENDERING.DefineUniform("u_drawmatrix");
RENDERING.DefineUniform("u_camera");
RENDERING.DefineUniform("u_matpose");

