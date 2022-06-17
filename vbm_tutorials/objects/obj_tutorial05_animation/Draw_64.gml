/// @desc Draw mesh visiblity

draw_set_halign(0);
draw_set_valign(0);

draw_text(16, 16, "Use the arrow keys to move camera");
draw_text(16, 32, "Hold SHIFT and use arrow keys to rotate model");
draw_text(16, 64, "Camera Position: " + string(viewposition));
draw_text(16, 80, "Z Rotation: " + string(zrot));
draw_text(16, 112, "Press SPACE to switch animation modes");
draw_text(16, 128, "Animation Mode: " + (playbackmode==0? "Matrix": "Tracks"));
draw_text(16, 144, "Animation Position: " + string(playbackposition));
draw_text(16, 160, "Animation Frame: " + string(playbackposition*trk_wave.FrameCount()));
