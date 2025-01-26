// Script assets have changed for v2.3.0 see
// https://help.yoyogames.com/hc/en-us/articles/360005277377 for more information

/*
	GM Matrix Index Reference:
	[
		0,	4,	8, 12,	|	(x)
		1,	5,	9, 13,	|	(y)
		2,	6, 10, 14,	|	(z)
		3,	7, 11, 15,	|	(w)
	]
*/

#region // Static ===================================================================

#macro VBM_PROJECTPATH global.__vbm_projectpath
VBM_PROJECTPATH = "";

// Limit on v2022 LTS is 128...?
#macro VBM_BONELIMIT 192
#macro VBM_BONECAPACITY 192
#macro VBM_CURVECAPACITY 160
#macro VBM_CHANNELCAPACITY 2048

// M[Y][X]
#macro VBM_M00 0
#macro VBM_M10 1
#macro VBM_M20 2
#macro VBM_M30 3
#macro VBM_M01 4
#macro VBM_M11 5
#macro VBM_M21 6
#macro VBM_M31 7
#macro VBM_M02 8
#macro VBM_M12 9
#macro VBM_M22 10
#macro VBM_M32 11
#macro VBM_M03 12
#macro VBM_M13 13
#macro VBM_M23 14
#macro VBM_M33 15

#macro VBM_T_LOCX 0
#macro VBM_T_LOCY 1
#macro VBM_T_LOCZ 2
#macro VBM_T_QUATW 3
#macro VBM_T_QUATX 4
#macro VBM_T_QUATY 5
#macro VBM_T_QUATZ 6
#macro VBM_T_SCALEX 7
#macro VBM_T_SCALEY 8
#macro VBM_T_SCALEZ 9

#macro VBM_SUBMIT_TEXDEFAULT -1
#macro VBM_SUBMIT_TEXNONE 0

enum VBM_OPENFLAGS {
	NOFREEZE = 1<<0,
	MERGE = 1<<1,
	ALL_EDGES = 1<<2,
	NO_ANIMCURVES = 1<<3,
	BAKE_TRANSFORM = 1<<4,
	BAKE_LOCAL = 1<<5,
}

enum VBM_ATTRIBUTE {
	PADDING, POSITION, COLOR, UV, NORMAL, 
	TANGENT, BITANGENT, BONE, WEIGHT, GROUP,
	
	SIZE_1 = 1<<4, SIZE_2 = 2<<4, SIZE_3 = 3<<4, SIZE_4 = 4<<4,
	IS_BYTE = 1<<7,
}

enum VBM_MESHFLAGS {
	IS_EDGE = 1<<0
}

enum VBM_SWINGFLAGS {
	DISTANCE = 1<<0,
}

enum VBM_BONESEGMENT {
	head_x, head_y, head_z, tail_x, tail_y, tail_z, roll, length
}

function VBM_StringHash(s) {
	// Djb2 hash by Dan Bernstein
	var value = 5381;
	var n = string_length(s);
	var i = 1;
	repeat(n) {value = (value * 33 + string_ord_at(s, i)) & 0xffffff; i++;}
	return value;
}

// Returns new single array for matrix values
function VBM_CreateMatrixArrayFlat(n) {
	n = min(n, VBM_BONELIMIT);
	var outmat4arrayflat = array_create(n*16);
	
	// Write identity
	outmat4arrayflat[@ 0] = 1.0; outmat4arrayflat[@ 1] = 0.0; outmat4arrayflat[@ 2] = 0.0; outmat4arrayflat[@ 3] = 0.0;
	outmat4arrayflat[@ 4] = 0.0; outmat4arrayflat[@ 5] = 1.0; outmat4arrayflat[@ 6] = 0.0; outmat4arrayflat[@ 7] = 0.0;
	outmat4arrayflat[@ 8] = 0.0; outmat4arrayflat[@ 9] = 0.0; outmat4arrayflat[@10] = 1.0; outmat4arrayflat[@11] = 0.0;
	outmat4arrayflat[@12] = 0.0; outmat4arrayflat[@13] = 0.0; outmat4arrayflat[@14] = 0.0; outmat4arrayflat[@15] = 1.0;

	// Fill in steps of base 2
	var p = 1;
	while ( (p<<1) < n) {
		array_copy(outmat4arrayflat, 16*p, outmat4arrayflat, 0, 16*p);
		p = p << 1;	// p = 2^i
	}
	array_copy(outmat4arrayflat, (n-p)*16, outmat4arrayflat, 0, 16*p);	// Last power of 2 to n
	
	return outmat4arrayflat;
}

// Returns new array of matrices
function VBM_CreateMatrixArrayPartitioned(n) {
	var outmat4array = array_create(n);
	for (var i = 0; i < n; i++) {
		outmat4array = matrix_build_identity();
	}
	return outmat4array;
}

#endregion // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#region // Model Elements ===========================================================

// Mesh ......................................................................
function VBM_Mesh() constructor {
	name = "";
	vertex_buffer = -1;	// Used in drawing
	is_edge = 0;	// 
	format = -1;	// Used when creating buffer
	formatkey = array_create(8);	// Represents buffer
	texture_sprite = -1;	// Fallback for texture
	texture_override = -1;	// Used instead of sprite if set
	material_index = -1;	// Index to material in model
	bounds_min = [0,0,0];
	bounds_max = [0,0,0];
	
	function toString() {
		return "{VBMMesh " + name 
			+ " sprite " + string(texture_override? texture_override: texture_sprite) 
			+ " format " + string(formatkey) 
			+ "}";
	}
}

// Skeleton ...................................................................
function VBM_SkeletonSwingBone() constructor {
	gravity = 0;
	friction = 0;
	stiffness = 0;
	dampness = 0;
	offset = [0,0,0];
	angle_range_x = [0,0];
	angle_range_z = [0,0];
	flags = VBM_SWINGFLAGS.DISTANCE;
}

function VBM_SkeletonColliderBone() constructor {
	radius = 0;
	length = 0;
	offset = [0,0,0];
}

function VBM_Skeleton() constructor {
	name = "";
	bone_names = array_create(VBM_BONECAPACITY, "");
	bone_hashes = array_create(VBM_BONECAPACITY, 0);
	bone_nametoindex = {};
	bone_segments = array_create(VBM_BONECAPACITY);	// [ [headx, y, z, tailx, y, z, roll, length] ]
	bone_parentindex = array_create(VBM_BONECAPACITY);
	bone_swingindex = array_create(VBM_BONECAPACITY);
	bone_colliderindex = array_create(VBM_BONECAPACITY);
	
	bone_matlocal = array_create(VBM_BONECAPACITY);	// mat4[]
	bone_matinverse = array_create(VBM_BONECAPACITY);	// mat4[]
	bone_count = 0;
	
	swing_bones = [];	// Array of VBM_SkeletonSwingBone
	swing_count = 0;
	collider_bones = [];	// Array of VBM_SkeletonColliderBone
	collider_count = 0;
	
	function toString() {
		return "{VBMSkeleton " + name 
			+ " bones " + string(bone_count) 
			+ " swing " + string(swing_count) 
			+ " colliders " + string(collider_count) 
			+ "}";
	}
}

#endregion // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#region // Animation ================================================================

function VBM_Animation() constructor {
	name = "";
	flags = 0;
	curve_count = 0;
	duration = 0;
	native_fps = 60;
	
	curve_names = array_create(VBM_CURVECAPACITY);
	curve_namehashes = array_create(VBM_CURVECAPACITY);
	
	curve_views = array_create(VBM_CURVECAPACITY*2);	// [ channel_offset, channel_count, ... ]
	animcurve = -1;	// Single animcurve containing all channels for animation
	
	baked_transforms = [];
	baked_local = [];	// Array of array of flat matrices for each frame of animation
	baked_final = [];
	
	function toString() {
		return "{VBMAnimation " + name 
			+ " duration " + string_format(duration, 2, 2) 
			+ " fps" + string_format(native_fps, 2, 2) 
			+ " curves " + string(curve_count)
			+ " baked [" + (
				(array_length(baked_transforms)? "T": " ") + 
				(array_length(baked_local)? "L": " ") + 
				(array_length(baked_final)? "F": " ")
			) + "]"
			+ "}";
	}
}

function VBM_Animation_Free(animation) {
	if ( animation.animcurve ) {
		animcurve_destroy(animation.animcurve);
		animation.animcurve = -1;
	}
}

function VBM_Animation_Copy(animation_dest, animation_src) {
	if ( is_undefined(animation_src) ) {
		return;
	}
	
	// Copy metadata
	animation_dest.name = animation_src.name;
	animation_dest.flags = animation_src.flags;
	animation_dest.curve_count = animation_src.curve_count;
	animation_dest.duration = animation_src.duration;
	animation_dest.native_fps = animation_src.native_fps;
	
	// Copy arrays
	array_copy(animation_dest.curve_names, 0, animation_src.curve_names, 0, VBM_CURVECAPACITY);
	array_copy(animation_dest.curve_namehashes, 0, animation_src.curve_namehashes, 0, VBM_CURVECAPACITY);
	array_copy(animation_dest.curve_views, 0, animation_src.curve_views, 0, array_length(animation_src.curve_views));
	
	array_copy(animation_dest.baked_transforms, 0, animation_src.baked_transforms, 0, array_length(animation_src.baked_transforms));
	array_copy(animation_dest.baked_local, 0, animation_src.baked_local, 0, array_length(animation_src.baked_local));
	array_copy(animation_dest.baked_final, 0, animation_src.baked_final, 0, array_length(animation_src.baked_final));
	
	// Copy animcurve
	if ( animation_src.animcurve != -1 ) {
		if ( animation_dest.animcurve == -1 ) {
			animation_dest.animcurve = animcurve_create();
		}
		
		var srccurve = animcurve_get(animation_src.animcurve);
		var dstcurve = animcurve_get(animation_dest.animcurve);
		var srcchannel, dstchannel;
		var psrc, pdst;
		var numchannels, numkeyframes;
		
		numchannels = array_length(srccurve.channels);
		var dstchannels = array_create(numchannels);
		var dstpoints;
		var channel_offset = 0, i;
		
		// Iterate channels
		repeat(numchannels) {
			srcchannel = srccurve.channels[channel_offset];
			dstchannel = animcurve_channel_new();
			
			numkeyframes = array_length(srcchannel.points);
			dstpoints = array_create(numkeyframes);
			// Iterate keyframes
			i = 0; repeat(numkeyframes) {
				psrc = srcchannel.points[i];
				pdst = animcurve_point_new();
				pdst.posx = psrc.posx;
				pdst.value = psrc.value;
				dstpoints[i] = pdst;
				i++;
			}
			dstchannel.points = dstpoints;
			dstchannel.type = animcurvetype_linear;
			dstchannel.name = srcchannel.name;
			dstchannels[channel_offset] = dstchannel;
			channel_offset++;
		}
		dstcurve.channels = dstchannels;
		dstcurve.name = srccurve.name;
	}
}

function VBM_Animation_Duplicate(animation_src) {
	var animation_dest = new VBM_Animation();
	VBM_Animation_Copy(animation_dest, animation_src);
	return animation_dest;
}

function VBM_Animation_SampleCurveSingle(animation, frame, curve_name, channel_index, default_value) {
	if (!animation) {return default_value;}
	
	var numcurves = animation.curve_count;
	var curve_index, channel_count;
	var curve_views = animation.curve_views;
	
	frame = (animation.duration > 0)? frame mod animation.duration: 1;
	var pos = frame / max(1.0, animation.duration);
	
	// Find curve_index
	curve_index = 0;
	while (curve_index < numcurves) {
		if ( animation.curve_names[curve_index] == curve_name ) {
			break;
		}
		curve_index++;
	}
	
	channel_count = curve_views[curve_index*2+1];
	
	if (channel_index >= channel_count) {
		return default_value;
	}
	
	channel_index = channel_index + curve_views[curve_index*2+0];
	
	var animchannel = animcurve_get_channel(animation.animcurve, channel_index);
	return animcurve_channel_evaluate(animchannel, pos);
}

function VBM_Animation_SampleCurveVector(animation, frame, curve_name, outvector) {
	if (!animation) {return 0;}
	
	var numcurves = animation.curve_count;
	var curve_index, channel_index, channel_count;
	var curve_views = animation.curve_views;
	
	frame = (animation.duration > 0)? frame mod animation.duration: 1;
	var pos = frame / max(1.0, animation.duration);
	
	// Find curve_index
	curve_index = 0;
	while (curve_index < numcurves) {
		if ( animation.curve_names[curve_index] == curve_name ) {
			break;
		}
		curve_index++;
	}
	
	if ( curve_index == numcurves ) {return 0;}
	
	channel_index = curve_views[curve_index*2+0];
	channel_count = curve_views[curve_index*2+1];
	curve_name = animation.curve_names[curve_index];
	
	// For each channel
	var animchannel;
	repeat(channel_count) {
		// Write value
		animchannel = animcurve_get_channel(animation.animcurve, channel_index);
		outvector[@ channel_index] = animcurve_channel_evaluate(animchannel, pos);
		channel_index++;
	}
	
	return 1;
}

function VBM_Animation_SampleCurves(animation, frame, outstruct) {
	if (!animation) {return;}
	
	var numcurves = animation.curve_count;
	var curve_views = animation.curve_views;
	
	frame = (animation.duration > 0)? frame mod animation.duration: 1;
	var pos = frame / max(1.0, animation.duration);
	var curve_index = 0, channel_index;
	var channel_count, channel_offset;
	var curve_name;
	var animchannel;
	
	repeat(numcurves) {
		channel_offset = curve_views[curve_index*2+0];
		channel_count = curve_views[curve_index*2+1];
		
		curve_name = animation.curve_names[curve_index];
		if ( !variable_struct_exists(outstruct, curve_name) ) {
			outstruct[$ curve_name] = array_create(channel_count);
		}
		
		// For each channel
		repeat(channel_count) {
			// Write value
			animchannel = animcurve_get_channel(animation.animcurve, channel_offset+channel_index);
			outstruct[$ curve_name][channel_index] = animcurve_channel_evaluate(animchannel, pos);;
			channel_index++;
		}
		
		curve_index++;
	}
}

