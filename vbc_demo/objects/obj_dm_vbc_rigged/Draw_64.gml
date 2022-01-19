/// @desc

// Inherit the parent event
event_inherited();

if (demo.showgui)
{
	draw_set_halign(fa_left);
	draw_set_valign(fa_bottom);
	var s = "Trk Evaluation Time: ";
	s += string(trkexectime)+" mcs (";
	s += string((trkexectime/1000000)*game_get_speed(gamespeed_fps))+" frames)";
	draw_text(4, window_get_height()-1, s);
}
