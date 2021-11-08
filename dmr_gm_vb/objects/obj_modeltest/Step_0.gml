/// @desc

// Move Model
var lev;
var f = camera.viewforward;
var r = camera.viewright;
var l;
l = point_distance(0,0, f[0], f[1]); f[0] = f[0]/l; f[1] = f[1]/l;
l = point_distance(0,0, r[0], r[1]); r[0] = r[0]/l; r[1] = r[1]/l;

lev = LevKeyHeld(VKey.d, VKey.a);
modelposition[0] -= r[0]*lev;
modelposition[1] += r[1]*lev;
lev = LevKeyHeld(VKey.w, VKey.s);
modelposition[0] += f[0]*lev;
modelposition[1] -= f[1]*lev;

modelzrot += LevKeyHeld(VKey.e, VKey.q);

layout.Update();

// Rotate Model
if mouse_check_button_pressed(mb_left)
{
	mouseanchor[0] = window_mouse_get_x();
	mouseanchor[1] = window_mouse_get_y();
	zrotanchor = modelzrot;
	mouselock = 1;
}
if mouselock
{
	if mouse_check_button(mb_left)
	{
		camera.lock = 1;
		modelzrot = zrotanchor + window_mouse_get_x()-mouseanchor[0];
	}
	else
	{
		mouselock = 0;	
	}
}
