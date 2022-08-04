/// @desc Initializing Variables

event_inherited();

// Load Vertex Buffers --------------------------------
vbm_kindle_prm = new VBMData();
vbm_kindle_prm.Open("assets/model_prm.vbm");

vbm_world.Clear();
vbm_world.Open("assets/world_lab_normal.vbm");

// Open TRK -------------------------------------------
trk_prm = new TRKData();
trk_prm.Open("assets/extra_prm.trk");

// Shader Uniforms
u_style_lightpos = shader_get_uniform(shd_style, "u_lightpos");

u_prm_lightpos = shader_get_uniform(shd_prm, "u_lightpos");
u_prm_matpose = shader_get_uniform(shd_prm, "u_matpose");
u_prm_skincolor = shader_get_uniform(shd_prm, "u_skincolor");
u_prm_skinparams = shader_get_uniform(shd_prm, "u_skinparams");
u_prm_transitionblend = shader_get_uniform(shd_prm, "u_transitionblend");

// For texture uniforms (sampler2D), use 'shader_get_sampler_index' instead of 'shader_get_uniform'
u_prm_col = shader_get_sampler_index(shd_prm, "u_tex_col");
u_prm_nor = shader_get_sampler_index(shd_prm, "u_tex_nor");
u_prm_prm = shader_get_sampler_index(shd_prm, "u_tex_prm");

// Normal Texture
spr_col = sprite_add("assets/kindle_col.png", 1, false, false, 0, 0);
spr_nor = sprite_add("assets/kindle_nor.png", 1, false, false, 0, 0);
spr_prm = sprite_add("assets/kindle_prm.png", 1, false, false, 0, 0);

tex_col = sprite_get_texture(spr_col, 0);
tex_nor = sprite_get_texture(spr_nor, 0);
tex_prm = sprite_get_texture(spr_prm, 0);

// Controls
localpose = Mat4Array(VBM_MATPOSEMAX);	// Array of matrices to be populated by EvaluateAnimationTracks()
matpose = Mat4ArrayFlat(VBM_MATPOSEMAX);	// Flat array of matrices to pass into the shader

// *Playback Controls ----------------------------------
playbackposition = 0;	// Current position of animation
playbackmode = 1; // 0 = Matrices, 1 = Tracks

skincolor = [1.0, 0.5, 0.5, 1.0]
skinparams = [0.5, 1.5, 1.0, 1.0]
transitionblend = 0;

event_perform(ev_step, 0);	// Force an update

for (var i = 0; i < vbm_kindle_prm.bonecount; i++)
{
	show_debug_message(vbm_kindle_prm.GetBoneName(i));
}
show_debug_message(vbm_kindle_prm.bonecount);
