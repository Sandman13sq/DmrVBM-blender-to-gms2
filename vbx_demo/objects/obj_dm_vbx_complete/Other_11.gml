/// @desc Layout

// Inherit the parent event
event_inherited();

layout.Label("Complete VB (shd_complete)");

Panel_MeshSelect(layout);

Panel_Playback(layout);

Panel_Pose(layout);

CommonLayout(true, true, false);
