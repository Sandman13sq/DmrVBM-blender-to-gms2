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
	trackpos = Modulo(trackpos + trackposspeed, 1);
	UpdateAnim();
}
else
{
	// Move by frame
	var lev = LevKeyHeld(vk_right, vk_left);
	if lev != 0
	{
		trackpos += lev*trackposspeed;
		UpdatePose(true);
	}
}
