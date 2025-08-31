/// @desc Initialization

function Entity(_entity_type="", _model=undefined) constructor {
	type = _entity_type;
	model = _model;
	
	location = [0,0,0];
	velocity = [0,0,0];
	euler = [0,0,0];
	matrix = matrix_build_identity();
	radius = 1;
	
	shadow_z = 0.0;
	shadw_normal = [0,0,0];
	
	animation_key = "";
	animation_frame = 0;
	animation_blend = 0;
	
	bone_transforms = vbm_transform_identity_array_1d(VBM_BONELIMIT);
	bone_transforms_last = vbm_transform_identity_array_1d(VBM_BONELIMIT);
	bone_particles = vbm_boneparticle_array_1d(VBM_BONELIMIT);
	bone_matrices = vbm_mat4_identity_array_1d(VBM_BONELIMIT);
	bone_skinning = vbm_mat4_identity_array_1d(VBM_BONELIMIT);
};

// Models -------------------------------------------
model_player = VBM_Model_Create();
VBM_Model_Open(model_player, "tutorial4_animation.vbm");

model_level = VBM_Model_Create();
VBM_Model_Open(model_level, "tutorial5_level.vbm");

model_shadow = VBM_Model_Create();
VBM_Model_Open(model_shadow, "tutorial5_shadow.vbm");

// Camera -------------------------------------------
view_location = [0,0,0];
view_location_intermediate = [0,0,0];
view_location_offset = [0,0,1];
view_euler = [45,0,0];
view_euler_intermediate = [45,0,0];
view_distance = 10;
view_distance_intermediate = view_distance;
view_distance_limits = [2, 100];

matproj = matrix_build_identity();
matview = matrix_build_identity();

// Entities ------------------------------------------
entitylist = array_create(16);

player = new Entity("player", model_player);
array_push(entitylist, player);

var _spawnboneindex = VBM_Model_FindBoneIndex(model_level, "spawn");
VBM_Model_BoneGetLocationBind(model_level, _spawnboneindex, player.location);

array_copy(view_location, 0, player.location, 0, 3);
array_copy(view_location_intermediate, 0, player.location, 0, 3);

