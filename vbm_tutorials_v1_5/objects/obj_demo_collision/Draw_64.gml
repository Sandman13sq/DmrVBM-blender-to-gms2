/// @desc Draw camera position
draw_set_halign(fa_left);
draw_set_valign(fa_top);

var _ystart = 96;
var xx = 16, yy = _ystart, ysep = 16;

// Left Info
draw_text(xx, yy, "Use WASD to move Poppie"); yy += ysep;	// TODO: Is this English keyboard only?
draw_text(xx, yy, "Hold E and Q to rotate camera"); yy += ysep;
draw_text(xx, yy, "Press \"<\",\">\" to navigate meshes"); yy += ysep;
draw_text(xx, yy, "Press ? to toggle mesh visibility"); yy += ysep;
draw_text(xx, yy, "Press \"[\",\"]\" to highlight bone"); yy += ysep;
draw_text(xx, yy, "Press \"-\",\"+\" to navigate animations"); yy += ysep;
yy += ysep;

// Info on right
var _mcamera = matrix_inverse(matview);

xx = surface_get_width(application_surface)-240;
yy = _ystart;
draw_text(xx, yy, "ViewDistance: " + string(view_distance)); yy += ysep;
draw_text(xx, yy, "ViewDir: " + string([_mcamera[VBM_M02], _mcamera[VBM_M12], _mcamera[VBM_M22]])); yy += ysep;
draw_text(xx, yy, "ViewPos: " + string([_mcamera[VBM_M03], _mcamera[VBM_M13], _mcamera[VBM_M23]])); yy += ysep;

var e;
for (var i = 0; i < array_length(entitylist); i++) {
	e = entitylist[i];
	if ( e == 0 ) {continue;}
	
	draw_text(xx, yy, string([e.model.name, e.animation_key]));
	yy += ysep;
}

yy += ysep;
