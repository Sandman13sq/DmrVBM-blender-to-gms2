/// @desc Initializing Variables

event_inherited();

// Load Vertex Buffers --------------------------------
vbm_kindle_outline = new VBMData();
vbm_kindle_outline.Open("assets/model_outline.vbm");

vbm_world.Clear();
vbm_world.Open("assets/world_lab_normal.vbm");

// Shader Uniforms
u_style_lightpos = shader_get_uniform(shd_style, "u_lightpos");

u_outline_lightpos = shader_get_uniform(shd_outline, "u_lightpos");
u_outline_outline = shader_get_uniform(shd_outline, "u_outline");

outlinestrength = 0.3;

event_perform(ev_step, 0);	// Force an update
