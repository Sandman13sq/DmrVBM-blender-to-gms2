/// @desc Update Animation

// Inherit the parent event
event_inherited();

// Mesh Select Flash
var n = array_length(meshflash);
for (var i = 0; i < n; i++)
{
	meshflash[i] = max(0, meshflash[i]-1);
}

// Pose Navigation
if (keyboard_check_pressed(demo.key_posenext))
{
	OP_PoseMarkerJump(Modulo(poseindex+1, posecount));
}
if (keyboard_check_pressed(demo.key_poseprev))
{
	OP_PoseMarkerJump(Modulo(poseindex-1, posecount));
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

