/// @desc 

draw_set_halign(0);
draw_set_valign(0);

var textarray = [
	"Camera Position: " + string(viewlocation),
	"Camera ZRot: " + string(viewzrot),
	"Camera XRot: " + string(viewxrot),
	"Mouse Anchor: " + string(mouseanchor),
];
var text = "";
for (var i = 0; i < array_length(textarray); i++)
{
	text += string(textarray[i]) + "\n";
}

draw_text(16, 16, report);

