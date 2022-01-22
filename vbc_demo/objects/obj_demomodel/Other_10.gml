/// @desc Methods + Operators

function FetchDrawMatrix()
{
	return BuildDrawMatrix(
		alpha, emission, roughness, rimstrength,
		ArrayToRGB(demo.colorblend), demo.colorblend[3],
		ArrayToRGB(demo.colorfill), demo.colorfill[3],
		);
}

function FetchPoseFiles(path, outtrk, outnames)
{
	path = filename_dir(path)+"/";
	var fname = file_find_first(path+"*.trk", 0);
	var trk;
	
	while (fname != "")
	{
		if ( file_exists(path+fname) )
		{
			trk = OpenTRK(path+fname);
			if trk
			{
				array_push(outtrk, trk);
				array_push(outnames, fname);
			}
		}
		
		fname = file_find_next();
	}
	
	file_find_close();
	
	return array_length(outtrk);
}

function DrawMeshFlash(uniform)
{
	var n = vbm.vbcount;
	var zfunc = gpu_get_zfunc();
	
	gpu_set_zfunc(cmpfunc_always);
	for (var i = 0; i < n; i++)
	{
		if ( meshvisible[i] && meshflash[i] > 0 )
		{
			shader_set_uniform_f_array(uniform, 
				BuildDrawMatrix(1, 1, 1, 0, 0, 0, c_white, 
					power(dsin(180*meshflash[i]/demo.flashtime), 2.0)
					));
			vbm.SubmitVBIndex(i, pr_trianglelist, demo.usetextures? meshtexture[i]: -1);
		}
	}
	gpu_set_zfunc(zfunc);
}

function LoadDiffuseTextures()
{
	var _tex_skin = sprite_get_texture(tex_curly_skin_col, 0);
	var _tex_def = sprite_get_texture(tex_curly_def_col, 0);
	var _tex_hair = sprite_get_texture(tex_curly_hair_col, 0);
	var _tex_gun = sprite_get_texture(tex_curly_gun_col, 0);
	var i;
	
	for (var i = 0; i < vbm.vbcount; i++)
	{
		if string_pos("def", vbm.vbnames[i]) {meshtexture[i] = _tex_def;}
		if string_pos("skin", vbm.vbnames[i]) {meshtexture[i] = _tex_skin;}
		if string_pos("eye", vbm.vbnames[i]) {meshtexture[i] = _tex_skin;}
		if string_pos("hair", vbm.vbnames[i]) {meshtexture[i] = _tex_hair;}
		if string_pos("gun", vbm.vbnames[i]) {meshtexture[i] = _tex_gun;}
	}
}

function LoadNormalTextures()
{
	var _tex_skin = sprite_get_texture(tex_curly_skin_nor, 0);
	var _tex_def = sprite_get_texture(tex_curly_def_nor, 0);
	var _tex_hair = sprite_get_texture(tex_curly_hair_nor, 0);
	//var _tex_gun = sprite_get_texture(tex_curly_gun_nor, 0);
	var i;
	
	for (var i = 0; i < vbm.vbcount; i++)
	{
		if string_pos("def", vbm.vbnames[i]) {meshnormalmap[i] = _tex_def;}
		if string_pos("skin", vbm.vbnames[i]) {meshnormalmap[i] = _tex_skin;}
		if string_pos("eye", vbm.vbnames[i]) {meshnormalmap[i] = _tex_skin;}
		if string_pos("hair", vbm.vbnames[i]) {meshnormalmap[i] = _tex_hair;}
		//if string_pos("gun", vbm.vbnames[i]) {meshnormalmap[i] = _tex_gun;}
	}
}

function UpdateAnim()
{
	var _vbm = vbm;
	var _trk = trkactive;
	
	// Generate relative bone matrices for position in animation
	trkexectime = get_timer();
	EvaluateAnimationTracks(trkposition, 
		interpolationtype,	// Method to blend keyframes with (constant, linear, square)
		_vbm.bonenames,		// Keys to use for track mapping
		_trk,				// Track data with transforms
		posetransform		// 2D Array to write matrix data to
		);
	trkexectime = get_timer()-trkexectime;
	
	// Convert relative bone matrices to model-space matrices
	CalculateAnimationPose(
		_vbm.bone_parentindices,	// index of bone's parent
		_vbm.bone_localmatricies,	// matrix of bone relative to parent
		_vbm.bone_inversematricies,	// matrix of bone relative to model origin
		posetransform,				// relative transforms (from animation or pose)
		matpose						// flat array of matrices to write data to
		);
}

