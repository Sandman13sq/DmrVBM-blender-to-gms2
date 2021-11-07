/// @desc

#region // Toggleables ==========================================

if keyboard_check_pressed(ord("M"))
{
	//vbmode = (vbmode+1) mod 3;
	curly.shadermode = Modulo(curly.shadermode+1, 2);
}

#endregion

// Move Model
var lev;
var f = camera.viewforward;
var r = camera.viewright;
var l;
l = point_distance(0,0, f[0], f[1]); f[0] = f[0]/l; f[1] = f[1]/l;
l = point_distance(0,0, r[0], r[1]); r[0] = r[0]/l; r[1] = r[1]/l;

lev = LevKeyHeld(VKey.d, VKey.a);
modelposition[0] -= r[0]*lev;
modelposition[1] += r[1]*lev;
lev = LevKeyHeld(VKey.w, VKey.s);
modelposition[0] += f[0]*lev;
modelposition[1] -= f[1]*lev;

modelzrot = LevKeyHeld(VKey.e, VKey.q);

curly.isplaying ^= keyboard_check_pressed(vk_space);
curly.keymode ^= keyboard_check_pressed(ord("K"));
curly.wireframe ^= keyboard_check_pressed(ord("L"));

if keyboard_check_pressed(vk_space)
{
	layout_model.FindElement("toggleplayback").Toggle();
}

layout.Update();

if 0
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
}

