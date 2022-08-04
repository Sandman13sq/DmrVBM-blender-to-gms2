/// @desc Initializing Variables

event_inherited();

// Load Vertex Buffers --------------------------------
vbm_kindle_normalmap = new VBMData();
vbm_kindle_normalmap.Open("assets/model_normalmap.vbm");

vbm_world.Clear();
vbm_world.Open("assets/world_lab_normalmap.vbm");

// Shader Uniforms
// For texture uniforms (sampler2D), use 'shader_get_sampler_index' instead of 'shader_get_uniform'
u_normalmap_lightpos = shader_get_uniform(shd_normalmap, "u_lightpos");

// Normal Texture
spr_normalmap = sprite_add("assets/kindle_nor.png", 1, false, false, 0, 0);
tex_normalmap = sprite_get_texture(spr_normalmap, 0);

event_perform(ev_step, 0);	// Force an update
