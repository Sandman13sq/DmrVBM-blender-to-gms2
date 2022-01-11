/// @desc 

// Inherit the parent event
event_inherited();

draw_text(240, 16, lastangles)

var m = obj_camera.matview
var xangle, yangle, zangle;
		
xangle = darcsin(-m[6]);
if (dcos(xangle) >= 0.0001)
{
	yangle = darctan2(m[2], m[10]);
	zangle = darctan2(m[4], m[5]);
}
else
{
	yangle = 0.0;
	zangle = darctan2(-m[1], m[5]);
}

draw_text(240, 32, [xangle, yangle, zangle]);
