/// @desc Draw camera position

draw_set_halign(fa_left);
draw_set_valign(fa_top);

var yy = 100;
draw_text(16, yy, "Use the arrow keys to move"); yy += 20;
draw_text(16, yy, "Model Position: " + string([x,y,0])); yy += 20;
draw_text(16, yy, "Model Rotation: " + string(zrot)); yy += 20;
yy += 20;
draw_text(16, yy, "Camera Position: " + string(viewposition)); yy += 20;
draw_text(16, yy, "Camera Rotation: " + string(viewhrot)); yy += 20;

