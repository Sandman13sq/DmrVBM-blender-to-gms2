/// @desc Initializing Variables

event_inherited();

// Load Vertex Buffers --------------------------------
vbm_curly_outline = new VBMData();
vbm_curly_outline.Open("extra/curly_outline.vbm");

vbm_world.Clear();
vbm_world.Open("extra/world_sand.vbm");

// Shader Uniforms
u_outline_lightpos = shader_get_uniform(shd_outline, "u_lightpos");
u_outline_outline = shader_get_uniform(shd_outline, "u_outline");

outlinestrength = 0.5;

event_perform(ev_step, 0);	// Force an update
