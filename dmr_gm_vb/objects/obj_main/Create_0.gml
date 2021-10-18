/// @desc

show_debug_overlay(1);
event_user(0);

layout = new Layout();
layout.SetPosXY(16, 16, 128, 128);
layout.Label("Editor");

var r = layout.Row();
r.Button().Label("OPEN");
r.Button().Label("SANS");
r.Real().Label("LV");

var c = layout.Column();
c.Button().Label("x");
c.Button().Label("y");
c.Button().Label("z");

var d = layout.Dropdown().Label("OPTIONS");
d.Button().Label("Continue").Operator(Op_Restart);
d.Button().Label("Quit").Operator(Op_End);

display_set_gui_size(room_width, room_height);
draw_set_font(fnt_default);
