/// @desc Draw info

draw_set_halign(0);
draw_set_valign(0);

draw_text(16, 16, "Use the arrow keys to move camera");
draw_text(16, 32, "Hold SHIFT and use arrow keys to rotate model");
draw_text(16, 64, "Camera Position: " + string(viewposition));
draw_text(16, 80, "Z Rotation: " + string(zrot));
draw_text(16, 112, "Press SPACE to toggle shader mode");
draw_text(16, 128, "Shader Mode: " + ((shadermode==0)? "Simple": "Normal") );
