/// @description Navigation Text

// Demos
if ( demo_mode ) {
	draw_text(16, 20, "Navigate demos with Number Keys | Press 0 for Tutorials");
	draw_text(16, 40, "Demo: ");

	var _name = "";
	for (var i = 1; i < array_length(demos); i++) {
		_name = variable_struct_get(demos[i], "name");
		if ( is_undefined(_name) ) {
			_name = object_get_name(demos[i]);
		}
		draw_text(80+(i-1)*200, 40, (tutorial_index==i)? ("["+_name+"]"): " "+_name);
	}
}
// Tutorials
else {
	draw_text(16, 20, "Navigate tutorials with Number Keys | Press 0 for Demos");
	draw_text(16, 40, "Tutorial: ");

	for (var i = 1; i < array_length(tutorials); i++) {
		draw_text(80+i*32, 40, (tutorial_index==i)? ("["+string(i)+"]"): " "+string(i));
	}
}