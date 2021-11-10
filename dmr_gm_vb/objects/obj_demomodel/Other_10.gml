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
	
	c.Bool("Wireframe").DefineControl(demo, "wireframe")
		.Description("Change primitive type to wireframe.");
	
	if _hastextures
	{
		c.Bool("Use Textures").DefineControl(demo, "usetextures")
			.Description("Use textures instead of vertex colors.");
	}
	if _hasnormals
	{
		c.Bool("Draw Normal Maps").DefineControl(demo, "drawnormal")
			.Description("Display normal maps on objects that have them.");
	}
	
	c.Enum("Cullmode").DefineControl(demo, "cullmode").DefineListItems([
		[cull_noculling, "No Culling", "Draw all triangles"],
		[cull_clockwise, "Cull Clockwise", "Skip triangles facing away from screen"],
		[cull_counterclockwise, "Cull Counter", "Skip triangles facing towards the screen"],
		]).
		Description("Set which triangles to NOT draw.\nGood for speeding up draw time");
	
	// Draw Matrix
	c = layout.Dropdown("Draw Matrix").SetIDName("drawmatrix")
		.Description("Show variables sent in for draw matrix uniform");
	
	if _nodrawmatrix
	{
		c.Real("Alpha").DefineControl(self, "alpha").SetBounds(0, 1).valueprecision=3;
	}
	else
	{
		c.Real("Alpha").DefineControl(self, "alpha").SetBounds(0, 1).valueprecision=3;
		c.Real("Emission").DefineControl(self, "emission").SetBounds(0, 1)
			.Description("Amount that the natural color shows over the shading.")
			.valueprecision=3;
		c.Real("Specular").DefineControl(self, "shine").SetBounds(0, 1)
			.Description("Amount of \"shine\"")
			.valueprecision=3;
		c.Real("SSS").DefineControl(self, "sss").SetBounds(0, 1)
			.Description("Amount of red tint to shadows.\n(Not real Subsurface Scattering)")
			.valueprecision=3;
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
	
	for (var i = 0; i < vbx.vbcount; i++)
	{
		if string_pos("def", vbx.vbnames[i]) {meshtexture[i] = _tex_def;}
		if string_pos("skin", vbx.vbnames[i]) {meshtexture[i] = _tex_skin;}
		if string_pos("hair", vbx.vbnames[i]) {meshtexture[i] = _tex_hair;}
		if string_pos("brow", vbx.vbnames[i]) {meshtexture[i] = _tex_hair;}
	}
}

function LoadNormalTextures()
{
	var _tex_def_nor = sprite_get_texture(tex_curly_def_nor, 0);
	var i;
	
	for (var i = 0; i < vbx.vbcount; i++)
	{
		if string_pos("def", vbx.vbnames[i]) {meshnormalmap[i] = _tex_def_nor;}
	}
}
