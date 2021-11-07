/// @desc

#region // Toggleables ==========================================

if keyboard_check_pressed(ord("M"))
{
	//vbmode = (vbmode+1) mod 3;
	curly.shadermode = Modulo(curly.shadermode+1, 2);
}

#endregion

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