function VBM_Animation_SampleBoneTransforms(animation, frame, bonehashes, outtransforms, stride) {
	var bone_count = array_length(bonehashes);
	var curvehashes = animation.curve_namehashes;
	
	frame = (animation.duration > 0)? frame mod (animation.duration): 1;
	var pos = frame / max(1.0, animation.duration);
	var curvenamehash;
	var bone_index = 0, curve_index = 0;
	var bone_found;
	var channel_offset, transform_index;
	var animchannel;
	var use_animcurves = animcurve_exists(animation.animcurve);
	
	// Use baked transforms
	if ( array_length(animation.baked_transforms) > 0 ) {
		repeat(numbonecurves) {
			// Map curve to boneindex
			curvenamehash = curvehashes[curve_index];
			repeat(bone_count) {
				if (curvenamehash == bonehashes[bone_index]) {
					array_copy(outtransforms, bone_index*stride, animation.baked_transforms[frame], curve_index*10, 10);
					break;	// Break when bonename == curvename
				}
				bone_index = (bone_index+1) mod bone_count;	// Loop bone index (keep progress from last curve)
			}
			curve_index++;
		}
	}
	// Use GM Animation curve
	else if ( use_animcurves ) {
		var numbonecurves = animation.curve_count;
		var curve_views = animation.curve_views;
		var curve_size;
		var bone_found;
		
		repeat(numbonecurves) {
			// Map curve to boneindex
			bone_found = false;
			curvenamehash = curvehashes[curve_index];
			repeat(bone_count) {
				if (curvenamehash == bonehashes[bone_index]) {bone_found = true; break;}	// Break when bonename == curvename
				bone_index = (bone_index+1) mod bone_count;	// Loop bone index (keep progress from last curve)
			}
			
			// Bone found
			if (bone_found) {
				channel_offset = curve_views[curve_index*2+0];
				curve_size = curve_views[curve_index*2+1];
				transform_index = 0;
				
				repeat(curve_size) {
					animchannel = animcurve_get_channel(animation.animcurve, channel_offset+transform_index);
					outtransforms[@ bone_index*stride + transform_index] = animcurve_channel_evaluate(animchannel, pos);
					
					transform_index++;
				}
			}
			curve_index++;
		}
	}
}

function VBM_Animation_BlendBoneTransforms(animation, frame, bonehashes, outtransforms, stride, last_transforms, blend_amt) {
	var bone_count = array_length(bonehashes);
	var curvehashes = animation.curve_namehashes;
	
	frame = (animation.duration > 0)? frame mod (animation.duration): 1;
	var pos = frame / max(1.0, animation.duration);
	var curvenamehash;
	var bone_index = 0, curve_index = 0;
	var bone_found;
	var channel_offset, transform_index;
	var animchannel;
	var use_animcurves = animcurve_exists(animation.animcurve);
	
	// Use baked transforms
	if ( array_length(animation.baked_transforms) > 0 ) {
		repeat(numbonecurves) {
			// Map curve to boneindex
			curvenamehash = curvehashes[curve_index];
			repeat(bone_count) {
				if (curvenamehash == bonehashes[bone_index]) {
					array_copy(outtransforms, bone_index*stride, animation.baked_transforms[frame], curve_index*10, 10);
					break;	// Break when bonename == curvename
				}
				bone_index = (bone_index+1) mod bone_count;	// Loop bone index (keep progress from last curve)
			}
			curve_index++;
		}
	}
	// Use GM Animation curve
	else if ( use_animcurves ) {
		var numbonecurves = animation.curve_count;
		var curve_views = animation.curve_views;
		var curve_size;
		var bone_found;
		var transform_offset;
		
		repeat(numbonecurves) {
			// Map curve to boneindex
			bone_found = false;
			curvenamehash = curvehashes[curve_index];
			repeat(bone_count) {
				if (curvenamehash == bonehashes[bone_index]) {bone_found = true; break;}	// Break when bonename == curvename
				bone_index = (bone_index+1) mod bone_count;	// Loop bone index (keep progress from last curve)
			}
			
			// Bone found
			if (bone_found) {
				channel_offset = curve_views[curve_index*2+0];
				curve_size = curve_views[curve_index*2+1];
				transform_index = 0;
				transform_offset = bone_index*stride;
				
				array_copy(last_transforms, transform_offset, outtransforms, transform_offset, stride);
				
				repeat(curve_size) {
					animchannel = animcurve_get_channel(animation.animcurve, channel_offset+transform_index);
					outtransforms[@ transform_offset + transform_index] = animcurve_channel_evaluate(animchannel, pos);
					
					transform_index++;
				}
				
				__vbm_transformblend(outtransforms, transform_offset, last_transforms, transform_offset, outtransforms, transform_offset, blend_amt);
			}
			curve_index++;
		}
	}
}

function VBM_Animation_BakeAnimationTransforms(animation) {
	var duration = animation.duration;
	var transforms;
	var baked = array_create(duration);
	animation.baked_transforms = [];
	for (var frame = 0; frame < duration; frame++) {
		transforms = array_create(VBM_BONECAPACITY*10);
		VBM_Animation_SampleBoneTransforms(animation, frame, animation.curve_namehashes, transforms, 10);
		baked[frame] = transforms;
	}
	animation.baked_transforms = baked;
}

function VBM_Animation_BakeAnimationLocal(animation) {
	var duration = animation.duration;
	var transforms = array_create(VBM_BONECAPACITY*10);
	var baked = array_create(duration);
	var framematrices;
	var curve_count = animation.curve_count;
	
	var xx, xy, xz, xw, yy, yz, yw, zz, zw;
	var qw, qx, qy, qz, sx, sy, sz;
	var curve_index;
	var bone_offset;
	var mA = matrix_build_identity();
	
	array_resize(animation.baked_local, 0);
	for (var frame = duration-1; frame >= 0; frame--) {
		framematrices = array_create(curve_count);
		VBM_Animation_SampleBoneTransforms(animation, frame, animation.curve_namehashes, transforms, 10);
		
		curve_index = 0;
		bone_offset = 0;
		repeat(curve_count) {
			// M = T * R * S, Mat4Compose(loc, quat, scale):
			qw = transforms[curve_index+VBM_T_QUATW];
			qx = transforms[curve_index+VBM_T_QUATX];
			qy = transforms[curve_index+VBM_T_QUATY];
			qz = transforms[curve_index+VBM_T_QUATZ];
		
			sx = transforms[curve_index+VBM_T_SCALEX];
			sy = transforms[curve_index+VBM_T_SCALEY];
			sz = transforms[curve_index+VBM_T_SCALEZ];
		
			xx = qx*qx; xy = qx*qy; xz = qx*qz; xw = qx*qw;
			yy = qy*qy; yz = qy*qz; yw = qy*qw;
			zz = qz*qz; zw = qz*qw;
		
			mA[VBM_M00] = (1.0 - 2.0 * (yy + zz)) * sx;
		    mA[VBM_M01] = (2.0 * (xy - zw)) * sx;
		    mA[VBM_M02] = (2.0 * (xz + yw)) * sx;
		    mA[VBM_M03] = transforms[curve_index+VBM_T_LOCX];
		    mA[VBM_M10] = (2.0 * (xy + zw)) * sy;
		    mA[VBM_M11] = (1.0 - 2.0 * (xx + zz)) * sy;
		    mA[VBM_M12] = (2.0 * (yz - xw)) * sy;
			mA[VBM_M13] = transforms[curve_index+VBM_T_LOCY];
		    mA[VBM_M20] = (2.0 * (xz - yw)) * sz;
		    mA[VBM_M21] = (2.0 * (yz + xw)) * sz;
		    mA[VBM_M22] = (1.0 - 2.0 * (xx + yy)) * sz;
			mA[VBM_M23] = transforms[curve_index+VBM_T_LOCZ];
		    mA[VBM_M30] = 0.0; 
			mA[VBM_M31] = 0.0; 
			mA[VBM_M32] = 0.0; 
			mA[VBM_M33] = 1.0;
			array_copy(framematrices, bone_offset, mA, 0, 16);
			bone_offset += 16;
			curve_index += 1;
		}
		
		baked[@ frame] = framematrices;
	}
	animation.baked_local = baked;
}

#endregion // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#region // Model Struct =============================================================

function VBM_Model() constructor {
	meshes = array_create(16);
	mesh_count = 0;
	
	skeleton = new VBM_Skeleton();
	animations = [];
	animation_count = 0;
	
	texture_sprites = [];	// Generated during file reading
	texture_count = 0;
	
	function toString() {
		return "{VBMModel " + name 
			+ " meshes " + string(mesh_count) 
			+ " textures " + string(texture_count) 
			+ " bones" + string(skeleton.bone_count)
			+ " animations " + string(animation_count) 
			+ "}";
	}
}

function VBM_Model_Create() {
	return new VBM_Model();
}

function VBM_Model_Join(model, src, copy_meshes, copy_skeleton, copy_animations) {
	if (copy_meshes) {
		var texture_index_offset = model.texture_count;
		array_resize(model.texture_sprites, model.texture_count+src.texture_count);
		for (var i = 0; i < src.texture_count; i++) {
			model.texture_sprites[model.texture_count] = sprite_duplicate(src.texture_sprites[i]);
			model.texture_count += 1;
		}
		
		array_resize(model.meshes, src.mesh_count+model.mesh_count);
		for (var i = 0; i < src.mesh_count; i++) {
			var m1 = src.meshes[i];
			var m2 = new VBM_Mesh();
			
			m2.name = m1.name;
			array_copy(m2.formatkey, 0, m1.formatkey, 0, 8);
			m2.format = VBM_FormatFromKey(m2.formatkey);
			var b = buffer_create_from_vertex_buffer(m1.vertex_buffer, buffer_fast, 1);
			m2.vertex_buffer = vertex_create_buffer_from_buffer(b, m2.format);
			buffer_delete(b);
			m2.is_edge = m1.is_edge;
			
			if (m1.texture_sprite > -1) {
				for (var j = 0; j < src.texture_count; j++) {
					if ( m1.texture_sprite == src.texture_sprites[j] ) {
						m2.texture_sprite = model.texture_sprites[texture_index_offset+j];
						break;
					}
				}
			}
			
			m2.texture_override = m1.texture_override;
			m2.material_index = m1.material_index;
			array_copy(m2.bounds_min, 0, m1.bounds_min, 0, 8);
			array_copy(m2.bounds_max, 0, m1.bounds_max, 0, 8);
			
			model.meshes[model.mesh_count] = m2;
			model.mesh_count += 1;
		}
	}
	
	if (copy_skeleton) {
		var s1 = src.skeleton;
		var s2 = model.skeleton;
		
		s2.name = s1.name;
		s2.bone_count = s1.bone_count;
		array_copy(s2.bone_names, 0, s1.bone_names, 0, VBM_BONECAPACITY);
		array_copy(s2.bone_hashes, 0, s1.bone_hashes, 0, VBM_BONECAPACITY);
		array_copy(s2.bone_parentindex, 0, s1.bone_parentindex, 0, VBM_BONECAPACITY);
		
		for (var i = 0; i < s2.bone_count; i++) {
			s2.bone_matlocal[i] = matrix_build_identity();
			s2.bone_matinverse[i] = matrix_build_identity();
			s2.bone_segments[i] = array_create(8);
			
			array_copy(s2.bone_matlocal[i], 0, s1.bone_matlocal[i], 0, 16);
			array_copy(s2.bone_matinverse[i], 0, s1.bone_matinverse[i], 0, 16);
			array_copy(s2.bone_segments[i], 0, s1.bone_segments[i], 0, 8);
		}
	}
	
	if (copy_animations) {
		array_resize(model.animations, model.animation_count+src.animation_count);
		for (var i = 0; i < src.animation_count; i++) {
			var a1 = src.animations[i];
			var a2 = new VBM_Animation();
			
			a2.name = a1.name;
			a2.flags = a1.flags;
			a2.curve_count = a1.curve_count;
			a2.duration = a1.duration;
			a2.native_fps = a1.native_fps;
			
			array_copy(a2.curve_names, 0, a1.curve_names, 0, VBM_CURVECAPACITY);
			array_copy(a2.curve_namehashes, 0, a1.curve_namehashes, 0, VBM_CURVECAPACITY);
			array_copy(a2.curve_views, 0, a1.curve_views, 0, array_length(a1.curve_views));
			
			model.animations[model.animation_count] = a2;
			model.animation_count += 1;
		}
	}
}

function VBM_Model_Clear(vbmmodel) {
	for (var i = 0; i < array_length(vbmmodel.texture_sprites); i++) {
		sprite_delete(vbmmodel.texture_sprites[i]);
	}
	
	var n = vbmmodel.mesh_count;
	for (var mesh_index = 0; mesh_index < n; mesh_index++) {
		var mesh = vbmmodel.meshes[mesh_index];
		vertex_delete_buffer(mesh.vertex_buffer);
		vertex_format_delete(mesh.format);
	}
	
	var n = vbmmodel.animation_count;
	for (var animation_index = 0; animation_index < n; animation_index++) {
		VBM_Animation_Free(vbmmodel.animations[animation_index]);
	}
	
	array_resize(vbmmodel.texture_sprites, 0);
	array_resize(vbmmodel.meshes, 0);
	array_resize(vbmmodel.animations, 0);
	vbmmodel.mesh_count = 0;
	vbmmodel.skeleton.bone_count = 0;
	vbmmodel.animation_count = 0;
}

// Model Meshes .................................................................
function VBM_Model_GetMesh(vbmmodel, mesh_index) {
	if ( vbmmodel && mesh_index >= 0 && mesh_index < vbmmodel.mesh_count ) {
		return vbmmodel.meshes[mesh_index];	
	}
	return undefined;
}

function VBM_Model_GetMeshCount(vbmmodel) {
	return vbmmodel? vbmmodel.mesh_count: 0;
}

function VBM_Model_GetMeshName(vbmmodel, mesh_index) {
	return vbmmodel? 
		((mesh_index>=0 && mesh_index<vbmmodel.mesh_count)? vbmmodel.meshes[mesh_index].name: "<nullMesh>"): 
		"<nullModel>";
}

function VBM_Model_GetMeshNameArray(vbmmodel) {
	var names = [];
	if ( vbmmodel ) {
		var n = vbmmodel.mesh_count;
		array_resize(names, n);
		for (var i = 0; i < n; i++) {names[i] = vbmmodel.meshes[i].name;}
	}
	return names;
}

