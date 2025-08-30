/// @description Navigate Tutorial

// Toggle Fullscreen
if ( keyboard_check_pressed(vk_f11) ) {
	window_set_fullscreen(!window_get_fullscreen());
}

// Exit fullscreen
if ( keyboard_check_pressed(vk_escape) ) {
	if ( window_get_fullscreen() ) {
		window_set_fullscreen(false);
	}
}

// Switch tutorial
if ( keyboard_check_pressed(ord("0")) ) {
	demo_mode ^= 1;
}

var _change_tutorial = 0;
for (var i = 1; i < array_length(tutorials); i++) {
	if ( keyboard_check_pressed(ord("0") + i) ) {
		tutorial_index = i;
		_change_tutorial = 1;
	}
}

if ( _change_tutorial ) {
	instance_destroy(tutorial_inst);
	if ( demo_mode ) {
		if ( tutorial_index < array_length(demos) ) {
			tutorial_inst = instance_create_depth(0,0,0, demos[tutorial_index]);
			show_debug_message("Demo " + string(tutorial_index) + ": " + object_get_name(demos[tutorial_index]));
		}
	}
	else {
		tutorial_inst = instance_create_depth(0,0,0, tutorials[tutorial_index]);
		show_debug_message("Tutorial " + string(tutorial_index) + ": " + object_get_name(tutorials[tutorial_index]));
	}
	
	
}

