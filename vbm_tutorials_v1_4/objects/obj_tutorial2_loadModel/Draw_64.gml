/// @desc Draw camera position

draw_set_halign(fa_left);
draw_set_valign(fa_top);

draw_text(16, 100, "Use the arrow keys to move");
draw_text(16, 120, "Press space to toggle yflip for Projection Matrix");
draw_text(16, 140, "Camera Position: " + string(viewposition));
draw_text(16, 160, "YFlip: " + (yflip? "On": "Off"));

draw_text(16, 200, @"
In Blender, X points Right, Y points up, and Z points towards camera
Depending on your device, Y may be inverted
A fast way to correct this is to negate both 
the field of view and aspect ratio of the Projection Matrix
"
);

