/// @desc

if layout.Update()
{
	camera.lock = 1;
}

if !camera.lock
{
	// Move Model
	var lev, spd;
	var f = camera.viewforward;
	var r = camera.viewright;
	var l;
	l = point_distance(0,0, f[0], f[1]); 
	if (l != 0)
	{
		f[0] = f[0]/l; f[1] = f[1]/l;
	}
	l = point_distance(0,0, r[0], r[1]); 
	if (l != 0)
	{
		r[0] = r[0]/l; r[1] = r[1]/l;
	}
	
	spd = delta_time/60000;
	lev = LevKeyHeld(VKey.d, VKey.a)*spd;
	if (lev != 0)
	{
		modelposition[0] -= r[0]*lev;
		modelposition[1] -= r[1]*lev;
	}
	lev = LevKeyHeld(VKey.w, VKey.s)*spd;
	if (lev != 0)
	{
		modelposition[0] += f[0]*lev;
		modelposition[1] += f[1]*lev;
	}
	
	// Rotate Model
	spd = delta_time/10000;
	modelzrot += LevKeyHeld(VKey.e, VKey.q)*spd;
	
	if mouse_check_button_pressed(mb_left)
	&& !keyboard_check(vk_alt)
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
			modelzrot = zrotanchor - (window_mouse_get_x()-mouseanchor[0]);
		}
		else
		{
			mouselock = 0;	
		}
	}
}