function UpdatePose()
{
	var _vbm = vbm;
	var _trk = trkactive;
	
	if (_trk.markercount)
	{
		var _pos = _trk.markerpositions[trkmarkerindex];
		
		// Generate relative bone matrices for position in animation
		EvaluateAnimationTracks(_pos, 
			TRK_Intrpl.constant,	// Method to blend keyframes with (constant, linear, square)
			_vbm.bonenames,		// Keys to use for track mapping
			_trk,	// Track data with transforms
			posetransform		// 2D Array to write matrix data to
			);
	
		// Convert relative bone matrices to model-space matrices
		CalculateAnimationPose(
			_vbm.bone_parentindices,	// index of bone's parent
			_vbm.bone_localmatricies,	// matrix of bone relative to parent
			_vbm.bone_inversematricies,	// matrix of bone relative to model origin
			posetransform,				// relative transforms (from animation or pose)
			matpose						// flat array of matrices to write data to
			);
	}
}

#region Operators ==================================================

function OP_MeshSelect(value, btn)
{
	meshselect = value;
	layout.FindElement("meshvisible").DefineControl(self, "meshvisible", value);
	meshflash[meshselect] = demo.flashtime;
}

function OP_ToggleAllVisibility(value, btn)
{
	var n = array_length(meshvisible);
	for (var i = 0; i < n; i++)
	{
		if meshvisible[i]
		{
			ArrayClear(meshvisible, 0);
			return;
		}
	}
	
	ArrayClear(meshvisible, 1);
}

function OP_RestPose(value, btn)
{
	isplaying = false;
	Mat4ArrayFlatClear(matpose, Mat4());
	demo.modelzrot = 0;
	
	if keyboard_check_direct(vk_alt)
	{
		Mat4ArrayFlatClear(matpose, Mat4Rotate(0, 0, 180));
		demo.modelzrot = 180;
	}
}

function OP_TogglePlayback(value, btn)
{
	posemode = 1;
	isplaying = value;
	UpdateAnim();
}

function OP_ChangeTrackPos(value, btn)
{
	posemode = 1;
	trackpos = value;
	UpdateAnim();
}

function OP_PoseMarkerJump(value, btn)
{
	trkmarkerindex = value;
	isplaying = false;
	
	if (trkactive.markercount)
	{
		trkposition = trkactive.markerpositions[trkmarkerindex];
		UpdateAnim();
	}
}

function OP_ActionSelect(value, btn)
{
	trkindex = value;
	trkactive = trkanims[trkindex];
	trktimestep = TrackData_GetTimeStep(trkactive, game_get_speed(gamespeed_fps));
	trkposlength = trkactive.length;
	
	layout_poselist.ClearItems();
	for (var i = 0; i < trkactive.markercount; i++)
	{
		layout_poselist.DefineListItem(i, trkactive.markernames[i]);
	}
	
	printf([trktimestep, trkposition, trkmarkerindex])
	
	UpdateAnim();
}

function OP_SetInterpolation(value, btn)
{
	interpolationtype = value;
	UpdateAnim();
}

function OP_CameraToBone(value, btn)
{
	var b = vbm.FindBone("t_camera")
	
	if (b)
	{
		var m = Mat4ArrayFlatGet(matpose, b);
		var loc = Mat4GetTranslation(m);
		
		// Source: https://stackoverflow.com/questions/21515755/how-to-calculate-the-angles-xyz-from-a-matrix4x4
		var xangle, yangle, zangle;
		
		xangle = darcsin(-m[6]);
		if (dcos(xangle) >= 0.0001)
		{
			yangle = darctan2(-m[2], m[10]);
			zangle = darctan2(-m[4], m[5]);
		}
		else
		{
			yangle = 0.0;
			zangle = darctan2(m[1], m[5]);
		}
		
		// Location
		obj_camera.viewlocation[0] = loc[0];
		obj_camera.viewlocation[1] = loc[1];
		obj_camera.viewlocation[2] = loc[2];
		
		obj_camera.viewdirection = xangle;
		obj_camera.viewpitch = yangle;
		
		obj_camera.UpdateMatView();
		
		lastangles = [xangle, yangle, zangle]
		
	}
}


#endregion

