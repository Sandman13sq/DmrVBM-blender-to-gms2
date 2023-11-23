/// @desc Initializing Variables

event_inherited();

// Load Vertex Buffers --------------------------------
vbm_starcie_prm = new VBMData();
vbm_starcie_prm.Open("assets/starcie/model_prm.vbm");

vbm_world.Clear();
vbm_world.Open("assets/starcie/world_murasaki_normal.vbm");

// Open TRK -------------------------------------------
animations = OpenTRKDirectory("assets/starcie/");
animationkeys = variable_struct_get_names(animations);
array_sort(animationkeys, function(a, b) {return animations[$ a].Duration() > animations[$ b].Duration();});
animationindex = 0;

show_debug_message("> Loaded " + string(array_length(animationkeys)) + " animations");

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
spr_col = sprite_add("assets/starcie/starcie_col.png", 1, false, false, 0, 0);
spr_nor = sprite_add("assets/starcie/starcie_nor.png", 1, false, false, 0, 0);
spr_prm = sprite_add("assets/starcie/starcie_prm.png", 1, false, false, 0, 0);

tex_col = sprite_get_texture(spr_col, 0);
tex_nor = sprite_get_texture(spr_nor, 0);
tex_prm = sprite_get_texture(spr_prm, 0);

// Controls
trkanimator = new TRKAnimator().ReadTransformsFromVBM(vbm_starcie_prm);
trkanimator.CopyAnimations(animations);
trkanimator.AddLayer(TRKANIMATORLAYERFLAG.ignorecurves);
trkanimator.SetAnimationKey(animationkeys[animationindex]);

mattran = Mat4();

// *Playback Controls ----------------------------------
playbackmode = 1; // 0 = Matrices, 1 = Tracks

skincolor = [1.000000, 0.635530, 0.412623, 1.000000]
//skincolor = [1.0, 0.8138143387522769, 0.668758068807794, 1.0]
skinparams = [0.5, 1.5, 1.0, 1.0]
transitionblend = 0;

event_perform(ev_step, 0);	// Force an update
