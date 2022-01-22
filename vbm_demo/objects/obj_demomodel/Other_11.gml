/// @desc Layout

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
	
	b.Enum("Cullmode").DefineControl(demo, "cullmode").DefineItems([
		[cull_noculling, "No Culling", "Draw all triangles"],
		[cull_clockwise, "Cull Clockwise", "Skip triangles facing away from screen"],
		[cull_counterclockwise, "Cull Counter", "Skip triangles facing towards the screen"],
		]).
		Description("Set which triangles to NOT draw.\nGood for speeding up draw time")
		.SetDefault(cull_clockwise);
	
	// Draw Matrix
	var d = b.Dropdown("Draw Matrix").SetIDName("drawmatrix")
		.Description("Show variables sent in for draw matrix uniform");
	
	if ( _nodrawmatrix )
	{
		d.Real("Alpha").DefineControl(self, "alpha").SetBounds(0, 1).valueprecision=3;
	}
	else
	{
		var e = d.Real("Alpha").DefineControl(self, "alpha").SetBounds(0, 1);
			e.valueprecision = 3;
			e.valuedefault = 1.0;
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
	for (var i = 0; i < vbm.vbcount; i++)
	{
		l.DefineListItem(i, vbm.vbnames[i], vbm.vbnames[i]);
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
	
	var l = b.Enum("Animation").Operator(OP_ActionSelect);
	for (var i = 0; i < trkcount; i++)
	{
		l.DefineListItem(i, trknames[i]);
	}
	
	// Pose
	layout_poselist = b.Enum("Pose").Operator(OP_PoseMarkerJump);
	
	b.Bool("Play Animation").DefineControl(self, "isplaying").Operator(OP_TogglePlayback);
	b.Real("Pos")
		.Operator(OP_ChangeTrackPos)
		.DefineControl(self, "trkposition")
		.SetBounds(0, 1, 0.02)
		.Description("Toggle animation playback")
		.operator_on_change = true;
	b.Real("Animation Speed")
		.DefineControl(self, "playbackspeed")
		.SetBounds(-100, 100, 0.02)
		.SetDefault(1.0)
		.Description("Set playback speed");
	b.Button("Rest Pose").Operator(OP_RestPose);
	
	var e = b.Enum("Interpolation")
		.Operator(OP_SetInterpolation)
		.DefineControl(self, "interpolationtype")
		.Description("Method of blending together transforms when evaluating animation.")
		.DefineItems([
			[TRK_Intrpl.constant, "Constant", "Floors keyframe position when evaluating pose"],
			[TRK_Intrpl.linear, "Linear", "Linearly keyframe position when evaluating pose"],
			[TRK_Intrpl.smooth, "Square", "Uses square of position difference when evaluating pose"]
			])
		.SetDefault(TRK_Intrpl.linear);
}