function VBM_Model_FindMeshIndex(vbmmodel, mesh_name) {
	if (vbmmodel) {
		var n = vbmmodel.mesh_count;
		for (var i = 0; i < n; i++) {
			if (vbmmodel.mesh_name[i] == mesh_name) {
				return i;
			}
		}
	}
	return -1;
}

function VBM_Model_FindMesh(vbmmodel, mesh_name) {
	if (vbmmodel) {
		var n = vbmmodel.mesh_count;
		for (var i = 0; i < n; i++) {
			if (vbmmodel.meshes.name == mesh_name) {
				return i;
			}
		}
	}
	return undefined;
}

// Model Textures .................................................................
function VBM_Model_GetTextureSprite(vbmmodel, texture_index) {
	if ( vbmmodel && texture_index >= 0 && texture_index < vbmmodel.texture_count ) {
		return vbmmodel.texture_sprites[texture_index];	
	}
	return -1;
}

function VBM_Model_GetTextureSpriteCount(vbmmodel) {
	return vbmmodel? vbmmodel.texture_count: 0;
}

// Model Skeleton .................................................................
function VBM_Model_GetBoneCount(vbmmodel) {
	return vbmmodel? vbmmodel.skeleton.bone_count: 0;
}

function VBM_Model_GetBoneName(vbmmodel, bone_index) {
	return vbmmodel? 
		((bone_index>=0 && bone_index<vbmmodel.skeleton.bone_count)? vbmmodel.skeleton.bone_names[bone_index]: "<nullBone>"): 
		"<nullModel>";
}

function VBM_Model_GetBoneNameArray(vbmmodel) {
	var names = [];
	if ( vbmmodel ) {
		var n = vbmmodel.skeleton.bone_count;
		array_resize(names, n);
		for (var i = 0; i < n; i++) {names[i] = vbmmodel.skeleton.bone_names[i];}
	}
	return names;
}

function VBM_Model_FindBoneIndex(vbmmodel, bone_name) {
	if (vbmmodel && vbmmodel.skeleton.bone_count > 0) {
		var n = vbmmodel.skeleton.bone_count;
		for (var i = 0; i < n; i++) {
			if ( vbmmodel.skeleton.bone_names[i] == bone_name ) {
				return i;
			}
		}
	}
	return -1;
}

// Model Animations .................................................................
function VBM_Model_GetAnimation(vbmmodel, animation_index) {
	return (animation_index >= 0 && animation_index < vbmmodel.animation_count)?
		vbmmodel.animations[animation_index]: undefined;
}

function VBM_Model_GetAnimationName(vbmmodel, animation_index) {
	return (vbmmodel && animation_index >= 0 && animation_index < vbmmodel.animation_count)?
		vbmmodel.animations[animation_index].name: "<nullAnimation>";
}

function VBM_Model_GetAnimationNameArray(vbmmodel) {
	var names = [];
	if ( vbmmodel ) {
		var n = vbmmodel.animation_count;
		array_resize(names, n);
		for (var i = 0; i < n; i++) {names[i] = vbmmodel.animations[i].name;}
	}
	return names;
}

function VBM_Model_GetAnimationDuration(vbmmodel, animation_index) {
	return (vbmmodel && animation_index >= 0 && animation_index < vbmmodel.animation_count)?
		vbmmodel.animations[animation_index].duration: 0;
}

function VBM_Model_FindAnimation(vbmmodel, animation_name) {
	var n = vbmmodel.animation_count;
	for (var i = 0; i < n; i++) {
		if (vbmmodel.animations[i].name == animation_name) {
			return vbmmodel.animations[i];
		}
	}
	return undefined;
}

function VBM_Model_HasAnimation(vbmmodel, animation_name) {
	var n = vbmmodel.animation_count;
	for (var i = 0; i < n; i++) {
		if (vbmmodel.animations[i].name == animation_name) {
			return true;
		}
	}
	return false;
}

function VBM_Model_Submit(vbmmodel, texture) {
	if (!vbmmodel) {return;}
	var n = vbmmodel.mesh_count;
	var mesh;
	var tex;
	for (var mesh_index = 0; mesh_index < n; mesh_index++) {
		mesh = vbmmodel.meshes[mesh_index];
		if (texture == VBM_SUBMIT_TEXNONE) {
			tex = -1;
		}
		else if (texture == VBM_SUBMIT_TEXDEFAULT) {
			tex = mesh.texture_override? mesh.texture_override: 
				((mesh.texture_sprite > -1)? sprite_get_texture(mesh.texture_sprite, 0): texture);
		}
		else {
			tex = texture;
		}
		vertex_submit(mesh.vertex_buffer, mesh.is_edge? pr_linelist: pr_trianglelist, tex);
	}
}

function VBM_Model_SubmitExt(vbmmodel, texture, hidebits, flags) {
	var n = vbmmodel.mesh_count;
	var mesh;
	var tex;
	for (var mesh_index = 0; mesh_index < n; mesh_index++) {
		if (hidebits & (1<<mesh_index)) {continue;}
		mesh = vbmmodel.meshes[mesh_index];
		
		if (texture == VBM_SUBMIT_TEXNONE) {
			tex = -1;
		}
		else if (texture == VBM_SUBMIT_TEXDEFAULT) {
			tex = mesh.texture_override? mesh.texture_override: 
				((mesh.texture_sprite > -1)? sprite_get_texture(mesh.texture_sprite, 0): texture);
		}
		else {
			tex = texture;
		}
		
		vertex_submit(mesh.vertex_buffer, mesh.is_edge? pr_linelist: pr_trianglelist, tex);
	}
}

function VBM_Model_SubmitMesh(vbmmodel, texture, mesh_index) {
	if ( mesh_index >= 0 && mesh_index < vbmmodel.mesh_count ) {
		var mesh = vbmmodel.meshes[mesh_index];
		if (texture == VBM_SUBMIT_TEXNONE) {
			texture = -1;
		}
		else if (texture == VBM_SUBMIT_TEXDEFAULT) {
			texture = mesh.texture_override? mesh.texture_override: 
				((mesh.texture_sprite > -1)? sprite_get_texture(mesh.texture_sprite, 0): texture);
		}
		vertex_submit(mesh.vertex_buffer, mesh.is_edge? pr_linelist: pr_trianglelist, texture);
	}
}

function VBM_Model_SubmitMeshName(vbmmodel, texture, mesh_name) {
	var n = vbmmodel.mesh_count;
	var mesh;
	var tex;
	
	for (var i = 0; i < n; i++) {
		if (vbmmodel.meshes[i].name == mesh_name) {
			mesh = vbmmodel.meshes[i];
			if (texture == VBM_SUBMIT_TEXNONE) {
				tex = -1;
			}
			else if (texture == VBM_SUBMIT_TEXDEFAULT) {
				tex = mesh.texture_override? mesh.texture_override: 
					((mesh.texture_sprite > -1)? sprite_get_texture(mesh.texture_sprite, 0): texture);
			}
			else {
				tex = texture;
			}
			
			vertex_submit(mesh.vertex_buffer, mesh.is_edge? pr_linelist: pr_trianglelist, tex);
		}
	}
}

function VBM_Model_SampleAnimationIndex_Mat4(vbmmodel, animation_index, frame, outmat4arrayflat) {
	VBM_Model_SampleAnimation_Mat4(vbmmodel, VBM_Model_GetAnimation(vbmmodel, animation_index), frame, outmat4arrayflat);
}

function VBM_Model_SampleAnimationName_Mat4(vbmmodel, animation_name, frame, outmat4arrayflat) {
	VBM_Model_SampleAnimation_Mat4(vbmmodel, VBM_Model_FindAnimation(vbmmodel, animation_name), frame, outmat4arrayflat);
}

function VBM_Model_SampleAnimation_Mat4(vbmmodel, animation, frame, outmat4arrayflat) {
	// Fill array with identity if inputs are invalid
	if ( !vbmmodel || !animation ) {
		var bone_count = array_length(outmat4arrayflat) / 16;
		outmat4arrayflat[@ 0] = 1; outmat4arrayflat[@ 1] = 0; outmat4arrayflat[@ 2] = 0; outmat4arrayflat[@ 3] = 0;
		outmat4arrayflat[@ 4] = 0; outmat4arrayflat[@ 5] = 1; outmat4arrayflat[@ 6] = 0; outmat4arrayflat[@ 7] = 0;
		outmat4arrayflat[@ 8] = 0; outmat4arrayflat[@ 9] = 0; outmat4arrayflat[@10] = 1; outmat4arrayflat[@11] = 0;
		outmat4arrayflat[@12] = 0; outmat4arrayflat[@13] = 0; outmat4arrayflat[@14] = 0; outmat4arrayflat[@15] = 1;
		
		var p = 1;
		while ( (p<<1) < bone_count) {
			array_copy(outmat4arrayflat, 16*p, outmat4arrayflat, 0, 16*p);
			p = p << 1;	// p = 2^i
		}
		array_copy(outmat4arrayflat, 16*(bone_count-p), outmat4arrayflat, 0, 16*p);	// Last power of 2 to n
		return;	// yeet out of function
	}
	
	var skeleton = vbmmodel.skeleton;
	var bone_count = skeleton.bone_count;
	
	// Use output data as memory for calculations ....................................
	
	// Fill array with default transforms
	outmat4arrayflat[@ VBM_T_LOCX] = 0.0; outmat4arrayflat[@ VBM_T_LOCY] = 0.0; outmat4arrayflat[@ VBM_T_LOCZ] = 0.0; 
	outmat4arrayflat[@ VBM_T_QUATW] = 1.0; outmat4arrayflat[@ VBM_T_QUATX] = 0.0; outmat4arrayflat[@ VBM_T_QUATY] = 0.0; outmat4arrayflat[@ 6+VBM_T_QUATZ] = 0.0;
	outmat4arrayflat[@ VBM_T_SCALEX] = 1.0; outmat4arrayflat[@ VBM_T_SCALEY] = 1.0; outmat4arrayflat[@ VBM_T_SCALEZ] = 1.0;
	
	var p = 1;
	while ( (p<<1) < bone_count) {
		array_copy(outmat4arrayflat, 16*p, outmat4arrayflat, 0, 16*p);
		p = p << 1;	// p = 2^i
	}
	array_copy(outmat4arrayflat, 16*(bone_count-p), outmat4arrayflat, 0, 16*p);
	
	// Matrix 0 = Identity
	outmat4arrayflat[@ 0] = 1; outmat4arrayflat[@ 1] = 0; outmat4arrayflat[@ 2] = 0; outmat4arrayflat[@ 3] = 0;
	outmat4arrayflat[@ 4] = 0; outmat4arrayflat[@ 5] = 1; outmat4arrayflat[@ 6] = 0; outmat4arrayflat[@ 7] = 0;
	outmat4arrayflat[@ 8] = 0; outmat4arrayflat[@ 9] = 0; outmat4arrayflat[@10] = 1; outmat4arrayflat[@11] = 0;
	outmat4arrayflat[@12] = 0; outmat4arrayflat[@13] = 0; outmat4arrayflat[@14] = 0; outmat4arrayflat[@15] = 1;
	
	// Sample Transforms .......................................................
	VBM_Animation_SampleBoneTransforms(animation, frame, skeleton.bone_hashes, outmat4arrayflat, 16);
	
	// Transforms to Matrices ......................................................
	var bone_index;
	var parentindices = skeleton.bone_parentindex;
	var bone_matinverse = skeleton.bone_matinverse;
	var bone_matlocal = skeleton.bone_matlocal;
		
	// Reuse given out array for storing intermediate transforms (Local-Space and Model-Space)
	var mA = matrix_build_identity();
	var mB = matrix_build_identity();
	var t;
	var qw, qx, qy, qz;
	var xx, xy, xz, xw, yy, yz, yw, zz, zw, sx, sy, sz;
	
	t = 1;
	repeat(bone_count-1) {
		bone_index = t*16;
		
		// M = T * R * S, Mat4Compose(loc, quat, scale):
		qw = outmat4arrayflat[bone_index+VBM_T_QUATW];
		qx = outmat4arrayflat[bone_index+VBM_T_QUATX];
		qy = outmat4arrayflat[bone_index+VBM_T_QUATY];
		qz = outmat4arrayflat[bone_index+VBM_T_QUATZ];
		
		sx = outmat4arrayflat[bone_index+VBM_T_SCALEX];
		sy = outmat4arrayflat[bone_index+VBM_T_SCALEY];
		sz = outmat4arrayflat[bone_index+VBM_T_SCALEZ];
		
		xx = qx*qx; xy = qx*qy; xz = qx*qz; xw = qx*qw;
		yy = qy*qy; yz = qy*qz; yw = qy*qw;
		zz = qz*qz; zw = qz*qw;
		
		mA[VBM_M00] = (1.0 - 2.0 * (yy + zz)) * sx;
	    mA[VBM_M01] = (2.0 * (xy - zw)) * sx;
	    mA[VBM_M02] = (2.0 * (xz + yw)) * sx;
	    mA[VBM_M03] = outmat4arrayflat[bone_index+VBM_T_LOCX];
	    mA[VBM_M10] = (2.0 * (xy + zw)) * sy;
	    mA[VBM_M11] = (1.0 - 2.0 * (xx + zz)) * sy;
	    mA[VBM_M12] = (2.0 * (yz - xw)) * sy;
		mA[VBM_M13] = outmat4arrayflat[bone_index+VBM_T_LOCY];
	    mA[VBM_M20] = (2.0 * (xz - yw)) * sz;
	    mA[VBM_M21] = (2.0 * (yz + xw)) * sz;
	    mA[VBM_M22] = (1.0 - 2.0 * (xx + yy)) * sz;
		mA[VBM_M23] = outmat4arrayflat[bone_index+VBM_T_LOCZ];
	    mA[VBM_M30] = 0.0; mA[VBM_M31] = 0.0; mA[VBM_M32] = 0.0; mA[VBM_M33] = 1.0;
		
		// Transform Offset (Local x transform.RST)
		mA = matrix_multiply(mA, bone_matlocal[t]);	// = Local
		
		// Model-Space Offset (Parent x Local)
		array_copy(mB, 0, outmat4arrayflat, parentindices[t]*16, 16);	// Parent.Model
		mA = matrix_multiply(mA, mB);	// Model-Space
		array_copy(outmat4arrayflat, t*16, mA, 0, 16);	// Temporarily write to final location
		t++;
	}
	
	t = 1;
	bone_count = min(bone_count, VBM_BONELIMIT);	// If array exceeds 128, crashes on some devices
	repeat(bone_count-1) {
		// Vertex-Space Offset (Model x InverseBind)
		array_copy(mA, 0, outmat4arrayflat, t*16, 16);
		mA = matrix_multiply(bone_matinverse[t], mA);	// Final
		array_copy(outmat4arrayflat, t*16, mA, 0, 16);
		t++;
	}
}

