/// @desc Initialize

model = new VBM_Model();
VBM_Model_Open(model, "demo_benchmark.vbm", VBM_OPENFLAG.PRINTDEBUG);

VBM_Model_AddTextureSprite(model, spr_texpoppie03);
var mtlindex = VBM_Model_AddMaterial(model, "", "", 0, VBM_MATERIALTEXTUREFLAG.FILTERLINEAR);
VBM_Model_MeshSetMaterialByLayer(model, VBM_LAYERMASKALL, mtlindex);

model_location = [0,0,0];
model_euler = [0,0,90];

animation = VBM_Model_GetAnimation(model, 0);
animation_mode = 1;
animation_index = 0;
animation_frame = 0;
animation_blend = 0;
animation_time_factor = 1.0;

bone_transforms = vbm_transform_identity_array_1d(200);
bone_particles = vbm_boneparticle_array_1d(200);
bone_matrices = vbm_mat4_identity_array_1d(200);
bone_skinning = vbm_mat4_identity_array_1d(200);

view_distance = 1.0;

mproj = matrix_build_identity();
mview = matrix_build_identity();
mtran = matrix_build_identity();
maxes = matrix_build_identity();

format = VBM_FormatBuild(VBM_FORMAT_NATIVE);

enum Benchmark {total, animation, transform, swing, skinning}
for (var i = 0; i < 5; i++) { // [current, average, sum, count]
	benchmark[i] = array_create(4);
}
benchmark_name = ["Total", "Animation", "Transform", "Swing", "Skinning"];
benchmark_color = [c_gray, c_blue, c_red, c_green, c_yellow];

event_perform(ev_step, 0);
event_perform(ev_step, ev_step_end);

