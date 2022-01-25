/// @desc Fullscreen + Debug

// Game restart
if ( keyboard_check(vk_tab) )
{
	if ( keyboard_check_pressed(ord("R")) )
	{
		game_restart();	
		return;
	}
}

// Toggle fullscreen
if ( keyboard_check_pressed(vk_f4) )
{
	window_set_fullscreen(!window_get_fullscreen());
}

if ( keyboard_check_pressed(vk_escape) )
{
	window_set_fullscreen(false);
}

// Check if window size changed
if (
	window_get_width() != lastwindowsize[0] || 
	window_get_height() != lastwindowsize[1] ||
	lastfullscreen != window_get_fullscreen()
	)
&& (window_get_width() > 0 && window_get_height() > 0)
{
	surface_resize(application_surface, window_get_width(), window_get_height());
	with all {event_perform(ev_draw, 65);}
}
