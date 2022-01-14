/// @desc

// Toggle GUI
if (keyboard_check_pressed(key_gui))
{
	showgui ^= 1;
	show_debug_overlay(showgui || keyboard_check(vk_control));
	
	cursortimeout = cursortimeouttime*(showgui);
}

if (keyboard_check_pressed(vk_escape))
{
	showgui = 1;
	show_debug_overlay(showgui);
	
	cursortimeout = cursortimeouttime*(showgui);
}

// Cursor Display
if (!showgui)
{
	cursortimeout = max(0, cursortimeout-delta_time/1000000);
	
	if (
		mouselastx != window_mouse_get_x() ||
		mouselasty != window_mouse_get_y()
	)
	{
		mouselastx = window_mouse_get_x();
		mouselasty = window_mouse_get_y();
		
		cursortimeout = cursortimeouttime;
	}
}

if (cursortimeout == 0 && !showgui)
{
	window_set_cursor(cr_none);
}
else
{
	window_set_cursor(cr_default);
}

// Update Layout
if (showgui)
{
	if ( layout.Update() )
	{
		camera.lock = 1;
	}
}

// Switch mesh
if (keyboard_check_pressed(VKey._1)) {OP_ModelMode(ModelType.simple, 0);}
if (keyboard_check_pressed(VKey._2)) {OP_ModelMode(ModelType.normal, 0);}
if (keyboard_check_pressed(VKey._3)) {OP_ModelMode(ModelType.vbx, 0);}
if (keyboard_check_pressed(VKey._4)) {OP_ModelMode(ModelType.normalmap, 0);}
if (keyboard_check_pressed(VKey._5)) {OP_ModelMode(ModelType.rigged, 0);}
if (keyboard_check_pressed(VKey._6)) {OP_ModelMode(ModelType.complete, 0);}

// Demo Controls
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
	
	var xlev = LevKeyHeld(key_right, key_left);
	var ylev = LevKeyHeld(key_up, key_down);
	var rotlev = LevKeyHeld(key_rotateright, key_rotateleft);
	var movespeed = delta_time/60000;
	var rotspeed = delta_time/10000;
	
	// Move Camera
	if (!keyboard_check(vk_shift))
	{
		if (xlev != 0)
		{
			camera.viewlocation[0] -= r[0]*xlev * movespeed;
			camera.viewlocation[1] -= r[1]*xlev * movespeed;
		}
		
		if (ylev != 0)
		{
			camera.viewlocation[0] += f[0]*ylev * movespeed;
			camera.viewlocation[1] += f[1]*ylev * movespeed;
		}
		
		camera.viewdirection += rotspeed * -rotlev;
	}
	// Move Model
	else
	{
		if (xlev != 0)
		{
			modelposition[0] -= r[0]*xlev * movespeed;
			modelposition[1] -= r[1]*xlev * movespeed;
		}
	
		if (ylev != 0)
		{
			modelposition[0] += f[0]*ylev * movespeed;
			modelposition[1] += f[1]*ylev * movespeed;
		}
		
		modelzrot += rotspeed * -rotlev;
	}
	
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

