/// @description Window Resize

var ww = window_get_width(), hh = window_get_height();
if ( 
	(ww > 0 && hh > 0) &&	// Prevent crash on minimize
	(surface_get_width(application_surface) != ww || surface_get_height(application_surface) != hh)
) {
	surface_resize(application_surface, ww, hh);
	display_set_gui_size(ww, hh);
	
	view_set_wport(view_current, ww);
	view_set_hport(view_current, hh);
	camera_set_view_size(camera_get_active(), ww, hh);
	
	room_width = ww;
	room_height = hh;
}

draw_set_font(dmrfont);
