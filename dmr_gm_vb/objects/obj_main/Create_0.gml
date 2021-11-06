/// @desc

show_debug_overlay(1);
event_user(0);

//display_set_gui_size(room_width, room_height);
display_set_gui_maximize(1, 1);
draw_set_font(fnt_default);

RENDERING = new Rendering();
RENDERING.DefineUniform("u_drawmatrix");
RENDERING.DefineUniform("u_camera");
RENDERING.DefineUniform("u_matpose");

room_goto(rm_modeltest);
