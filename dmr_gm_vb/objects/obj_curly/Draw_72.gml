/// @desc Def Texture Surface

var _defsprite = tex_curly_def_col;

if !surface_exists(defsurf)
{
	defsurf = surface_create(
		sprite_get_width(_defsprite),
		sprite_get_height(_defsprite)
		);
	deftexture = surface_get_texture(defsurf);
	
	var _vbx = vbx_model, _me;
	for (var i = 0; i < _vbx.vbcount; i++)
	{
		_me = meshdata[i];
		_me.name = _vbx.vbnames[i];
		
		if string_pos("cloth", meshdata[i].name)
		|| string_pos("boot", meshdata[i].name)
		|| string_pos("_def", meshdata[i].name)
		{
			_me.texturediffuse = deftexture;
		}
	}
}

surface_set_target(defsurf)
{
	shader_set(shd_edit);
	
	shader_set_uniform_f(u_shd_edit_hue, lerp(0, 2*pi, hue));
	shader_set_uniform_f(u_shd_edit_sat, sat);
	shader_set_uniform_f(u_shd_edit_lum, lum);
	draw_sprite(tex_curly_def_col, 0, 0, 0);
	
	shader_reset();
}
surface_reset_target();

