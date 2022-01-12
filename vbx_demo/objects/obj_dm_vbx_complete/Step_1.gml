/// @desc

// Inherit the parent event
event_inherited();

// Toggle playback
if keyboard_check_pressed(vk_space)
{
	isplaying ^= true;
}

// Progress Animation
if isplaying
{
	trackpos = Modulo(trackpos + tracktimestep*playbackspeed, 1);
	UpdateAnim();
}
else
{
	// Move by frame
	var lev = LevKeyPressed(vk_right, vk_left);
	if lev != 0
	{
		// Move by playback speed
		if keyboard_check(vk_shift) {trackpos += lev*tracktimestep * playbackspeed;}
		// Move by frame
		else
		{
			var tdata = trackdata_anim;
			
			var _ll = 1/tdata.length;
			if lev < 0 {trackpos = Quantize(trackpos+lev*_ll, _ll);}
			else {trackpos = QuantizeCeil(trackpos+lev*_ll, _ll);}
			
			if trackpos < tdata.positionrange[0] {trackpos = tdata.positionrange[1];}
			else if trackpos > tdata.positionrange[1] {trackpos = tdata.positionrange[0];}
		}
		posemode = 1;
		UpdateAnim();
	}
}

var s = 0.01;
mattex_x += LevKeyHeld(vk_numpad6, vk_numpad4)*s;
mattex_y += LevKeyHeld(vk_numpad2, vk_numpad8)*s;

mattex = Mat4Translate(mattex_x, mattex_y, 0);

var _pos = playbacktimeline.UpdateTimeline(trackpos);
if _pos != trackpos
{
	trackpos = _pos;
	UpdateAnim();
}

if playbacktimeline.IsMouseOver()
|| playbacktimeline.active
{
	camera.lock = true;	
}
