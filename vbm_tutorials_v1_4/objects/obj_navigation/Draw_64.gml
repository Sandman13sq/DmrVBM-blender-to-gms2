/// @description

draw_text(16, 20, "Navigate tutorials with Number Keys");
draw_text(16, 40, "Tutorial: ");

for (var i = 1; i < array_length(tutorials); i++) {
	draw_text(80+i*32, 40, (tutorial_index==i)? ("["+string(i)+"]"): " "+string(i));
}
