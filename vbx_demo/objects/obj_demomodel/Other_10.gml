/// @desc Methods + Operators

function FetchDrawMatrix()
{
	return BuildDrawMatrix(
		alpha, emission, roughness, rimstrength,
		ArrayToRGB(demo.colorblend), demo.colorblend[3],
		ArrayToRGB(demo.colorfill), demo.colorfill[3],
		);
}

function CommonLayout(_hastextures, _hasnormals, _nodrawmatrix)
{
	var b = layout.Box("Display");
	
	b.Bool("Wireframe").DefineControl(demo, "wireframe")
		.Description("Change primitive type to wireframe.");
	
	if (_hastextures)
	{
		b.Bool("Use Textures").DefineControl(demo, "usetextures")
			.Description("Use textures instead of vertex colors.");
	}
	if (_hasnormals)
	{
		b.Bool("Use Normal Maps").DefineControl(demo, "usenormalmap")
			.Description("Use normal maps on objects that have them.");
		b.Bool("Draw Normal Maps").DefineControl(demo, "drawnormal")
			.Description("Display normal maps on objects that have them.");
	}
	
	b.Enum("Cullmode").DefineControl(demo, "cullmode").DefineListItems([
		[cull_noculling, "No Culling", "Draw all triangles"],
		[cull_clockwise, "Cull Clockwise", "Skip triangles facing away from screen"],
		[cull_counterclockwise, "Cull Counter", "Skip triangles facing towards the screen"],
		]).
		Description("Set which triangles to NOT draw.\nGood for speeding up draw time");
	
	// Draw Matrix
	var d = b.Dropdown("Draw Matrix").SetIDName("drawmatrix")
		.Description("Show variables sent in for draw matrix uniform");
	
	if ( _nodrawmatrix )
	{
		d.Real("Alpha").DefineControl(self, "alpha").SetBounds(0, 1).valueprecision=3;
	}
	else
	{
		d.Real("Alpha").DefineControl(self, "alpha").SetBounds(0, 1).valueprecision=3;
		d.Real("Emission").DefineControl(self, "emission").SetBounds(0, 1)
			.Description("Amount that the natural color shows over the shading.")
			.valueprecision=3;
		d.Real("Roughness").DefineControl(self, "roughness").SetBounds(0, 1)
			.Description("Size of reflected light")
			.valueprecision=3;
		d.Real("Rim Strength").DefineControl(self, "rimstrength").SetBounds(0, 1)
			.Description("")
			.valueprecision=3;
	}
	
	var r;
	
	d.Text("Blend Color (R,G,B,amt)");
	r = d.Row();
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorblend", 0).draw_increments = false; 
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorblend", 1).draw_increments = false; 
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorblend", 2).draw_increments = false;
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorblend", 3).draw_increments = false;

	d.Text("Fill Color (R,G,B,amt)");
	r = d.Row();
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorfill", 0).draw_increments = false; 
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorfill", 1).draw_increments = false; 
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorfill", 2).draw_increments = false;
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorfill", 3).draw_increments = false;
	
}

function Panel_MeshSelect(layout)
{
	// Mesh
	var b = layout.Box("Meshes");
	var l = b.List()
		.Operator(OP_MeshSelect)
		.DefineControl(self, "meshselect");
	for (var i = 0; i < vbx.vbcount; i++)
	{
		l.DefineListItem(i, vbx.vbnames[i], vbx.vbnames[i]);
	}
	
	var r = b.Row();
	r.Bool("Visible").SetIDName("meshvisible")
		.DefineControl(self, "meshvisible", meshselect)
		.Description("Toggle visibility for selected mesh");
	r.Button("Toggle All").Operator(OP_ToggleAllVisibility)
		.Description("Toggle visibility for all meshes");
}

function Panel_Playback(layout)
{
	// Playback
	var b = layout.Box("Playback");
	b.Bool("Play Animation").DefineControl(self, "isplaying").Operator(OP_TogglePlayback);
	b.Real("Pos")
		.Operator(OP_ChangeTrackPos)
		.DefineControl(self, "trackpos")
		.SetBounds(0, 1, 0.02)
		.Description("Toggle animation playback")
		.operator_on_change = true;
	b.Real("Animation Speed")
		.DefineControl(self, "playbackspeed")
		.SetBounds(-100, 100, 0.02)
		.SetDefault(1.0)
		.Description("Set playback speed");
	b.Button("Bind Pose").Operator(OP_BindPose);
}

function Panel_Pose(layout)
{
	// Pose
	var b = layout.Box("Poses");
	var l = b.Dropdown("Select a Pose").List().Operator(OP_PoseMarkerJump);
	for (var i = 0; i < trackdata_poses.markercount; i++)
	{
		l.DefineListItem(i, trackdata_poses.markernames[i]);
	}

	var e = b.Enum("Interpolation")
		.Operator(OP_SetInterpolation)
		.DefineControl(self, "interpolationtype")
		.DefineListItems([
			[AniTrack_Intrpl.constant, "Constant", "Floors keyframe position when evaluating pose"],
			[AniTrack_Intrpl.linear, "Linear", "Linearly keyframe position when evaluating pose"],
			[AniTrack_Intrpl.smooth, "Square", "Uses square of position difference when evaluating pose"]
			])
		.Description("Method of blending together transforms when evaluating animation.");
}

function DrawMeshFlash(uniform)
{
	var n = vbx.vbcount;
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
			vbx.SubmitVBIndex(i, pr_trianglelist, demo.usetextures? meshtexture[i]: -1);
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
	
	for (var i = 0; i < vbx.vbcount; i++)
	{
		if string_pos("def", vbx.vbnames[i]) {meshtexture[i] = _tex_def;}
		if string_pos("skin", vbx.vbnames[i]) {meshtexture[i] = _tex_skin;}
		if string_pos("eye", vbx.vbnames[i]) {meshtexture[i] = _tex_skin;}
		if string_pos("hair", vbx.vbnames[i]) {meshtexture[i] = _tex_hair;}
		if string_pos("gun", vbx.vbnames[i]) {meshtexture[i] = _tex_gun;}
	}
}

function LoadNormalTextures()
{
	var _tex_skin = sprite_get_texture(tex_curly_skin_nor, 0);
	var _tex_def = sprite_get_texture(tex_curly_def_nor, 0);
	var _tex_hair = sprite_get_texture(tex_curly_hair_nor, 0);
	//var _tex_gun = sprite_get_texture(tex_curly_gun_nor, 0);
	var i;
	
	for (var i = 0; i < vbx.vbcount; i++)
	{
		if string_pos("def", vbx.vbnames[i]) {meshnormalmap[i] = _tex_def;}
		if string_pos("skin", vbx.vbnames[i]) {meshnormalmap[i] = _tex_skin;}
		if string_pos("eye", vbx.vbnames[i]) {meshnormalmap[i] = _tex_skin;}
		if string_pos("hair", vbx.vbnames[i]) {meshnormalmap[i] = _tex_hair;}
		//if string_pos("gun", vbx.vbnames[i]) {meshnormalmap[i] = _tex_gun;}
	}
}
