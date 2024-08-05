/// @desc Draw camera position

draw_set_halign(fa_left);
draw_set_valign(fa_top);

draw_text(16, 100, "Use the arrow keys to move");
draw_text(16, 120, "Camera Position: " + string(viewposition));

