/// @desc

// Inherit the parent event
event_inherited();

var lev = LevKeyHeld(vk_right, vk_left);
if lev != 0
{
	trackpos += lev*0.002;
	UpdatePose(true);
}

if isplaying
{
	trackpos = Modulo(trackpos + trackposspeed, 1);
	UpdatePose(true);
}
