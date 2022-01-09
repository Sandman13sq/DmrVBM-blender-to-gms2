/// @desc Layout

// Inherit the parent event
event_inherited();

layout.Label("Normal VB (shd_normalmap)");

var l = layout.Dropdown("Meshes");
l.active = true;
for (var i = 0; i < vbx.vbcount; i++)
{
	l.Bool(vbx.vbnames[i]).DefineControl(self, "meshvisible", i);
}

CommonLayout(true, true, false);
