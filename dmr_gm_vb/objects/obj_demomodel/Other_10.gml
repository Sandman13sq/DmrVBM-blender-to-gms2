/// @desc Methods + Operators

function FetchDrawMatrix()
{
	return BuildDrawMatrix(
		alpha, emission, shine, sss,
		ArrayToRGB(demo.colorblend), demo.colorblend[3],
		ArrayToRGB(demo.colorfill), demo.colorfill[3],
		);
}

function CommonLayout(_hastextures, _hasnormals, _nodrawmatrix)
{
	var c = layout.Column("Display");
	c.Bool().Label("Wireframe").DefineControl(demo, "wireframe");
	if _hastextures
		{c.Bool().Label("Use Textures").DefineControl(demo, "usetextures");}
	if _hasnormals
		{c.Bool().Label("Draw Normal Maps").DefineControl(demo, "drawnormal");}
	
	c.Enum().Label("Cullmode").DefineControl(demo, "cullmode").DefineListItems([
		[cull_noculling, "No Culling", "Draw all triangles"],
		[cull_clockwise, "Cull Clockwise", "Skip triangles facing away from screen"],
		[cull_counterclockwise, "Cull Counter", "Skip triangles facing towards the screen"],
		]);
	
	// Draw Matrix
	c = layout.Dropdown("Draw Matrix").SetIDName("drawmatrix");
	
	if _nodrawmatrix
	{
		c.Real().Label("Alpha").DefineControl(self, "alpha").SetBounds(0, 1, 0.1);
	}
	else
	{
		c.Real().Label("Alpha").DefineControl(self, "alpha").SetBounds(0, 1, 0.1);
		c.Real().Label("Emission").DefineControl(self, "emission").SetBounds(0, 1, 0.1);
		c.Real().Label("Shine").DefineControl(self, "shine").SetBounds(0, 1, 0.1);
		c.Real().Label("SSS").DefineControl(self, "sss").SetBounds(0, 1, 0.1);
	}
	
	var r;

	c.Text("Blend Color (R,G,B,amt)");
	r = c.Row();
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorblend", 0).draw_increments = false; 
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorblend", 1).draw_increments = false; 
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorblend", 2).draw_increments = false;
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorblend", 3).draw_increments = false;

	c.Text("Fill Color (R,G,B,amt)");
	r = c.Row();
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorfill", 0).draw_increments = false; 
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorfill", 1).draw_increments = false; 
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorfill", 2).draw_increments = false;
	r.Real().SetBounds(0, 1, 0.05).DefineControl(demo, "colorfill", 3).draw_increments = false;
	
}

function LoadDiffuseTextures()
{
	var _tex_skin = sprite_get_texture(tex_curly_skin_col, 0);
	var _tex_def = sprite_get_texture(tex_curly_def_col, 0);
	var _tex_hair = sprite_get_texture(tex_curly_hair_col, 0);
	var i;
	
	i = vbx.FindVBIndex_Contains("skin"); if i meshtexture[i] = _tex_skin;
	i = vbx.FindVBIndex_Contains("head"); if i meshtexture[i] = _tex_skin;
	i = vbx.FindVBIndex_Contains("cloth"); if i meshtexture[i] = _tex_def;
	i = vbx.FindVBIndex_Contains("boot"); if i meshtexture[i] = _tex_def;
	i = vbx.FindVBIndex_Contains("headphone"); if i meshtexture[i] = _tex_def;
	i = vbx.FindVBIndex_Contains("under"); if i meshtexture[i] = _tex_def;
	i = vbx.FindVBIndex_Contains("hair"); if i meshtexture[i] = _tex_hair;
	i = vbx.FindVBIndex_Contains("brow"); if i meshtexture[i] = _tex_hair;	
}

function LoadNormalTextures()
{
	var _tex_def_nor = sprite_get_texture(tex_curly_def_nor, 0);
	var i;
	
	i = vbx.FindVBIndex_Contains("cloth"); if i meshnormalmap[i] = _tex_def_nor;
	i = vbx.FindVBIndex_Contains("boot"); if i meshnormalmap[i] = _tex_def_nor;
	i = vbx.FindVBIndex_Contains("headphone"); if i meshnormalmap[i] = _tex_def_nor;
	i = vbx.FindVBIndex_Contains("under"); if i meshnormalmap[i] = _tex_def_nor;
}
