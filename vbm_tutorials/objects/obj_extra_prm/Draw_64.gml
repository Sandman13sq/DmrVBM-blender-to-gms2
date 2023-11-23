/// @desc

draw_set_halign(0);
draw_set_valign(0);

var yy = 20;
draw_text(16, yy, trkanimator); yy += 16;
draw_text(16, yy, trkanimator.Layer(0).trkactive); yy += 16;
yy += 16;
draw_text(16, yy, "Press L to switch lighting mode: "+(lightmode? "View": "World")); yy += 16;
draw_text(16, yy, "Press SPACE to switch animation modes"); yy += 16;
draw_text(16, yy, "Animation Mode: " + (playbackmode==0? "Matrix": "Tracks")); yy += 16;
draw_text(16, yy, "Animation Position: " + string(trkanimator.Layer(0).animationposition)); yy += 16;
draw_text(16, yy, "Animation Frame: " + string(trkanimator.Layer(0).animationframe)); yy += 16;
draw_text(16, yy, "Use +/- to change transition blend"); yy += 16;
draw_text(16, yy, "Transition Blend: " + string(transitionblend)); yy += 16;