#endregion // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#region // Animator =================================================================

function VBM_AnimatorLayer() constructor {
	animation_frame = 0;
	animation_pos = 0;
	animation = new VBM_Animation();	// Values of active animation are copied here
	
	blend_frame = 0.0;
	blend_time = 0.0;
	
	function toString() {
		return "{VBMAnimatorLayer "
			+ " frame " + string_format(animation_frame, 4, 0)
			+ " pos " + string_format(animation_frame, 2, 2)
			+ " animation " + (animation? animation.name: "<None>")
			+ "}";
	}
}

function VBM_AnimatorSwing() constructor {
	bone_name = "";
	bone_hash = 0;
	mass = 10.0;
	stiffness = 0.1;
	friction = 0.1;
	dampness = 0.1;
	stretch = 0.0;
	randomness = 0.1;	// Added to particle when far from point
	force = [0, 0, -0.01];
	
	angle_min_x = -0.1;
	angle_max_x = 0.1;
	angle_min_z = -0.1;
	angle_max_z = 0.1;
	
	vprev = [0,0,0];
	vcurr = [0,0,0];
	vgoal = [0,0,0];
	
	flags = VBM_SWINGFLAGS.DISTANCE;
}

function VBM_AnimatorCollider() constructor {
	bone_name = "";
	bone_hash = 0;
	offset = [0,0,0];
	radius = 0;
	length = 0;
	vcurr = [0,0,0];
	vend = [0,0,0];
}

// Stores animation state for complex movements
function VBM_Animator() constructor {
	transforms = array_create(10*VBM_BONECAPACITY);	// Flat array of [locx, locy, locz, quatw, quatx, quaty, quatz, scalex, scaley, scalez]
	transforms_last = array_create(10*VBM_BONECAPACITY);
	transform_root = array_create(10);
	transform_checksum = array_create(VBM_BONECAPACITY);
	matworld = array_create(VBM_BONECAPACITY, matrix_build_identity());
	matfinal = array_create(VBM_BONECAPACITY*16);	// Flat array of [mat4]
	matroot = matrix_build_identity();
	
	bone_count = 0;
	bone_names = array_create(VBM_BONECAPACITY);
	bone_hashes = array_create(VBM_BONECAPACITY);
	bone_parentindex = array_create(VBM_BONECAPACITY);
	bone_matlocal = array_create(VBM_BONECAPACITY);
	bone_matinverse = array_create(VBM_BONECAPACITY);
	bone_segments = array_create(VBM_BONECAPACITY*8);
	
	swing_bones = [];	// array of VBM_AnimatorSwing
	swing_count = 0;
	swing_enabled = true;
	
	colliders = [];	// array of VBM_AnimatorCollider
	collider_count = 0;
	colliders_enabled = true;
	
	layer_count = 0;
	layers = array_create(8);
	layer_active_bits = ~0;
	
	mesh_hide_bits = 0;	// Capped at 32?
	mesh_names = array_create(32);
	animations = [];
	animation_count = 0;
	
	benchmark = [0,0,0,0];	// [total_time, transform_time, matrix_time]
	
	function toString() {
		return "{VBMAnimator "
			+ " layers " + string(layer_count)
			+ " exectime " + string_format(benchmark[0], 2, 2)
			+ "}";
	}
}

function VBM_Animator_Create() {
	var animator = new VBM_Animator();
	for (var t = 0; t < VBM_BONECAPACITY; t++) {
		animator.bone_matlocal[t] = matrix_build_identity();
		animator.bone_matinverse[t] = matrix_build_identity();
		
		animator.transforms[t*10 + VBM_T_QUATW] = 1.0;
		animator.transforms[t*10 + VBM_T_SCALEX] = 1.0;
		animator.transforms[t*10 + VBM_T_SCALEY] = 1.0;
		animator.transforms[t*10 + VBM_T_SCALEZ] = 1.0;
		
		animator.matrices[t*16 + VBM_M00] = 1.0;
		animator.matrices[t*16 + VBM_M11] = 1.0;
		animator.matrices[t*16 + VBM_M22] = 1.0;
		animator.matrices[t*16 + VBM_M33] = 1.0;
	}
	VBM_Animator_AddLayers(animator, 1);
	return animator;
}

function VBM_Animator_Clear(animator) {
	var midentity = matrix_build_identity();
	var tidentity = [0,0,0, 1,0,0,0, 1,1,1];
	
	for (var t = 0; t < VBM_BONECAPACITY; t++) {
		array_copy(animator.bone_matlocal[t], 0, midentity, 0, 16);
		array_copy(animator.bone_matinverse[t], 0, midentity, 0, 16);
		array_copy(animator.matrices, t*16, midentity, 0, 16);
		array_copy(animator.transforms, t*10, tidentity, 0, 10);
	}
	
	var n = animator.animation_count;
	for (var animation_index = 0; animation_index < n; animation_index++) {
		VBM_Animation_Free(animator.animations[animation_index]);
	}
	
	array_resize(animator.animations, 0);
	animator.animation_count = 0;
}

function VBM_Animator_FromModel(animator, vbmmodel) {
	VBM_Animator_FromModelExt(animator, vbmmodel, 1, 1);
}

function VBM_Animator_FromModelExt(animator, vbmmodel, read_skeleton, read_animations) {
	if (!animator || !vbmmodel) {return;}
	
	// Meshes
	if (1) {
		var n = vbmmodel.mesh_count;
		for (var i = 0; i < n; i++) {
			animator.mesh_names[i] = vbmmodel.meshes[i].name;
		}
	}
	
	// Bones
	if ( read_skeleton ) {
		var ske = vbmmodel.skeleton;
		animator.bone_count = ske.bone_count;
		array_copy(animator.bone_parentindex, 0, ske.bone_parentindex, 0, animator.bone_count);
		array_copy(animator.bone_names, 0, ske.bone_names, 0, animator.bone_count);
		array_copy(animator.bone_hashes, 0, ske.bone_hashes, 0, animator.bone_count);
		
		for (var i = 0; i < animator.bone_count; i++) {
			array_copy(animator.bone_matlocal[i], 0, ske.bone_matlocal[i], 0, 16);
			array_copy(animator.bone_matinverse[i], 0, ske.bone_matinverse[i], 0, 16);
			animator.bone_segments[i] = array_create(8);
			array_copy(animator.bone_segments[i], 0, vbmmodel.skeleton.bone_segments[i], 0, 8);
		
			if (ske.bone_swingindex[i] >= 0) {
				var swg = ske.swing_bones[ske.bone_swingindex[i]];
				VBM_Animator_SwingDefine(
					animator, animator.bone_names[i],
					10.0,
					swg.friction, 
					swg.stiffness, 
					swg.dampness, 
					0.0, 0.0, swg.gravity
				);
			}
		
			if (ske.bone_colliderindex[i] >= 0) {
				var collider = ske.collider_bones[ske.bone_colliderindex[i]];
				VBM_Animator_ColliderDefine(
					animator, animator.bone_names[i],
					collider.radius,
					collider.length
				);
			}
		}
	}
	// Animations
	if ( read_animations ) {
		array_resize(animator.animations, animator.animation_count+vbmmodel.animation_count);
		for (var i = 0; i < vbmmodel.animation_count; i++) {
			animator.animations[animator.animation_count] = new VBM_Animation();
			VBM_Animation_Copy(animator.animations[animator.animation_count], vbmmodel.animations[i]);
			animator.animation_count += 1;
		}
	}
}

function VBM_Animator_SwingDefine(animator, bone_name, mass, friction, stiffness, dampness, force_x, force_y, force_z) {
	var swg = 0;
	for (var i = 0; i < animator.swing_count; i++) {
		if (animator.swing_bones[i].bone_name == bone_name) {
			swg = animator.swing_bones[i];
			break;
		}
	}
	
	if (swg == 0) {
		swg = new VBM_AnimatorSwing();
		array_resize(animator.swing_bones, animator.swing_count+1);
		animator.swing_bones[animator.swing_count] = swg;
		animator.swing_count += 1;
	}
	
	swg.bone_name = bone_name;
	swg.bone_hash = VBM_StringHash(bone_name);
	swg.force[0] = force_x;
	swg.force[1] = force_y;
	swg.force[2] = force_z;
	swg.mass = max(mass, 0.01);
	swg.friction = max(friction, 0.01);
	swg.stiffness = max(stiffness, 0.01);
	swg.dampness = max(dampness, 0.01);
	return swg;
}

function VBM_Animator_SwingDefinePattern(animator, bone_name, mass, friction, stiffness, dampness, force_x, force_y, force_z) {
	var namelen = string_length(bone_name);
	for (var i = 0; i < animator.bone_count; i++) {
		if ( string_copy(animator.bone_names[i], 1, namelen) == bone_name ) {
			VBM_Animator_SwingDefine(animator, animator.bone_names[i], 
				mass, friction, stiffness, dampness, force_x, force_y, force_z);
		}
	}
}

function VBM_Animator_SwingReset(animator) {
	var mswg = matrix_build_identity();
	var swg;
	var voffset = [0,0,0];
	var vgoal = [0,0,0];
	var bone_index, parent_index, swing_index;
	var bone_count, swing_count;
	var bone_hash;
	var bone_length;
	
	bone_count = animator.bone_count;
	swing_count = animator.swing_count;
	
	for (var bone_index = 0; bone_index < bone_count; bone_index++) {
		// Model-Space Offset (Parent x Local)
		animator.matworld[bone_index] = matrix_multiply(
			animator.bone_matlocal[bone_index], 
			animator.matworld[animator.bone_parentindex[bone_index]]
		);
		bone_hash = animator.bone_hashes[bone_index];
		
		for (swing_index = 0; swing_index < swing_count; swing_index++) {
			swg = animator.swing_bones[swing_index];
			if ( bone_hash == swg.bone_hash) {
				parent_index = animator.bone_parentindex[bone_index];
				bone_length = animator.bone_segments[bone_index][VBM_BONESEGMENT.length];
				
				// Get position of goal = (Bone.Local x Swing.Offset) x Parent.Absolute
				mswg = [1,0,0,0, 0,1,0,bone_length, 0,0,1,0, 0,0,0,1];
				mswg = matrix_multiply(mswg, animator.bone_matlocal[bone_index]);
				mswg = matrix_multiply(mswg, animator.matworld[parent_index]);
				
				vgoal[0] = mswg[VBM_M03];
				vgoal[1] = mswg[VBM_M13];
				vgoal[2] = mswg[VBM_M23];
				
				array_copy(swg.vcurr, 0, vgoal, 0, 3);
				array_copy(swg.vprev, 0, vgoal, 0, 3);
				array_copy(swg.vgoal, 0, vgoal, 0, 3);
				break;
			}
		}
	}
}

function VBM_Animator_ColliderDefine(animator, bone_name, radius, length) {
	if (animator) {
		var col = 0;
		for (var i = 0; i < animator.collider_count; i++) {
			if (animator.colliders[i].bone_name == bone_name) {
				col = animator.colliders[i];
				break;
			}
		}
		
		if (col == 0) {
			col = new VBM_AnimatorCollider();
			array_resize(animator.colliders, animator.collider_count+1);
			animator.colliders[animator.collider_count] = col;
			animator.collider_count += 1;
		}
		
		col.bone_name = bone_name;
		col.bone_hash = VBM_StringHash(bone_name);
		col.radius = radius;
		col.length = length;
	}
}

function VBM_Animator_ResizeLayers(animator, numlayers) {
	var new_count = min(numlayers, 8);
	for (var i = animator.layer_count; i < new_count; i++) {
		animator.layers[i] = new VBM_AnimatorLayer();
	}
	animator.layer_count = new_count;
}

function VBM_Animator_AddLayers(animator, n=1) {
	VBM_Animator_ResizeLayers(animator, animator.layer_count+n);
}

function VBM_Animator_AddAnimation(animator, animation) {
	array_push(animator.animations, VBM_Animation_Duplicate(animation));
	animator.animation_count += 1;
}

function VBM_Animator_AddModelAnimations(animator, vbmmodel) {
	var n = vbmmodel.animation_count;
	for (var i = 0; i < n; i++) {
		VBM_Animator_AddAnimation(animator, vbmmodel.animations[i]);
	}
}

function VBM_Animator_PlayAnimationIndex(animator, layer_index, animation_index) {
	if ( layer_index >= 0 && layer_index < animator.layer_count) {
		if ( animation_index >= 0 && animation_index < animator.animation_count ) {
			if ( animator.layers[layer_index].animation.name != animator.animations[animation_index].name ) {
				VBM_Animation_Copy(
					animator.layers[layer_index].animation,
					animator.animations[animation_index]
				);
			}
		}
	}
}

function VBM_Animator_PlayAnimationKey(animator, layer_index, animation_name) {
	if ( layer_index >= 0 && layer_index < animator.layer_count) {
		if ( animator.layers[layer_index].animation.name != animation_name ) {
			for (var i = 0; i < animator.animation_count; i++) {
				if (animator.animations[i].name == animation_name) {
					animator.layers[layer_index].animation = animator.animations[i];
				}
			}
		}
	}
}

function VBM_Animator_SetAnimationFrame(animator, layer_index, frame) {
	if ( animator ) {
		var lyr = animator.layers[layer_index];
		lyr.animation_frame = frame;
		lyr.animation_pos = frame / lyr.animation.duration;
	}
}

function VBM_Animator_SetAnimationPosition(animator, layer_index, position) {
	if ( animator ) {
		var lyr = animator.layers[layer_index];
		lyr.animation_pos = position;
		lyr.animation_frame = position * lyr.animation.duration;
	}
}

function VBM_Animator_GetLayerCount(animator) {
	return animator? animator.layer_count: 0;
}

