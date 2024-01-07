/// @desc

draw_text(16, 16, "Navigate tutorials with Number Keys");
draw_text(16, 32, "Tutorial:");

for (var i = 1; i < array_length(tutorials); i++)
{
	draw_text(80 + i*32, 32, (tutorialindex == i)? ("["+string(i)+"]"): " "+string(i));
}