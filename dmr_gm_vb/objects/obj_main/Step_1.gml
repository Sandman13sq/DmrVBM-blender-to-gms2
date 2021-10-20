/// @desc

if keyboard_check(vk_tab)
{
	if keyboard_check_pressed(ord("R"))
	{
		game_restart();	
	}
}

if keyboard_check_pressed(vk_f4)
{
	window_set_fullscreen(!window_get_fullscreen());
}

if keyboard_check_pressed(vk_escape)
{
	window_set_fullscreen(false);
}


