/// @description

if ( 
	surface_get_width(application_surface) != window_get_width() ||
	surface_get_height(application_surface) != window_get_height() 
) {
	surface_resize(application_surface, window_get_width(), window_get_height());
	display_set_gui_size(window_get_width(), window_get_height());
	
	view_set_wport(view_current, window_get_width());
	view_set_hport(view_current, window_get_height());
	camera_set_view_size(camera_get_active(), window_get_width(), window_get_height());
	
	room_width = window_get_width();
	room_height = window_get_height();
}

draw_set_font(dmrfont);
