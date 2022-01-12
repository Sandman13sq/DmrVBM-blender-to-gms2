/// @desc

// Inherit the parent event
event_inherited();

// Mesh Select Flash
var n = array_length(meshflash)
for (var i = 0; i < n; i++)
{
	meshflash[i] = max(0, meshflash[i]-1);
}

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
	var lev = LevKeyHeld(vk_right, vk_left);
	if lev != 0
	{
		trackpos += lev*playbackspeed;
		posemode = 1;
		UpdateAnim();
	}
}
