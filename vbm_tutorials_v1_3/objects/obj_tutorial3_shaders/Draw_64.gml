/// @desc Draw info

draw_set_halign(0);
draw_set_valign(0);

draw_text(16, 100, "Use the arrow keys to move camera");
draw_text(16, 120, "Hold SHIFT and use arrow keys to rotate model");
draw_text(16, 140, "Camera Position: " + string(viewposition));
draw_text(16, 160, "Z Rotation: " + string(zrot));
draw_text(16, 180, "Press SPACE to toggle shader mode");
draw_text(16, 200, "Shader Mode: " + ((shadermode==0)? "Simple": "Normal") );
