/// @desc

// Inherit the parent event
event_inherited();

layout.Label("Simple VB");

layout.Bool("Use GM Default Shader").DefineControl(self, "use_gm_default_shader");

CommonLayout(false, false, true);

layout.FindElement("drawmatrix").active = true;