function VBM_Animator_GetAnimationCount(animator) {
	return animator? animator.animation_count: 0;
}

function VBM_Animator_GetAnimationName(animator, animation_index) {
	return animator?
		((animation_index >= 0 && animation_index < animator.animation_count)? animator.animations[animation_index].name: "<nullAnimation>"): 
		"<nullAnimator>";
}

function VBM_Animator_GetAnimationNameArray(animator) {
	var names = [];
	if ( animator ) {
		var n = animator.animation_count;
		array_resize(names, n);
		for (var i = 0; i < n; i++) {names[i] = animator.animations[i].name;}
	}
	return names;
}

function VBM_Animator_GetBoneName(animator, bone_index) {
	return animator?
		((bone_index >= 0 && bone_index < animator.bone_count)? animator.bone_names[bone_index]: "<nullBone>"): 
		"<nullAnimator>";
}

function VBM_Animator_GetBoneNameArray(animator) {
	var names = [];
	if ( animator ) {
		var n = animator.bone_count;
		array_resize(names, n);
		for (var i = 0; i < n; i++) {names[i] = animator.bone_names[i].name;}
	}
	return names;
}

function VBM_Animator_FindBoneIndex(animator, bone_name) {
	for (var i = 0; i < animator.bone_count; i++) {
		if (animator.bone_names[i] == bone_name) {return i;}
	}
	return -1;
}

function VBM_Animator_FindBoneIndicesByPattern(animator, name, outindexarray, n) {
	var bone_count = animator.bone_count;
	var hits = 0;
	var namelen = string_length(name);
	for (var i = 0; i < bone_count; i++) {
		if ( string_copy(animator.bone_names[i], 1, namelen) == name ) {
			outindexarray[hits] = i;
			hits += 1;
			if (hits >= n) {
				break;
			}
		}
	}
	return hits;
}

function VBM_Animator_FindBoneNamesByPattern(animator, name, outstringarray, n) {
	var bone_count = animator.bone_count;
	var hits = 0;
	var namelen = string_length(name);
	for (var i = 0; i < bone_count; i++) {
		if ( string_copy(animator.bone_names[i], 1, namelen) == name ) {
			outstringarray[hits] = animator.bone_names[i];
			hits += 1;
			if (hits >= n) {
				break;
			}
		}
	}
	return hits;
}

function VBM_Animator_GetBoneParentIndex(animator, bone_index) {
	return animator.bone_parentindex[bone_index];
}

function VBM_Animator_GetLayerAnimationPosition(animator, layer_index) {
	return (animator && layer_index >= 0 && layer_index < animator.layer_count)?
		animator.layers[layer_index].animation_frame / animator.layers[layer_index].animation.duration:
		0.0;
}

function VBM_Animator_GetLayerAnimationFrame(animator, layer_index) {
	return (animator && layer_index >= 0 && layer_index < animator.layer_count)?
		animator.layers[layer_index].animation_frame: -1;
}

function VBM_Animator_GetLayerAnimationKey(animator, layer_index) {
	return (animator && layer_index >= 0 && layer_index < animator.layer_count)?
		(animator.layers[layer_index].animation.curve_count? animator.layers[layer_index].animation.name: "<nullAnimation>"): "<nullAnimatorLayer>";
}

function VBM_Animator_GetMat4WorldArray(animator) {
	return animator.matworld;
}

function VBM_Animator_GetMat4FinalArray(animator) {
	return animator.matfinal;
}

function VBM_Animator_GetTransform(animator, transform_index, outfloat10) {
	array_copy(outfloat10, 0, animator.transforms, transform_index*10, 10);
}

function VBM_Animator_GetMatrixWorld(animator, bone_index, outmat4) {
	array_copy(outmat4, 0, animator.matworld[bone_index], 0, 16);
}

function VBM_Animator_GetMatrixFinal(animator, bone_index, outmat4) {
	array_copy(outmat4, 0, animator.matfinal, 16*bone_index, 16);
}

function VBM_Animator_SetRootTransform(animator, x,y,z, radiansx,radiansy,radiansz, sx,sy,sz) {
	animator.transforms[VBM_T_SCALEX] = sx;
	animator.transforms[VBM_T_SCALEY] = sy;
	animator.transforms[VBM_T_SCALEZ] = sz;
	
	animator.transforms[VBM_T_QUATW] = cos(radiansx)*cos(radiansy)*cos(radiansz) - sin(radiansx)*sin(radiansy)*sin(radiansz);
	animator.transforms[VBM_T_QUATX] = sin(radiansx)*cos(radiansy)*cos(radiansz) + cos(radiansx)*sin(radiansy)*sin(radiansz);
	animator.transforms[VBM_T_QUATY] = cos(radiansx)*sin(radiansy)*cos(radiansz) - sin(radiansx)*cos(radiansy)*sin(radiansz);
	animator.transforms[VBM_T_QUATZ] = cos(radiansx)*cos(radiansy)*sin(radiansz) + sin(radiansx)*sin(radiansy)*cos(radiansz);
	
	animator.transforms[VBM_T_LOCX] = x;
	animator.transforms[VBM_T_LOCY] = y;
	animator.transforms[VBM_T_LOCZ] = z;
	array_copy(animator.transform_root, 0, animator.transforms, 0, 10);
}

function VBM_Animator_SetVisibilityIndex(animator, mesh_index, is_visible) {
	if ( is_visible ) {
		animator.mesh_hide_bits |= (1<<mesh_index);
	}
	else {
		animator.mesh_hide_bits &= ~(1<<mesh_index);
	}
}

function VBM_Animator_SetVisibilityName(animator, mesh_name, is_visible) {
	for (var i = 0; i < 32; i++) {
		if (animator.mesh_names[i] == mesh_name) {
			if ( is_visible ) {
				animator.mesh_hide_bits |= (1<<i);
			}
			else {
				animator.mesh_hide_bits &= ~(1<<i);
			}
		}
	}
}

function VBM_Animator_LayerSetBlendTime(animator, layer_index, blend_frames) {
	if (animator && layer_index >= 0 && layer_index < animator.layer_count) {
		var lyr = animator.layers[layer_index];
		lyr.blend_frame = blend_frames;
		lyr.blend_time = blend_frames;
	}
}

