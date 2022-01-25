/// @desc 

var _w = window_get_width();
var _h = window_get_height();

draw_set_halign(fa_right);
draw_set_valign(fa_bottom);

draw_text(_w-16, _h-48, "Use number keys to navigate tutorials");
draw_text(_w-16, _h-32, tutorialnames[tutorialindex]);

draw_set_halign(fa_center);
var n = array_length(tutorialobjects);
var j = 0;
for (var i = n-1; i > 0; i--)
{
	draw_text(_w-16-(j*24), _h-16, (tutorialindex==i)? ("["+string(i)+"]"): string(i));
	j++;
}
