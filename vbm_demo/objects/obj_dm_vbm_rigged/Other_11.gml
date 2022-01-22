/// @desc Layout

// Inherit the parent event
event_inherited();

layout.Label("Rigged VB (shd_rigged)");

Panel_MeshSelect(layout);

Panel_Playback(layout);

CommonLayout(true, false, false);
