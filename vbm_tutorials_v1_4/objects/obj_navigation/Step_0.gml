/// @description

var _tutlast = tutorial_index;

for (var i = 1; i < array_length(tutorials); i++) {
	if ( keyboard_check_pressed(ord("0") + i) ) {
		tutorial_index = i;
	}
}

if ( keyboard_check_pressed(vk_f4) ) {
	window_set_fullscreen(!window_get_fullscreen());
}

if ( keyboard_check_pressed(vk_escape) ) {
	if ( window_get_fullscreen() ) {
		window_set_fullscreen(false);
	}
}

if (_tutlast != tutorial_index) {
	instance_destroy(tutorial_inst);
	tutorial_inst = instance_create_depth(0,0,0, tutorials[tutorial_index]);
	
	show_debug_message("Tutorial " + string(tutorial_index) + ": " + object_get_name(tutorials[tutorial_index]));
}

