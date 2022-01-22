/// @desc Draw Layout

if reactivated
{
	event_perform(ev_draw, 65);
	reactivated = false;
}

if (demo.showgui)
{
	layout.Draw();
}
