/*
*/

// Creates and updates a direction vector controlled by mouse movement
function MouseLook() constructor
{
	lookdirection = 0; // Left-Right [0-360]
	lookpitch = 0; // Up-Down [-1 - 1] [Down, Up], 0 = Straight Forward
	
	sensitivity = 0.2;
	
	pitchrange = [-0.5, 0.5];
	
	active = false;
	activedelay = 0;
	
	lastFullscreen = window_get_fullscreen();
	fullscreenDelay = 0;
	
	viewforward = [0, 1, 0];
	viewright = [1, 0, 0];
	viewup = [0, 0, 1];
	
	mouseanchor = [0, 0];
	
	function SetActive(_bool)
	{
		active = _bool;
		window_set_cursor(active? cr_none: cr_default);
		
		if active {window_mouse_set(window_get_width() * 0.5, window_get_height() * 0.5);}
		else {fullscreenDelay = false;}
	}
	
	// Set min/max range for vertical movement
	function SetVerticalRange(_amtUp, _amtDown)
	{
		if _amtUp < _amtDown
		{
			pitchrange[1] = _amtDown;
			pitchrange[0] = _amtUp;
		}
		else
		{
			pitchrange[0] = _amtDown;
			pitchrange[1] = _amtUp;
		}
		
		lookpitch = clamp(lookpitch, pitchrange[0], pitchrange[1]);
	}
	
	function SetDirection(value) {lookdirection = value; UpdateView();}
	function AddDirection(value) {lookdirection += value; UpdateView();}
	
	function SetPitch(value) {lookpitch = clamp(value, pitchrange[0], pitchrange[1]); UpdateView();}
	function AddPitch(value) {lookpitch = clamp(lookpitch + value, pitchrange[0], pitchrange[1]); UpdateView();}
	
	// Read mouse movement and apply changes
	function Update(_active)
	{
		// Skip if fullscreen has changed
		if lastFullscreen != window_get_fullscreen()
		{
			lastFullscreen = window_get_fullscreen();
			fullscreenDelay = 30;
		}
		
		if _active
		{
			var _wHalf = window_get_width() * 0.5,
				_hHalf = window_get_height() * 0.5;
			
			window_mouse_set(_wHalf, _hHalf);
			
			if activedelay {activedelay = 0}
			else
			{
				if keyboard_check_pressed(vk_escape) || !window_has_focus()
				{
					SetActive(false);
				}
			
				if fullscreenDelay > 0 {fullscreenDelay--; return;}
			
				lookdirection = lookdirection - sensitivity * (window_mouse_get_x() - _wHalf);
				lookpitch = clamp(lookpitch + sensitivity * (window_mouse_get_y() - _hHalf) / 90, 
					pitchrange[0], pitchrange[1]);
				
				UpdateView();
			}
		}
		else
		{
			UpdateView();
			activedelay = 1;
		}
	}
	
	// Returns forward vector of mouse look
	function GetViewForward() {return viewforward;}
	function GetViewRight() {return viewright;}
	function GetViewUp() {return viewup;}
	
	function UpdateView()
	{
		viewforward = [
				dcos(lookdirection) * dcos(lookpitch * 90),
				-dsin(lookdirection) * dcos(lookpitch * 90),
				-dsin(lookpitch * 90)
				];
			
			viewright = [
				dcos(lookdirection + 90) * dcos(lookpitch * 90),
				-dsin(lookdirection + 90) * dcos(lookpitch * 90),
				-dsin(lookpitch * 90)
				];
			
			viewup = [
				viewright[1] * viewforward[2] - viewright[2] * viewforward[1],
				viewright[2] * viewforward[0] - viewright[0] * viewforward[2],
				viewright[0] * viewforward[1] - viewright[1] * viewforward[0]
				];
	}
	
	Update(0);
}