function VBM_Animator_UpdateExt(animator, delta, update_transforms, update_swing, update_bones) {
	var bone_count = animator.bone_count;
	var blend_mix;
	
	animator.benchmark[0] = get_timer();
	
	// Process Layers ..............................................................
	if ( update_transforms ) {
		animator.benchmark[1] = get_timer();
		var layer_count = animator.layer_count * 1;
		for (var layer_index = 0; layer_index < layer_count; layer_index++) {
			if ( (animator.layer_active_bits & (1<<layer_index)) == 0 ) {
				continue;
			}
		
			var lyr = animator.layers[layer_index];
			if (lyr.animation.curve_count > 0) {
				blend_mix = lyr.blend_time > 0.0? 1.0-(lyr.blend_frame / lyr.blend_time): 1.0;
				VBM_Animation_BlendBoneTransforms(
					lyr.animation, 
					lyr.animation_frame, 
					animator.bone_hashes, 
					animator.transforms, 
					10,
					animator.transforms_last,
					blend_mix
				);
				lyr.animation_frame += delta;
			}
			
			if ( lyr.blend_frame > 0.0 ) {
				lyr.blend_frame = max(lyr.blend_frame-delta, 0.0);
			}
		}
		animator.benchmark[1] = get_timer()-animator.benchmark[1];
	}
	
	// Transforms to Matrices ......................................................
	animator.benchmark[2] = get_timer();
	var transforms = animator.transforms;
	var transforms_last = animator.transforms_last;
	var outmat4arrayflat = animator.matfinal;
	
	var parentindices = animator.bone_parentindex;
	var bone_matinverse = animator.bone_matinverse;
	var bone_matlocal = animator.bone_matlocal;
	
	var mA = matrix_build_identity();
	var bone_index;
	var d;
	var transform_offset = 0;
	var sx, sy, sz;
	var qw, qx, qy, qz;
	var xx, xy, xz, xw, yy, yz, yw, zz, zw;
	
	// Root transform
	qw = transforms[VBM_T_QUATW];
	qx = transforms[VBM_T_QUATX];
	qy = transforms[VBM_T_QUATY];
	qz = transforms[VBM_T_QUATZ];
	sx = transforms[VBM_T_SCALEX];
	sy = transforms[VBM_T_SCALEY];
	sz = transforms[VBM_T_SCALEZ];
		
	d = 1.0 / sqrt(qw*qw+qx*qx+qy*qy+qz*qz);
	qw *= d; qx *= d; qy *= d; qz *= d;
		
	// M = T * R * S, Mat4Compose(loc, quat, scale):
	xx = qx*qx; xy = qx*qy; xz = qx*qz; xw = qx*qw;
	yy = qy*qy; yz = qy*qz; yw = qy*qw;
	zz = qz*qz; zw = qz*qw;
		
	mA[@ VBM_M00] = (1.0 - 2.0 * (yy + zz)) * sx;
	mA[@ VBM_M01] = (2.0 * (xy - zw)) * sx;
	mA[@ VBM_M02] = (2.0 * (xz + yw)) * sx;
	mA[@ VBM_M03] = transforms[VBM_T_LOCX];
	mA[@ VBM_M10] = (2.0 * (xy + zw)) * sy;
	mA[@ VBM_M11] = (1.0 - 2.0 * (xx + zz)) * sy;
	mA[@ VBM_M12] = (2.0 * (yz - xw)) * sy;
	mA[@ VBM_M13] = transforms[VBM_T_LOCY];
	mA[@ VBM_M20] = (2.0 * (xz - yw)) * sz;
	mA[@ VBM_M21] = (2.0 * (yz + xw)) * sz;
	mA[@ VBM_M22] = (1.0 - 2.0 * (xx + yy)) * sz;
	mA[@ VBM_M23] = transforms[VBM_T_LOCZ];
	mA[@ VBM_M30] = 0.0; mA[@ VBM_M31] = 0.0; mA[@ VBM_M32] = 0.0; mA[@ VBM_M33] = 1.0;
	array_copy(animator.matworld[0], 0, mA, 0, 16);
	array_copy(animator.matfinal, 0, mA, 0, 16);
	
	// Matrices
	bone_index = 1;
	
	// Single check here instead of checking for every bone
	if ( animator.swing_enabled ) {
		var vcurr = [0,0,0], lroot = [0,0,0], lgoal = [0,0,0];
		var vx, vy, vz;
		var lx, ly, lz;
		var gx, gy, gz;
		var rx, ry, rz;
		var cx, cy, cz;
		var velx, vely, velz;
		var d;
		var n;
		var swg;
		var parent_index;
		var mswg = matrix_build_identity(), minv = matrix_build_identity();
		var rollpt5, pitchpt5, yawpt5;
		var bone_hash;
		var frictionrate, stiffness, dampness, randomness, stretch;
		var collider;
		var collider_index;
		var colliders_enabled = animator.colliders_enabled;
		var swg_flags = 0;
		var swing_index;
		var swing_count = animator.swing_count;
		var collider_count = animator.collider_count;
		var bone_length = 0, particle_length;
		
		var m00, m01, m02, m03, m04, m05, m06, m07, m08, m09, m10, m11, m12, m13, m14, m15;
		
		while (bone_index < bone_count) {
			transform_offset = bone_index*10;
			bone_hash = animator.bone_hashes[bone_index];
			parent_index = parentindices[bone_index];
			
			// Swing bone ......................................................
			swing_index = 0;
			repeat(swing_count) {
				if ( bone_hash == animator.swing_bones[swing_index].bone_hash ) {
					swg = animator.swing_bones[swing_index];
					swg_flags = swg.flags;
					bone_length = animator.bone_segments[bone_index][VBM_BONESEGMENT.length];
					
					// Get position of bone before local transform = Bone.Local x Parent.Absolute
					mswg = matrix_multiply(animator.bone_matlocal[bone_index], animator.matworld[parent_index]);
					rx = mswg[VBM_M03];
					ry = mswg[VBM_M13];
					rz = mswg[VBM_M23];
					
					// Calculate inverse of swing base position for later converting back to local transform 
					//__vbm_mat4inverse(minv, mswg);	// <-- Inlined below
					m00 = mswg[ 0]; m01 = mswg[ 1]; m02 = mswg[ 2]; m03 = mswg[ 3];
					m04 = mswg[ 4];	m05 = mswg[ 5]; m06 = mswg[ 6]; m07 = mswg[ 7];
					m08 = mswg[ 8]; m09 = mswg[ 9]; m10 = mswg[10]; m11 = mswg[11]; 
					m12 = mswg[12]; m13 = mswg[13]; m14 = mswg[14]; m15 = mswg[15];
					
					minv[ 0] = m05*m10*m15-m05*m11*m14-m09*m06*m15+m09*m07*m14+m13*m06*m11-m13*m07*m10;
				    minv[ 4] =-m04*m10*m15+m04*m11*m14+m08*m06*m15-m08*m07*m14-m12*m06*m11+m12*m07*m10;
				    minv[ 8] = m04*m09*m15-m04*m11*m13-m08*m05*m15+m08*m07*m13+m12*m05*m11-m12*m07*m09;
				    minv[12] =-m04*m09*m14+m04*m10*m13+m08*m05*m14-m08*m06*m13-m12*m05*m10+m12*m06*m09;
				    minv[ 1] =-m01*m10*m15+m01*m11*m14+m09*m02*m15-m09*m03*m14-m13*m02*m11+m13*m03*m10;
				    minv[ 5] = m00*m10*m15-m00*m11*m14-m08*m02*m15+m08*m03*m14+m12*m02*m11-m12*m03*m10;
				    minv[ 9] =-m00*m09*m15+m00*m11*m13+m08*m01*m15-m08*m03*m13-m12*m01*m11+m12*m03*m09;
				    minv[13] = m00*m09*m14-m00*m10*m13-m08*m01*m14+m08*m02*m13+m12*m01*m10-m12*m02*m09;
				    minv[ 2] = m01*m06*m15-m01*m07*m14-m05*m02*m15+m05*m03*m14+m13*m02*m07-m13*m03*m06;
				    minv[ 6] =-m00*m06*m15+m00*m07*m14+m04*m02*m15-m04*m03*m14-m12*m02*m07+m12*m03*m06;
				    minv[10] = m00*m05*m15-m00*m07*m13-m04*m01*m15+m04*m03*m13+m12*m01*m07-m12*m03*m05;
				    minv[14] =-m00*m05*m14+m00*m06*m13+m04*m01*m14-m04*m02*m13-m12*m01*m06+m12*m02*m05;
				    minv[ 3] =-m01*m06*m11+m01*m07*m10+m05*m02*m11-m05*m03*m10-m09*m02*m07+m09*m03*m06;
				    minv[ 7] = m00*m06*m11-m00*m07*m10-m04*m02*m11+m04*m03*m10+m08*m02*m07-m08*m03*m06;
				    minv[11] =-m00*m05*m11+m00*m07*m09+m04*m01*m11-m04*m03*m09-m08*m01*m07+m08*m03*m05;
				    minv[15] = m00*m05*m10-m00*m06*m09-m04*m01*m10+m04*m02*m09+m08*m01*m06-m08*m02*m05;
	
				    d = 1.0 / (m00 * minv[0] + m01 * minv[4] + m02 * minv[8] + m03 * minv[12] + 0.00001);	// Assumes determinant > 0. Error otherwise
				    minv[ 0] *= d; minv[ 1] *= d; minv[ 2] *= d; minv[ 3] *= d;
				    minv[ 4] *= d; minv[ 5] *= d; minv[ 6] *= d; minv[ 7] *= d;
				    minv[ 8] *= d; minv[ 9] *= d; minv[10] *= d; minv[11] *= d;
				    minv[12] *= d; minv[13] *= d; minv[14] *= d; minv[15] *= d;
					
					// Get position of goal = Swing.Offset x Bone.Local x Parent.Absolute
					lgoal = matrix_transform_vertex(mswg, 0, bone_length, 0);
					gx = lgoal[0];
					gy = lgoal[1];
					gz = lgoal[2];
				
					// Calculate Particle via Verlet Integration ...........................................
					
					// Factor in `delta` here to save on multiplications
					frictionrate = (1.0-swg.friction) * delta;
					stiffness = swg.stiffness * delta;
					dampness = swg.dampness * delta;
					randomness = swg.randomness * delta;
					stretch = swg.stretch;
					
					lx = swg.vcurr[0];
					ly = swg.vcurr[1];
					lz = swg.vcurr[2];
					// Velocity = current - last
					velx = (lx - swg.vprev[0]) * (1.0 + randomness * random_range(-.5, .5));
					vely = (ly - swg.vprev[1]) * (1.0 + randomness * random_range(-.5, .5));
					velz = (lz - swg.vprev[2]) * (1.0 + randomness * random_range(-.5, .5));
					
					// Current = current + velocity + acceleration * dt*dt
					vx = lx + velx * frictionrate + (swg.force[0] / swg.mass) * delta * delta;
					vy = ly + vely * frictionrate + (swg.force[1] / swg.mass) * delta * delta;
					vz = lz + velz * frictionrate + (swg.force[2] / swg.mass) * delta * delta;
					
					vx = lerp(vx, gx, dampness);
					vy = lerp(vy, gy, dampness);
					vz = lerp(vz, gz, dampness);
					
					lx = lerp(lx, gx, dampness) - (gx - vx) * stiffness;
					ly = lerp(ly, gy, dampness) - (gy - vy) * stiffness;
					lz = lerp(lz, gz, dampness) - (gz - vz) * stiffness;
					
					// Limit Distance from root to particle
					if ( stretch < 0.99 ) {
						d = point_distance_3d(vx,vy,vz, rx,ry,rz);
						
						vx = lerp(rx + bone_length * (vx-rx)/d, vx, stretch);
						vy = lerp(ry + bone_length * (vy-ry)/d, vy, stretch);
						vz = lerp(rz + bone_length * (vz-rz)/d, vz, stretch);
						
						d = point_distance_3d(lx,ly,lz, rx,ry,rz);
						lx = lerp(rx + bone_length * (lx-rx)/d, lx, stretch);
						ly = lerp(ry + bone_length * (ly-ry)/d, ly, stretch);
						lz = lerp(rz + bone_length * (lz-rz)/d, lz, stretch);
					}
					
					// Check against colliders
					if ( colliders_enabled ) {
						collider_index = 0;
						repeat(collider_count) {
							collider = animator.colliders[collider_index];
							n = 2;
							for (var i = 0; i <= n; i++) {
								cx = lerp(collider.vcurr[0], collider.vend[0], i/n);
								cy = lerp(collider.vcurr[1], collider.vend[1], i/n);
								cz = lerp(collider.vcurr[2], collider.vend[2], i/n);
							
								velx = vx - cx;
								vely = vy - cy;
								velz = vz - cz;
								d = point_distance_3d(0,0,0, velx, vely, velz) + 0.000001;
								if ( d < collider.radius ) {
									velx /= d; vely /= d; velz /= d;
									d = collider.radius;
									vx = cx + velx * d;
									vy = cy + vely * d;
									vz = cz + velz * d;
									d *= 0.9;
									lx = cx + velx * d;
									ly = cy + vely * d;
									lz = cz + velz * d;
								}
							}
							collider_index += 1;
						}
					}
					
					swg.vcurr[0] = vx; swg.vcurr[1] = vy; swg.vcurr[2] = vz;
					swg.vprev[0] = lx; swg.vprev[1] = ly; swg.vprev[2] = lz;
					swg.vgoal[0] = gx; swg.vgoal[1] = gy; swg.vgoal[2] = gz;
				
					// Convert from world-space Back to local-space ...............................
					vcurr = matrix_transform_vertex(minv, vx, vy, vz);
					lroot = matrix_transform_vertex(minv, rx, ry, rz);
					lgoal = matrix_transform_vertex(minv, gx, gy, gz);
				
					// Write rotation back to transform
					rollpt5 = clamp(arctan2(vcurr[2]-lroot[2], vcurr[1]-lroot[1]) * 0.5, swg.angle_min_x, swg.angle_max_x);
					pitchpt5 = 0.0;
					yawpt5 = clamp(-arctan2(vcurr[0]-lroot[0], vcurr[1]-lroot[1]) * 0.5, swg.angle_min_z, swg.angle_max_z);
					
					cx = cos(rollpt5);
					cy = 1.0; // cos(pitchpt5);
					cz = cos(yawpt5);
					sx = sin(rollpt5);
					sy = 0.0; // sin(pitchpt5);
					sz = sin(yawpt5);
					
					particle_length = point_distance_3d(vcurr[0], vcurr[1], vcurr[2], lroot[0], lroot[1], lroot[2]);
					//show_debug_message(string([bone_length, particle_length, particle_length / bone_length]));
					
					//transforms[@ transform_offset + VBM_T_LOCX] = 0.0;
					//transforms[@ transform_offset + VBM_T_LOCY] = 0.0;
					//transforms[@ transform_offset + VBM_T_LOCZ] = 0.0;
					
					transforms[@ transform_offset + VBM_T_QUATW] = cx*cy*cz - sx*sy*sz;
					transforms[@ transform_offset + VBM_T_QUATX] = sx*cy*cz + cx*sy*sz;
					transforms[@ transform_offset + VBM_T_QUATY] = cx*sy*cz - sx*cy*sz;
					transforms[@ transform_offset + VBM_T_QUATZ] = cx*cy*sz + sx*sy*cz;
					
					transforms[@ transform_offset + VBM_T_SCALEX] = 1.0;
					transforms[@ transform_offset + VBM_T_SCALEY] = particle_length / bone_length;
					transforms[@ transform_offset + VBM_T_SCALEZ] = 1.0;
					break;
				}
				swing_index += 1;
			}
		
			// Transform to Mat4 ...............................................
			qw = transforms[transform_offset+VBM_T_QUATW];
			qx = transforms[transform_offset+VBM_T_QUATX];
			qy = transforms[transform_offset+VBM_T_QUATY];
			qz = transforms[transform_offset+VBM_T_QUATZ]; 
			sx = transforms[transform_offset+VBM_T_SCALEX];
			sy = transforms[transform_offset+VBM_T_SCALEY];
			sz = transforms[transform_offset+VBM_T_SCALEZ];
		
			d = 1.0 / (sqrt(qw*qw+qx*qx+qy*qy+qz*qz) + 0.000001);
			qw *= d; qx *= d; qy *= d; qz *= d;
		
			// M = T * R * S, Mat4Compose(loc, quat, scale):
			xx = qx*qx; xy = qx*qy; xz = qx*qz; xw = qx*qw;
			yy = qy*qy; yz = qy*qz; yw = qy*qw;
			zz = qz*qz; zw = qz*qw;
			//ww = qw*qw;
			
			mA[@ VBM_M00] = (1.0 - 2.0 * (yy + zz)) * sx;
			mA[@ VBM_M01] = (2.0 * (xy - zw)) * sx;
			mA[@ VBM_M02] = (2.0 * (xz + yw)) * sx;
			mA[@ VBM_M03] = transforms[transform_offset+VBM_T_LOCX];
			mA[@ VBM_M10] = (2.0 * (xy + zw)) * sy;
			mA[@ VBM_M11] = (1.0 - 2.0 * (xx + zz)) * sy;
			mA[@ VBM_M12] = (2.0 * (yz - xw)) * sy;
			mA[@ VBM_M13] = transforms[transform_offset+VBM_T_LOCY];
			mA[@ VBM_M20] = (2.0 * (xz - yw)) * sz;
			mA[@ VBM_M21] = (2.0 * (yz + xw)) * sz;
			mA[@ VBM_M22] = (1.0 - 2.0 * (xx + yy)) * sz;
			mA[@ VBM_M23] = transforms[transform_offset+VBM_T_LOCZ];
			mA[@ VBM_M30] = 0.0; mA[@ VBM_M31] = 0.0; mA[@ VBM_M32] = 0.0; mA[@ VBM_M33] = 1.0;
		
			// Transform Offset (Local x transform.RST)
			mA = matrix_multiply(mA, bone_matlocal[bone_index]);	// = Transform
			
			// Model-Space Offset (Parent x Transform)
			animator.matworld[bone_index] = matrix_multiply(mA, animator.matworld[parentindices[bone_index]]);	// Model
			
			// Vertex-Space Offset (Model x InverseBind)
			mA = matrix_multiply(bone_matinverse[bone_index], animator.matworld[bone_index]);	// Final
			array_copy(outmat4arrayflat, bone_index*16, mA, 0, 16);
			
			// Write to Collider
			for (collider_index = 0; collider_index < animator.collider_count; collider_index++) {
				collider = animator.colliders[collider_index];
				if ( collider.bone_hash == bone_hash ) {
					// Get position of bone before local transform = Bone.Local x Parent.Absolute
					mswg = matrix_multiply(animator.bone_matlocal[bone_index], animator.matworld[parent_index]);
					bx = mswg[VBM_M03];
					by = mswg[VBM_M13];
					bz = mswg[VBM_M23];
				
					// Get position of goal = Swing.Offset x Bone.Local x Parent.Absolute
					vx = collider.offset[0];
					vy = collider.offset[1];
					vz = collider.offset[2];
					
					lgoal = matrix_transform_vertex(mswg, vx, vy, vz);
					collider.vcurr[0] = bx;
					collider.vcurr[1] = by;
					collider.vcurr[2] = bz;
					collider.vend[0] = lgoal[0];
					collider.vend[1] = lgoal[1];
					collider.vend[2] = lgoal[2];
				}
			}
			
			bone_index++;
		}
	
	}
	// No swing bones. Matrix evaluation only
	else {
		while (bone_index < bone_count) {
			transform_offset = bone_index*10;
			bone_hash = animator.bone_hashes[bone_index];
			
			// Transform to Mat4 ...............................................
			qw = transforms[transform_offset+VBM_T_QUATW];
			qx = transforms[transform_offset+VBM_T_QUATX];
			qy = transforms[transform_offset+VBM_T_QUATY];
			qz = transforms[transform_offset+VBM_T_QUATZ]; 
			sx = transforms[transform_offset+VBM_T_SCALEX];
			sy = transforms[transform_offset+VBM_T_SCALEY];
			sz = transforms[transform_offset+VBM_T_SCALEZ];
		
			d = 1.0 / (sqrt(qw*qw+qx*qx+qy*qy+qz*qz) + 0.000001);
			qw *= d; qx *= d; qy *= d; qz *= d;
		
			// M = T * R * S, Mat4Compose(loc, quat, scale):
			xx = qx*qx; xy = qx*qy; xz = qx*qz; xw = qx*qw;
			yy = qy*qy; yz = qy*qz; yw = qy*qw;
			zz = qz*qz; zw = qz*qw;
			//ww = qw*qw;
		
			mA[@ VBM_M00] = (1.0 - 2.0 * (yy + zz)) * sx;
			mA[@ VBM_M01] = (2.0 * (xy - zw)) * sx;
			mA[@ VBM_M02] = (2.0 * (xz + yw)) * sx;
			mA[@ VBM_M03] = transforms[transform_offset+VBM_T_LOCX];
			mA[@ VBM_M10] = (2.0 * (xy + zw)) * sy;
			mA[@ VBM_M11] = (1.0 - 2.0 * (xx + zz)) * sy;
			mA[@ VBM_M12] = (2.0 * (yz - xw)) * sy;
			mA[@ VBM_M13] = transforms[transform_offset+VBM_T_LOCY];
			mA[@ VBM_M20] = (2.0 * (xz - yw)) * sz;
			mA[@ VBM_M21] = (2.0 * (yz + xw)) * sz;
			mA[@ VBM_M22] = (1.0 - 2.0 * (xx + yy)) * sz;
			mA[@ VBM_M23] = transforms[transform_offset+VBM_T_LOCZ];
			mA[@ VBM_M30] = 0.0; mA[@ VBM_M31] = 0.0; mA[@ VBM_M32] = 0.0; mA[@ VBM_M33] = 1.0;
		
			// Transform Offset (Local x transform.RST)
			mA = matrix_multiply(mA, bone_matlocal[bone_index]);	// = Local
		
			// Model-Space Offset (Parent x Local)
			animator.matworld[bone_index] = matrix_multiply(mA, animator.matworld[parentindices[bone_index]]);	// Model
		
			// Vertex-Space Offset (Model x InverseBind)
			mA = matrix_multiply(bone_matinverse[bone_index], animator.matworld[bone_index]);	// Final
			array_copy(outmat4arrayflat, bone_index*16, mA, 0, 16);
		
			bone_index++;
		}
	}
	animator.benchmark[2] = get_timer()-animator.benchmark[2];
	animator.benchmark[0] = get_timer()-animator.benchmark[0];
	
}

