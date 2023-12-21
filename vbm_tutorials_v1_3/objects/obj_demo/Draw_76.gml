/// @description 

// Window Resize
if ( windowres[0] != window_get_width() || windowres[1] != window_get_height() )
{
	var w = window_get_width();
	var h = window_get_height();
	
	windowres[0] = w;
	windowres[1] = h;
	surface_resize(application_surface, w, h);
	display_set_gui_size(w, h);
	
	view_set_wport(view_current, w);
	view_set_hport(view_current, h);
	camera_set_view_size(camera_get_active(), w, h);
	
	room_width = w;
	room_height = h;
	
	camera_set_proj_mat(camera_get_active(), matrix_build_projection_ortho(w, h, 1, 1000));
}


