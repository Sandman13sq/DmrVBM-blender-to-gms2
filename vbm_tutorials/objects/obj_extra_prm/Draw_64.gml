/// @desc

draw_set_halign(0);
draw_set_valign(0);

var i = 0;
draw_text(16, 16*i++, "Press L to switch lighting mode: "+(lightmode? "View": "World"));
draw_text(16, 16*i++, "Press SPACE to switch animation modes");
draw_text(16, 16*i++, "Animation Mode: " + (playbackmode==0? "Matrix": "Tracks"));
draw_text(16, 16*i++, "Animation Position: " + string(trkanimator.Layer(0).animationposition));
draw_text(16, 16*i++, "Animation Frame: " + string(trkanimator.Layer(0).animationframe));
draw_text(16, 16*i++, "Use +/- to change transition blend");
draw_text(16, 16*i++, "Transition Blend: " + string(transitionblend));