function VBM_Animator_Update(animator, delta) {
	VBM_Animator_UpdateExt(animator, delta, 1, 1, 1);
}

#endregion // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#region // Global ===================================================================

function VBM_Init() {
	
}

function VBM_FormatFromKey(formatkey) {
	// Z YYY XXXX -> X = Attribute Type, Y = Size, Z = Isbyte
	var n = array_length(formatkey);
	var attribute;
	var size;
	var isbyte;
	var bytesum = 0;
	var vertex_type;
	
	vertex_format_begin();
	for (var i = 0; i < n; i++) {
		attribute = formatkey[i] & 0x0f;	// Bits 0-3
		size = (formatkey[i] >> 4) & 0x07;	// Bits 4-7
		isbyte = (formatkey[i] & VBM_ATTRIBUTE.IS_BYTE) != 0; // 8th bit
		
		if (size == 0) {continue;}
		
		if (isbyte) {
			bytesum += size;
			if ((bytesum % 4) == 0) {
				vertex_format_add_color();
			}
		}
		else {
			if (size == 1) {vertex_type = vertex_type_float1;}
			if (size == 2) {vertex_type = vertex_type_float2;}
			if (size == 3) {vertex_type = vertex_type_float3;}
			if (size == 4) {vertex_type = vertex_type_float4;}
			
			switch(attribute) {
				case(VBM_ATTRIBUTE.POSITION):
					if (size == 2) {
						vertex_format_add_position();
					}
					else {
						vertex_format_add_position_3d();
					}
					break;
				
				case(VBM_ATTRIBUTE.UV): 
					vertex_format_add_texcoord(); 
					break;
				case(VBM_ATTRIBUTE.NORMAL): 
					vertex_format_add_normal();
					break;
				
				default:
					vertex_format_add_custom(vertex_type, vertex_usage_texcoord); 
					break;
			}
		}
	}
	
	return vertex_format_end();
}

function VBM_FormatKeyStride(formatkey) {
	var stride = 0;
	var n = array_length(formatkey);
	for (var i = 0; i < n; i++) {
		stride += ((formatkey[i] >> 4) & 0x7) * ((formatkey[i] & VBM_ATTRIBUTE.IS_BYTE)? 1: 4);
	}
	return stride;
}

function VBM_OpenVBM(fpath, outvbm, flags=0) {
	var b = buffer_load(VBM_PROJECTPATH+fpath);
	
	if (b == -1) {
		show_debug_message("Error opening VBM file: " + fpath);
		return outvbm;
	}
	
	var bdecompressed = buffer_decompress(b);
	buffer_delete(b);
	b = bdecompressed;
	
	// Header Check ========================================================
	var headerchars = [0,0,0];
	headerchars[0] = buffer_read(b, buffer_u8);
	headerchars[1] = buffer_read(b, buffer_u8);
	headerchars[2] = buffer_read(b, buffer_u8);
	var header_version = buffer_read(b, buffer_u8);
	
	var header_is_vbm = (
		headerchars[0] == ord("V") &&
		headerchars[1] == ord("B") &&
		headerchars[2] == ord("M")
	);
	
	if ( !header_is_vbm ) {
		show_debug_message("File does not contain VBM header: " + fpath);
		return outvbm;
	}
	
	if ( header_version != 4 ) {
		show_debug_message("VBM Version invalid (Version " + string(header_version) + "): " + fpath);
		return outvbm;
	}
	
	// Resource Loop =====================================================
	var word = "";
	
	var mesh_index = 0;
	var animation_index = 0;
	var texture_index = 0;
	
	var restypestr = "", restypeversion = 0, reslength = 0;
	var rescount = buffer_read(b, buffer_u32);
	var resjump = 0;
	
	for (var res_index = 0; res_index < rescount; res_index++) {
		if ( buffer_tell(b) >= buffer_get_size(b) ) {
			break;
		}
		
		restypestr = ""; repeat(3) {restypestr += chr(buffer_read(b, buffer_u8));}
		restypeversion = buffer_read(b, buffer_u8);
		reslength = buffer_read(b, buffer_u32);
		resjump = buffer_tell(b) + reslength;
		
		// Texture .......................................................
		if (restypestr == "TEX") {
			word = ""; repeat(buffer_read(b, buffer_u8)) {word += chr(buffer_read(b, buffer_u8));}
			
			var w = buffer_read(b, buffer_u32);
			var h = buffer_read(b, buffer_u32);
			var palette_size = buffer_read(b, buffer_u8);
			var palette = array_create(palette_size);
			var texture_buffer = buffer_create(w*h*4, buffer_fixed, 4);
			
			for (var i = 0; i < palette_size; i++) {palette[i] = buffer_read(b, buffer_u32);}
			repeat(w*h) {buffer_write(texture_buffer, buffer_u32, palette[buffer_read(b, buffer_u8)]);}
			
			var surf = surface_create(w, h);
			buffer_set_surface(texture_buffer, surf, 0);
			var sprite = sprite_create_from_surface(surf, 0, 0, w, h, 0, 0, 0, 0);
			outvbm.texture_sprites[texture_index] = sprite;
			texture_index += 1;
			surface_free(surf);
			buffer_delete(texture_buffer);
			outvbm.texture_count += 1;
		}
		// Mesh .......................................................
		else if (restypestr == "MSH") {
			word = ""; repeat(buffer_read(b, buffer_u8)) {word += chr(buffer_read(b, buffer_u8));}
			var texture_index = buffer_read(b, buffer_u8);
			var material_index = buffer_read(b, buffer_u8);
			
			var bounds_min = array_create(3);
			var bounds_max = array_create(3);
			bounds_min[0] = buffer_read(b, buffer_f32);
			bounds_min[1] = buffer_read(b, buffer_f32);
			bounds_min[2] = buffer_read(b, buffer_f32);
			bounds_max[0] = buffer_read(b, buffer_f32);
			bounds_max[1] = buffer_read(b, buffer_f32);
			bounds_max[2] = buffer_read(b, buffer_f32);
			
			var formatkey = array_create(16);
			var format_size = buffer_read(b, buffer_u8);
			for (var format_index = 0; format_index < format_size; format_index++) {
				formatkey[@ format_index] = buffer_read(b, buffer_u8);
			}
			
			var mesh_flags = buffer_read(b, buffer_u8);
			var loop_count = buffer_read(b, buffer_u32);
			var buffer_size = buffer_read(b, buffer_u32);
			
			// Read Vertex Buffer
			var format = VBM_FormatFromKey(formatkey);
			var vb = vertex_create_buffer_from_buffer_ext(b, format, buffer_tell(b), loop_count);
			if ( (flags & VBM_OPENFLAGS.NOFREEZE) == 0 ) {
				vertex_freeze(vb);
			}
			
			buffer_seek(b, buffer_seek_relative, buffer_size);
			
			var mesh = new VBM_Mesh();
			mesh.name = word;
			mesh.format = format;
			mesh.formatkey = formatkey;
			mesh.vertex_buffer = vb;
			mesh.texture_sprite = (texture_index != 0xFF && outvbm.texture_count > 0)? outvbm.texture_sprites[texture_index]: -1;
			mesh.material_index = material_index;
			mesh.is_edge = ((flags & VBM_OPENFLAGS.ALL_EDGES)? 1: 0) || (mesh_flags & VBM_MESHFLAGS.IS_EDGE);
			array_copy(mesh.bounds_min, 0, bounds_min, 0, 3);
			array_copy(mesh.bounds_max, 0, bounds_max, 0, 3);
		
			outvbm.meshes[@ mesh_index] = mesh;
			outvbm.mesh_count += 1;
			mesh_index += 1;
		}
		// Skeleton ...................................................
		else if (restypestr == "SKE") {
			var seg;
			var skeleton = outvbm.skeleton;
			
			// Swing Data
			var numswing = buffer_read(b, buffer_u32);
			skeleton.swing_count = numswing;
			array_resize(skeleton.swing_bones, numswing);
			for (var i = 0; i < numswing; i++) {
				var swg = new VBM_SkeletonSwingBone();
				swg.friction = buffer_read(b, buffer_f32);
				swg.stiffness = buffer_read(b, buffer_f32);
				swg.dampness = buffer_read(b, buffer_f32);
				swg.gravity = buffer_read(b, buffer_f32);
				if (restypeversion >= 1) {
					swg.stretch = buffer_read(b, buffer_f32);
				}
				swg.offset[0] = buffer_read(b, buffer_f32);
				swg.offset[1] = buffer_read(b, buffer_f32);
				swg.offset[2] = buffer_read(b, buffer_f32);
				swg.angle_range_x[0] = buffer_read(b, buffer_f32);
				swg.angle_range_x[1] = buffer_read(b, buffer_f32);
				swg.angle_range_z[0] = buffer_read(b, buffer_f32);
				swg.angle_range_z[1] = buffer_read(b, buffer_f32);
				skeleton.swing_bones[i] = swg;
			}
			
			// Collider
			var numcollider = buffer_read(b, buffer_u32);
			skeleton.collider_count = numcollider;
			array_resize(skeleton.collider_bones, numcollider);
			for (var i = 0; i < numcollider; i++) {
				var collider = new VBM_SkeletonColliderBone();
				collider.radius = buffer_read(b, buffer_f32);
				collider.length = buffer_read(b, buffer_f32);
				collider.offset[0] = buffer_read(b, buffer_f32);
				collider.offset[1] = buffer_read(b, buffer_f32);
				collider.offset[2] = buffer_read(b, buffer_f32);
				skeleton.collider_bones[i] = collider;
			}
				
			// Read bone segments
			var numbones = buffer_read(b, buffer_u32);
			skeleton.bone_count = numbones;
			for (var t = 0; t < numbones; t++) {
				word = ""; repeat(buffer_read(b, buffer_u8)) {word += chr(buffer_read(b, buffer_u8));}
				skeleton.bone_names[t] = word;
				skeleton.bone_hashes[t] = VBM_StringHash(word);
				skeleton.bone_parentindex[t] = buffer_read(b, buffer_u32);	// Parent index
				skeleton.bone_segments[t][VBM_BONESEGMENT.head_x] = buffer_read(b, buffer_f32);	// head
				skeleton.bone_segments[t][VBM_BONESEGMENT.head_y] = buffer_read(b, buffer_f32);
				skeleton.bone_segments[t][VBM_BONESEGMENT.head_z] = buffer_read(b, buffer_f32);
				skeleton.bone_segments[t][VBM_BONESEGMENT.tail_x] = buffer_read(b, buffer_f32);	// tail
				skeleton.bone_segments[t][VBM_BONESEGMENT.tail_y] = buffer_read(b, buffer_f32);
				skeleton.bone_segments[t][VBM_BONESEGMENT.tail_z] = buffer_read(b, buffer_f32);
				skeleton.bone_segments[t][VBM_BONESEGMENT.roll] = buffer_read(b, buffer_f32);	// roll
				skeleton.bone_swingindex[t] = buffer_read(b, buffer_u8);	// Swing Index
				skeleton.bone_colliderindex[t] = buffer_read(b, buffer_u8);	// Collider Index
				seg = skeleton.bone_segments[t];
				skeleton.bone_segments[t][VBM_BONESEGMENT.length] = point_distance_3d(	// length
					seg[VBM_BONESEGMENT.head_x], seg[VBM_BONESEGMENT.head_y], seg[VBM_BONESEGMENT.head_z], 
					seg[VBM_BONESEGMENT.tail_x], seg[VBM_BONESEGMENT.tail_y], seg[VBM_BONESEGMENT.tail_z]
				);	
				
				if ( skeleton.bone_swingindex[t] >= 255 ) {skeleton.bone_swingindex[t] = -1;}
				if ( skeleton.bone_colliderindex[t] >= 255 ) {skeleton.bone_colliderindex[t] = -1;}
			}
	
			// Calculate Matrices
			var mbind = array_create(VBM_BONECAPACITY);
			var minverse = array_create(VBM_BONECAPACITY);
			var roll = 0;
				
			for (var t = 0; t < numbones; t++) {
				seg = skeleton.bone_segments[t];
				roll = seg[6];
				
				// Zero Rotation Bind makes for MUCH simpler math
				mbind[t] = matrix_build(seg[0], seg[1], seg[2], 0,0,0,1,1,1);
				minverse[t] = matrix_build(-seg[0], -seg[1], -seg[2], 0,0,0,1,1,1);
		
				__vbm_mat4axisroll(mbind[t], seg[0], seg[1], seg[2], seg[3], seg[4], seg[5], seg[6]);
				__vbm_mat4inverse(minverse[t], mbind[t]);
			}
	
			for (var t = 0; t < numbones; t++) {
				// Local = bind x inverse
				skeleton.bone_matlocal[t] = matrix_multiply(mbind[t], minverse[skeleton.bone_parentindex[t]]);
				skeleton.bone_matinverse[t] = minverse[t];
			}
		}
		// Animations .................................................
		else if (restypestr == "ANI") {
			var anim = new VBM_Animation();
			var animchannels, animchannel, animpoints;
			var duration;
			word = ""; repeat(buffer_read(b, buffer_u8)) {word += chr(buffer_read(b, buffer_u8));}
		
			anim.name = word;
			anim.flags = buffer_read(b, buffer_u32);
			anim.duration = buffer_read(b, buffer_u32);
			var numcurves = buffer_read(b, buffer_u32);
			var netnumkeyframes = buffer_read(b, buffer_u32);
			
			anim.curve_count = numcurves;
		
			var channeloffset = 0;
			var offset = 0;
			
			duration = anim.duration + 0.00001;	// Small addend to prevent NaN from division
			
			// Parse curves
			anim.animcurve = animcurve_create();
			animchannels = array_create(numcurves*10);
			
			for (var curve_index = 0; curve_index < numcurves; curve_index++) {
				word = ""; repeat(buffer_read(b, buffer_u8)) {word += chr(buffer_read(b, buffer_u8));}
				var numchannels = buffer_read(b, buffer_u32);
				anim.curve_names[curve_index] = word;
				anim.curve_namehashes[curve_index] = VBM_StringHash(word);
				anim.curve_views[curve_index*2+0] = channeloffset;
				anim.curve_views[curve_index*2+1] = numchannels;
				
				for (var channel_index = 0; channel_index < numchannels; channel_index++) {
					var framecount = buffer_read(b, buffer_u32);
					
					animchannel = animcurve_channel_new();
					animpoints = array_create(framecount+1);
					animchannel.type = animcurvetype_linear;
					
					// Initialize point array
					for ( var f = 0; f <= framecount; f++ ) {
						animpoints[f] = animcurve_point_new();
					}
					// Read Keyframe Positions
					for (var f = 0; f < framecount; f++) {
						animpoints[f].posx = buffer_read(b, buffer_f32) / duration;
					}
					// Read Keyframe Values
					for (var f = 0; f < framecount; f++) {
						animpoints[f].value = buffer_read(b, buffer_f32);
					}
					
					// Extra point at end of curve to match duration
					animpoints[framecount] = animcurve_point_new();
					animpoints[framecount].posx = 1.0;
					animpoints[framecount].value = animpoints[framecount-1].value;
					
					// Add data to channel
					if ( numchannels > 0 ) {
						animchannel.name = word;	// Skip on index if single channel
					}
					else {
						animchannel.name = word+"["+string(channel_index)+"]";
					}
					animchannel.points = animpoints;
					animchannels[channeloffset] = animchannel;
					
					channeloffset += 1;
				}
			}
			
			anim.animcurve.channels = animchannels;
			
			if ( (flags & VBM_OPENFLAGS.BAKE_TRANSFORM) ) {
				VBM_Animation_BakeAnimationTransforms(anim);
			}
			
			if ( (flags & VBM_OPENFLAGS.BAKE_LOCAL) ) {
				VBM_Animation_BakeAnimationLocal(anim);
			}
			
			outvbm.animations[@ animation_index] = anim;
			outvbm.animation_count += 1;
			animation_index += 1;
		}
		
		// Jump to next resource
		buffer_seek(b, buffer_seek_start, resjump);
	}
	
	buffer_delete(b);
}

