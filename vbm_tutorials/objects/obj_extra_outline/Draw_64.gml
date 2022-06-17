/// @desc

draw_set_halign(0);
draw_set_valign(0);

var i = 1;
draw_text(16, 16*i++, "Press L to switch lighting mode: "+(lightmode? "View": "World"));
draw_text(16, 16*i++, "Use +/- to change outline strength");
draw_text(16, 16*i++, "Outline Strength: " + string(outlinestrength));
