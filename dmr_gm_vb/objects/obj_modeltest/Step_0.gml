/// @desc

// Check if window size changed
if window_get_width() != camera.width
|| window_get_height() != camera.height
{
	camera.width = window_get_width();
	camera.height = window_get_height();
	camera.matproj = matrix_build_projection_perspective_fov(
		camera.fieldofview, camera.width/camera.height, camera.znear, camera.zfar);
	
	surface_resize(application_surface, camera.width, camera.height);
	
	event_user(1);
}

if keyboard_check_pressed(ord("M"))
{
	//vbmode = (vbmode+1) mod 3;
	vbmode = (vbmode == 1)? 2: 1;
}

curly.isplaying ^= keyboard_check_pressed(vk_space);
keymode ^= keyboard_check_pressed(ord("K"));
wireframe ^= keyboard_check_pressed(ord("L"));

if keyboard_check_pressed(vk_space)
{
	layout_model.FindElement("toggleplayback").Toggle();
}

// Controls
if !middlelock {layout_model.Update();}

if (!layout_model.IsMouseOver() && !layout_model.active)
|| middlelock
{
	// Pose Matrices
	lev = LevKeyPressed(VKey.bracketClose, VKey.bracketOpen);
	if lev != 0
	{
		with curly
		{
			poseindex = Modulo(poseindex+lev, array_length(posemats));
			array_copy(matpose, 0, posemats[poseindex], 0, array_length(posemats[poseindex]));
		}
	}
	
	// Set anchor variables for movement
	if mouse_check_button_pressed(mb_middle)
	|| (keyboard_check(vk_alt) && mouse_check_button_pressed(mb_left))
	{
		mouseanchor[0] = window_mouse_get_x();
		mouseanchor[1] = window_mouse_get_y();
		cameraanchor[0] = camera.location[0];
		cameraanchor[1] = camera.location[1];
		cameraanchor[2] = camera.location[2];
		rotationanchor[0] = camera.viewdirection;
		rotationanchor[1] = camera.viewpitch;
		
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
			
			camera.viewdirection = rotationanchor[0] - r/4;
			camera.viewpitch = rotationanchor[1] + u/4;
		}
		// Pan
		else
		{
			var r, u;
			var d = camera.viewdistance/40;
			r = (window_mouse_get_x() - mouseanchor[0])*d/20;
			u = (window_mouse_get_y() - mouseanchor[1])*d/20;
			
			camera.location[0] = cameraanchor[0] + (camera.viewright[0]*r) + (camera.viewup[0]*u);
			camera.location[1] = cameraanchor[1] + (camera.viewright[1]*r) + (camera.viewup[1]*u);
			camera.location[2] = cameraanchor[2] + (camera.viewright[2]*r) + (camera.viewup[2]*u);
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
		if mouse_check_button_released(mb_middle)
		|| (mouse_check_button_released(mb_left))
		{
			while (camera.viewdirection < 0) {camera.viewdirection += 360;}
			camera.viewdirection = camera.viewdirection mod 360;
		
			while (camera.viewpitch < 0) {camera.viewpitch += 360;}
			camera.viewpitch = camera.viewpitch mod 360;
		
			middlelock = 0;
		}
	}
	
	//mouselook.Update(mouse_check_button(mb_middle) || (mouse_check_button(mb_left) && keyboard_check(vk_alt)));
	
	var lev = mouse_wheel_up() - mouse_wheel_down();
	if lev != 0
	{
		var d = 1.1;
		camera.viewdistance *= (lev<0)? d: (1/d);
	}

	x += keyboard_check(vk_right) - keyboard_check(vk_left);
	lev = keyboard_check_pressed(vk_up) - keyboard_check_pressed(vk_down);
}

// Rendering ==============================================================

drawmatrix = BuildDrawMatrix(
	1, 
	dm_emission, //*(string_pos("emi", vbx.vbnames[i]) != 0),
	dm_shine,
	dm_sss//(string_pos("skin", vbx.vbnames[i]) != 0),
	);

UpdateView();