function VBM_SetProjectPath(fdir) {
	VBM_PROJECTPATH = fdir;
}

#endregion // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

#region // Math =====================================================================

function __vbm_mat4multiply(outmat4, a, b) {
	var m = matrix_multiply(a, b);
	array_copy(outmat4, 0, m, 0, 16);
}

function __vbm_mat4compose(outmat4, x,y,z, qw,qx,qy,qz, sx,sy,sz) {
	var d = 1.0 / sqrt(qw*qw+qx*qx+qy*qy+qz*qz);
	qw *= d; qx *= d; qy *= d; qz *= d;
		
	// M = T * R * S, Mat4Compose(loc, quat, scale):
	var xx = qx*qx, xy = qx*qy, xz = qx*qz, xw = qx*qw;
	var yy = qy*qy, yz = qy*qz, yw = qy*qw;
	var zz = qz*qz, zw = qz*qw;
		
	outmat4[@ VBM_M00] = (1.0 - 2.0 * (yy + zz)) * sx;
	outmat4[@ VBM_M01] = (2.0 * (xy - zw)) * sx;
	outmat4[@ VBM_M02] = (2.0 * (xz + yw)) * sx;
	outmat4[@ VBM_M03] = x;
	outmat4[@ VBM_M10] = (2.0 * (xy + zw)) * sy;
	outmat4[@ VBM_M11] = (1.0 - 2.0 * (xx + zz)) * sy;
	outmat4[@ VBM_M12] = (2.0 * (yz - xw)) * sy;
	outmat4[@ VBM_M13] = y;
	outmat4[@ VBM_M20] = (2.0 * (xz - yw)) * sz;
	outmat4[@ VBM_M21] = (2.0 * (yz + xw)) * sz;
	outmat4[@ VBM_M22] = (1.0 - 2.0 * (xx + yy)) * sz;
	outmat4[@ VBM_M23] = z;
	outmat4[@ VBM_M30] = 0.0; outmat4[@ VBM_M31] = 0.0; outmat4[@ VBM_M32] = 0.0; outmat4[@ VBM_M33] = 1.0;
}

function __vbm_mat4decompose(outfloat10, m) {
	// Source: https://www.euclideanspace.com/maths/geometry/rotations/conversions/matrixToQuaternion/
	var qw = sqrt(1.0 + m[VBM_M00] + m[VBM_M11] + m[VBM_M22]) * 0.5;
	var qw4inv = 1.0 / (4.0 * qw);
	
	outfloat10[@ VBM_T_LOCX] = m[VBM_M03];
	outfloat10[@ VBM_T_LOCY] = m[VBM_M13];
	outfloat10[@ VBM_T_LOCZ] = m[VBM_M23];
	outfloat10[@ VBM_T_QUATW] = qw;
	outfloat10[@ VBM_T_QUATX] = (m[VBM_M21] - m[VBM_M12]) * qw4inv;
	outfloat10[@ VBM_T_QUATY] = (m[VBM_M02] - m[VBM_M20]) * qw4inv;
	outfloat10[@ VBM_T_QUATZ] = (m[VBM_M10] - m[VBM_M01]) * qw4inv;
}

function __vbm_mat4inverse(outmat4, msrc) {
	// Source MESA GLu library: https://www.mesa3d.org/
	var m00 = msrc[ 0], m01 = msrc[ 1], m02 = msrc[ 2], m03 = msrc[ 3];
	var m04 = msrc[ 4], m05 = msrc[ 5], m06 = msrc[ 6], m07 = msrc[ 7];
	var m08 = msrc[ 8], m09 = msrc[ 9], m10 = msrc[10], m11 = msrc[11];
	var m12 = msrc[12], m13 = msrc[13], m14 = msrc[14], m15 = msrc[15];
	
    var d;	// Determinant
	outmat4[@ 0] = m05*m10*m15-m05*m11*m14-m09*m06*m15+m09*m07*m14+m13*m06*m11-m13*m07*m10;
    outmat4[@ 4] =-m04*m10*m15+m04*m11*m14+m08*m06*m15-m08*m07*m14-m12*m06*m11+m12*m07*m10;
    outmat4[@ 8] = m04*m09*m15-m04*m11*m13-m08*m05*m15+m08*m07*m13+m12*m05*m11-m12*m07*m09;
    outmat4[@12] =-m04*m09*m14+m04*m10*m13+m08*m05*m14-m08*m06*m13-m12*m05*m10+m12*m06*m09;
    outmat4[@ 1] =-m01*m10*m15+m01*m11*m14+m09*m02*m15-m09*m03*m14-m13*m02*m11+m13*m03*m10;
    outmat4[@ 5] = m00*m10*m15-m00*m11*m14-m08*m02*m15+m08*m03*m14+m12*m02*m11-m12*m03*m10;
    outmat4[@ 9] =-m00*m09*m15+m00*m11*m13+m08*m01*m15-m08*m03*m13-m12*m01*m11+m12*m03*m09;
    outmat4[@13] = m00*m09*m14-m00*m10*m13-m08*m01*m14+m08*m02*m13+m12*m01*m10-m12*m02*m09;
    outmat4[@ 2] = m01*m06*m15-m01*m07*m14-m05*m02*m15+m05*m03*m14+m13*m02*m07-m13*m03*m06;
    outmat4[@ 6] =-m00*m06*m15+m00*m07*m14+m04*m02*m15-m04*m03*m14-m12*m02*m07+m12*m03*m06;
    outmat4[@10] = m00*m05*m15-m00*m07*m13-m04*m01*m15+m04*m03*m13+m12*m01*m07-m12*m03*m05;
    outmat4[@14] =-m00*m05*m14+m00*m06*m13+m04*m01*m14-m04*m02*m13-m12*m01*m06+m12*m02*m05;
    outmat4[@ 3] =-m01*m06*m11+m01*m07*m10+m05*m02*m11-m05*m03*m10-m09*m02*m07+m09*m03*m06;
    outmat4[@ 7] = m00*m06*m11-m00*m07*m10-m04*m02*m11+m04*m03*m10+m08*m02*m07-m08*m03*m06;
    outmat4[@11] =-m00*m05*m11+m00*m07*m09+m04*m01*m11-m04*m03*m09-m08*m01*m07+m08*m03*m05;
    outmat4[@15] = m00*m05*m10-m00*m06*m09-m04*m01*m10+m04*m02*m09+m08*m01*m06-m08*m02*m05;
	
    d = 1.0 / (m00 * outmat4[0] + m01 * outmat4[4] + m02 * outmat4[8] + m03 * outmat4[12] + 0.00001);	// Assumes determinant > 0. Error otherwise
    outmat4[@ 0] *= d; outmat4[@ 1] *= d; outmat4[@ 2] *= d; outmat4[@ 3] *= d;
    outmat4[@ 4] *= d; outmat4[@ 5] *= d; outmat4[@ 6] *= d; outmat4[@ 7] *= d;
    outmat4[@ 8] *= d; outmat4[@ 9] *= d; outmat4[@10] *= d; outmat4[@11] *= d;
    outmat4[@12] *= d; outmat4[@13] *= d; outmat4[@14] *= d; outmat4[@15] *= d;
}

function __vbm_mat4axisroll(outmat4, headx, heady, headz, tailx, taily, tailz, roll) {
	/*
        Sourced from:
        https://github.com/blender/blender/blob/31aa0f9a5d1d735ab6cb8a4eb1a91ffbbfac7873/source/blender/blenkernel/intern/armature.cc#L2484
    */
	
    // Bonematrix = Axis Roll
    var nx = tailx - headx;
    var ny = taily - heady;
    var nz = tailz - headz;
    var d = 1.0 / (sqrt(nx*nx + ny*ny + nz*nz));
    nx *= d; ny *= d; nz *= d;

    var theta = 1.0+ny;
    var theta_alt = nx*nx + nz*nz;

    var bMatrix = matrix_build_identity();
	var rMatrix = matrix_build_identity();
    
    //memset(&bMatrix[0], 0, 16*sizeof(float));
    bMatrix[VBM_M00] = 1.0; bMatrix[VBM_M11] = 1.0; bMatrix[VBM_M22] = 1.0; bMatrix[VBM_M33] = 1.0;
    if (theta > 0.0061 || theta_alt > (0.00025*0.00025)) {
        bMatrix[VBM_M10] = -nx;
        bMatrix[VBM_M01] = nx;
        bMatrix[VBM_M11] = ny;
        bMatrix[VBM_M21] = nz;
        bMatrix[VBM_M12] = -nz;
        if (theta <= 0.0061) {
            theta = theta_alt * 0.5 + theta_alt * theta_alt * 0.125;
        }
        bMatrix[VBM_M00] = 1.0-nx*nx / theta;
        bMatrix[VBM_M22] = 1.0-nz*nz / theta;
        bMatrix[VBM_M02] = -nx*nz / theta;
        bMatrix[VBM_M20] = -nx*nz / theta;
    }
    else {
        bMatrix[VBM_M00] = -1.0;
        bMatrix[VBM_M11] = -1.0;
    }

    // Rollmatrix = Quat to Mat4
    var qw = cos(roll*0.5);
    var qx = sin(roll*0.5) * nx;
    var qy = sin(roll*0.5) * ny;
    var qz = sin(roll*0.5) * nz;

    rMatrix[VBM_M00] = 1.0 - 2.0 * (qy*qy + qz*qz);
    rMatrix[VBM_M01] = 2.0 * (qx*qy - qz*qw);
    rMatrix[VBM_M02] = 2.0 * (qx*qz + qy*qw);
    rMatrix[VBM_M03] = 0.0;
    rMatrix[VBM_M10] = 2.0 * (qx*qy + qz*qw);
    rMatrix[VBM_M11] = 1.0 - 2.0 * (qx*qx + qz*qz);
    rMatrix[VBM_M12] = 2.0 * (qy*qz - qx*qw);
    rMatrix[VBM_M13] = 0.0;
    rMatrix[VBM_M20] = 2.0 * (qx*qz - qy*qw);
    rMatrix[VBM_M21] = 2.0 * (qy*qz + qx*qw);
    rMatrix[VBM_M22] = 1.0 - 2.0 * (qx*qx + qy*qy);
    rMatrix[VBM_M23] = 0.0;
    rMatrix[VBM_M30] = 0.0; rMatrix[VBM_M31] = 0.0; rMatrix[VBM_M32] = 0.0; rMatrix[VBM_M33] = 1.0;

    // Bind = (mroll x mbone)
    __vbm_mat4multiply(outmat4, bMatrix, rMatrix); // transformation is SECOND argument

    outmat4[@VBM_M03] = headx;
    outmat4[@VBM_M13] = heady;
    outmat4[@VBM_M23] = headz;
}

function __vbm_mat4string(m, index=0) {
	var s = "";
	for (var i = 0; i < 16; i++) {
		s += string_format(m[index*16+(i div 4)+(i%4)*4], 4, 4) + ((i>0&&((i+1)%4)==0)? "\n": "");
	}
	return s;
}

function __vbm_transformstring(t, index=0) {
	return "{" +
		"<" +
		string_format(t[index*10+VBM_T_LOCX], 2,2) + ", " +
		string_format(t[index*10+VBM_T_LOCY], 2,2) + ", " +
		string_format(t[index*10+VBM_T_LOCZ], 2,2) + ", " +
		"> " +
		"<" +
		string_format(t[index*10+VBM_T_QUATW], 2,2) + ", " +
		string_format(t[index*10+VBM_T_QUATX], 2,2) + ", " +
		string_format(t[index*10+VBM_T_QUATY], 2,2) + ", " +
		string_format(t[index*10+VBM_T_QUATZ], 2,2) + ", " +
		"> " +
		"<" +
		string_format(t[index*10+VBM_T_SCALEX], 2,2) + ", " +
		string_format(t[index*10+VBM_T_SCALEY], 2,2) + ", " +
		string_format(t[index*10+VBM_T_SCALEZ], 2,2) + ", " +
		">" +
	"}";
}

function __vbm_transformblend(tout, offset, ta, offset_a, tb, offset_b, amt) {
	repeat(10) {
		tout[@ offset] = lerp(ta[offset_a], tb[offset_b], amt);
		offset_a++;
		offset_b++;
		offset++;
	}
}

#endregion // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

