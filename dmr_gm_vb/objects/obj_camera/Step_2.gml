/// @desc Camera Controls

// Camera is not locked
if !lock 
{
	// Set anchor variables for movement
	if mouse_check_button_pressed(mb_middle)
	|| (keyboard_check(vk_alt) && mouse_check_button_pressed(mb_left))
	{
		mouseanchor[0] = window_mouse_get_x();
		mouseanchor[1] = window_mouse_get_y();
		cameraanchor[0] = viewlocation[0];
		cameraanchor[1] = viewlocation[1];
		cameraanchor[2] = viewlocation[2];
		rotationanchor[0] = viewdirection;
		rotationanchor[1] = viewpitch;
		
		middlemode = keyboard_check(vk_shift);
		middlelock = 1;
	}
	
	// Is moving
	if middlelock
	{
		// Rotate
		if middlemode == 0
		{
			var r, u;
			r = window_mouse_get_x() - mouseanchor[0];
			u = window_mouse_get_y() - mouseanchor[1];
			
			viewdirection = rotationanchor[0] - r/4;
			viewpitch = rotationanchor[1] + u/4;
		}
		// Pan
		else
		{
			var r, u;
			var d = viewdistance/40;
			r = (window_mouse_get_x() - mouseanchor[0])*d/20;
			u = (window_mouse_get_y() - mouseanchor[1])*d/20;
			
			viewlocation[0] = cameraanchor[0] + (viewright[0]*r) + (viewup[0]*u);
			viewlocation[1] = cameraanchor[1] - (viewright[1]*r) - (viewup[1]*u);
			viewlocation[2] = cameraanchor[2] + (viewright[2]*r) + (viewup[2]*u);
		}
		
		// Wrap Mouse Position
		var _mx = window_mouse_get_x(),
			_my = window_mouse_get_y();
		var _w = window_get_width(),
			_h = window_get_height();
		
		if _mx < 0 {window_mouse_set(_mx+_w, _my); mouseanchor[0] += _w;}
		else if _mx >= _w-1 {window_mouse_set(_mx-_w, _my); mouseanchor[0] -= _w;}
		_mx = window_mouse_get_x();
		
		if _my <= 0 {window_mouse_set(_mx, _my+_h); mouseanchor[1] += _h;}
		else if _my >= _h-1 {window_mouse_set(_mx, _my-_h); mouseanchor[1] -= _h;}
		_my = window_mouse_get_y();
		
		// Wrap Camera Rotations
		if !(mouse_check_button(mb_middle) || mouse_check_button(mb_left))
		{
			while (viewdirection < 0) {viewdirection += 360;}
			viewdirection = viewdirection mod 360;
		
			while (viewpitch < 0) {viewpitch += 360;}
			viewpitch = viewpitch mod 360;
		
			middlelock = 0;
		}
	}

	// Zoom in/out
	var lev = mouse_wheel_up() - mouse_wheel_down();
	if lev != 0
	{
		var d = 1.1;
		viewdistance *= (lev<0)? d: (1/d);
	}

}

lock = false;

// Check if window size changed
if (
	window_get_width() != width || 
	window_get_height() != height ||
	lastfullscreen != window_get_fullscreen()
	)
&& (window_get_width() > 0 && window_get_height() > 0)
{
	width = window_get_width();
	height = window_get_height();
	matproj = matrix_build_projection_perspective_fov(
		fieldofview, width/height, znear, zfar);
	lastfullscreen = window_get_fullscreen();
	
	surface_resize(application_surface, width, height);
	display_set_gui_size(width, height);
	
	with all {event_perform(ev_draw, 65);}
}

// Update orbit
if orbitmodel
{
	var loc = obj_modeltest.modelposition;
	var dist = point_distance(viewlocation[0], viewlocation[1], loc[0], loc[1]);
	var dir = point_direction(viewlocation[0], viewlocation[1], loc[0], loc[1]);
	
	// Smoothly move to position
	viewlocation[0] = loc[0] - dist*0.9 * dcos(dir);
	viewlocation[1] = loc[1] + dist*0.9 * dsin(dir);
	
	viewdirection += orbitspeed*delta_time/60000;
}

UpdateMatView();
