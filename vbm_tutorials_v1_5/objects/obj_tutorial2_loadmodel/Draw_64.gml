/// @desc Draw camera position

draw_set_halign(fa_left);
draw_set_valign(fa_top);

draw_text(16, 100, "Use the arrow keys to move");
draw_text(16, 120, "Press space to toggle yflip for Projection Matrix");
draw_text(16, 140, "Camera Position: " + string(view_position));
draw_text(16, 160, "YFlip: " + (yflip? "On": "Off"));

draw_text(16, 200, @"
Blender coordinate system is: 
    Right =     +X 
    Up =        +Y 
    Forward = -Z (into the screen, away from camera)
Depending on your device, Y may be inverted.
A fast way to correct this is to negate
the aspect ratio of the Projection Matrix.
"
);

