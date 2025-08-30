/*
	DmrVBM v1.5 by @sandman13sq
	Library used for 3D model support in Game Maker.
	GitHub Repository: https://github.com/Sandman13sq/DmrVBM-blender-to-gms2
*/

// ===========================================================
#region // CONSTANTS
// ===========================================================

// M[Y][X]
/*
	M00	M01	M02	M03
	M10	M11	M12	M13
	M20	M21	M22	M23
	M30	M31	M32	M33
	
	rx	ux	fx	x
	ry	uy	fy	y
	rz	uz	fz	z
	0.0	0.0	0.0 w=1.0
*/
#macro VBM_M00  0
#macro VBM_M10  1
#macro VBM_M20  2
#macro VBM_M30  3
#macro VBM_M01  4
#macro VBM_M11  5
#macro VBM_M21  6
#macro VBM_M31  7
#macro VBM_M02  8
#macro VBM_M12  9
#macro VBM_M22 10
#macro VBM_M32 11
#macro VBM_M03 12
#macro VBM_M13 13
#macro VBM_M23 14
#macro VBM_M33 15

enum VBM_TRANSFORM {
	x, y, z, qw, qx, qy, qz, sx, sy, sz, _len
};

// For Game Maker, "heavier" matrix is second argument: mat4_multiply(m, mparent)
#macro VBM_MAT4_MUTLIPLY matrix_multiply

#macro VBM_NULLINDEX ~0

// Attribute mask
enum VBM_FORMATMASK {
	POSITION =	0b000000001,
	NORMAL =	0b000000010,
	TANGENT =	0b000000100,
	BITANGENT =	0b000001000,
	COLOR =		0b000010000,
	UV =		0b000100000,
	UV2 =		0b001000000,
	BONE =		0b010000000,
	WEIGHT =	0b100000000,
};

#macro VBM_FORMAT_NATIVE (VBM_FORMATMASK.POSITION | VBM_FORMATMASK.COLOR | VBM_FORMATMASK.UV | (VBM_FORMATMASK.COLOR<<16))

// Uniform names for textures. Don't HAVE to be used.
#macro VBM_UNIFORMNAME_TEXTURE0 "texture0"
#macro VBM_UNIFORMNAME_TEXTURE1 "texture1"
#macro VBM_UNIFORMNAME_TEXTURE2 "texture2"
#macro VBM_UNIFORMNAME_TEXTURE3 "texture3"

// Matrix limit on v2022 LTS is 128...?
#macro VBM_BONELIMIT 240
#macro VBM_BONECAPACITY 200

#macro VBM_SUBMIT_TEXDEFAULT -1
#macro VBM_SUBMIT_TEXNONE 0

#endregion

// ===========================================================
#region // MATH
// ===========================================================

function vbm_transform_identity_array_1d(n) {
	var outtransforms = array_create(16*n);
	outtransforms[VBM_TRANSFORM.qw] = 1.0;
	outtransforms[VBM_TRANSFORM.sx] = 1.0;
	outtransforms[VBM_TRANSFORM.sy] = 1.0;
	outtransforms[VBM_TRANSFORM.sz] = 1.0;
	
	// Copy array to itself with increasing size and offset. O(log2)
	var p = 1, s = VBM_TRANSFORM._len;
	while ( (p<<1) < n ) {
		array_copy(outtransforms, s*p, outtransforms, 0, s*p);
		p = p << 1;
	}
	array_copy(outtransforms, s*(n-p), outtransforms, 0, s*p);	// Leftover values
	return outtransforms;
}

function vbm_transform_identity_array_2d(n) {
	var outarray = array_create(n);
	for (var i = 0; i < n; i++) {
		outarray[i] = array_create(VBM_TRANSFORM._len);
		outarray[i][VBM_TRANSFORM.qw] = 1.0;
		outarray[i][VBM_TRANSFORM.sx] = 1.0;
		outarray[i][VBM_TRANSFORM.sy] = 1.0;
		outarray[i][VBM_TRANSFORM.sz] = 1.0;
	}
	return outarray;
}

function vbm_mat4_identity_array_1d(n) {
	var outmat4 = array_create(16*n);
	outmat4[VBM_M00] = 1.0;
	outmat4[VBM_M11] = 1.0;
	outmat4[VBM_M22] = 1.0;
	outmat4[VBM_M33] = 1.0;
	
	// Copy array to itself with increasing size and offset. O(log2)
	var p = 1, s = 16;
	while ( (p<<1) < n ) {
		array_copy(outmat4, s*p, outmat4, 0, s*p);
		p = p << 1;
	}
	array_copy(outmat4, s*(n-p), outmat4, 0, s*p);	// Leftover values
	return outmat4;
}

function vbm_mat4_identity_array_2d(n) {
	return array_create_ext(n, matrix_build_identity);
}

function vbm_mat4_compose(outmat4, outmat4_offset, x, y, z, qw, qx, qy, qz, sx, sy, sz) {
	// M = T * R * S, Mat4Compose(loc, quat, scale):
    var xx = qx*qx, xy = qx*qy, xz = qx*qz, xw = qx*qw;
	var yy = qy*qy, yz = qy*qz, yw = qy*qw, zz = qz*qz, zw = qz*qw;

    outmat4[@ outmat4_offset+VBM_M00] = (1.0 - 2.0 * (yy + zz)) * sx;
    outmat4[@ outmat4_offset+VBM_M01] = (2.0 * (xy - zw)) * sx;
    outmat4[@ outmat4_offset+VBM_M02] = (2.0 * (xz + yw)) * sx;
    outmat4[@ outmat4_offset+VBM_M03] = x;
    outmat4[@ outmat4_offset+VBM_M10] = (2.0 * (xy + zw)) * sy;
    outmat4[@ outmat4_offset+VBM_M11] = (1.0 - 2.0 * (xx + zz)) * sy;
    outmat4[@ outmat4_offset+VBM_M12] = (2.0 * (yz - xw)) * sy;
    outmat4[@ outmat4_offset+VBM_M13] = y;
    outmat4[@ outmat4_offset+VBM_M20] = (2.0 * (xz - yw)) * sz;
    outmat4[@ outmat4_offset+VBM_M21] = (2.0 * (yz + xw)) * sz;
    outmat4[@ outmat4_offset+VBM_M22] = (1.0 - 2.0 * (xx + yy)) * sz;
    outmat4[@ outmat4_offset+VBM_M23] = z;
    outmat4[@ outmat4_offset+VBM_M30] = 0.0;
    outmat4[@ outmat4_offset+VBM_M31] = 0.0;
    outmat4[@ outmat4_offset+VBM_M32] = 0.0;
    outmat4[@ outmat4_offset+VBM_M33] = 1.0;
}

function vbm_boneparticle_array_1d(n) {
	return array_create(VBM_BONEPARTICLE._len*n);
}

#endregion

// ===========================================================
#region // MODEL ELEMENTS
// ===========================================================

// Meshdef --------------------------------------------------------------------
function VBM_ModelMeshdef() constructor {
	name = "";
	loop_start = 0;	// First loop (vertex) in vertex buffer
	loop_count = 0;	// Number of loops (vertices) to draw
	material_index = 0;
	bone_index = 0;	// Parent bone transform
	layer_mask = 0;	// Bitmask representing layers mesh is part of
	bounds = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]];	// min and max coords of mesh loops
};

/// @desc Revmoves allocated data from struct
/// @param {Struct.VBM_ModelMeshdef} meshdef
function VBM_ModelMeshdef_Free(meshdef) {
	// Nothing yet
};

// Prism --------------------------------------------------------------------
enum VBM_PRISMTRIANGLE {
	v0x, v0y, v0z,	// Vertex 1
	v1x, v1y, v1z,	// Vertex 2
	v2x, v2y, v2z,	// Vertex 3
	nx, ny, nz,		// Normal vector
	cx, cy, cz,		// Center
	layer_mask,		// Layer
	_len
};
function VBM_ModelPrism() constructor {
	name = "";
	bone_index = 0;	// Parent bone transform
	triangles = [];	// Flat list of VBM_PRISMTRIANGLE data
	bounds = [[0.0, 0.0, 0.0], [0.0, 0.0, 0.0]];	// min and max coords of vertices
};

/// @desc Revmoves allocated data from struct
/// @param {Struct.VBM_ModelPrism} prism
function VBM_ModelPrism_Free(prism) {
	// Nothing yet
};

// Bone --------------------------------------------------------------------

enum VBM_BONEFLAGS {
	HIDDEN		 = 1,
	SWINGBONE	 = 2,
	HASPROPS	 = 4,
};

enum VBM_BONEPARTICLE {
	xcurr, ycurr, zcurr, xlast, ylast, zlast, _len
};

function VBM_ModelBoneSwing() constructor {
	stiffness = 0.0;	// Speed that bone approaches goal. [low wiggle:high wiggle]
	damping = 0.0;		// Slows change in bone transform. [slow resolve:fast resolve]
	stretch = 0.0;		// Controls particle distance from goal. [low distance:high distance]
	smoothness = 0.0;	// Rotates direction towards goal when far
	limit = 0.0;		// Controls how far particle is allowed to rotate from goal. [full rotation:no rotation]
	gravity = 0.0;
	force_strength = 1.0;
};
function VBM_ModelBone() constructor {
	name = "";
	flags = 0;	// see VBM_BONEFLAGS enum
	matrix_bind = matrix_build_identity();	// Matrix relative to model origin
	matrix_inversebind = matrix_build_identity();	// Inverse of bind matrix. Used for vertex skinning
	matrix_relative = matrix_build_identity();	// Matrix relative to parent bone
	parent_index = 0;	// Index of parent bone
	length = 0.0;
	layer_mask = 0;		// Bitmask representing layers bone is part of.
	swing = new VBM_ModelBoneSwing();
	props = {};	// Extra properties exported with model. (Ex: Light color, Light power, object color, etc.)
};

/// @desc Revmoves allocated data from struct
/// @param {Struct.VBM_ModelBone} bone
function VBM_ModelBone_Free(bone) {
	delete bone.swing;
	delete bone.props;
};

/// @param {Struct.VBM_ModelBone} bone
/// @return {Bool}
function VBM_ModelBone_SwingEnabled(bone) {
	return (bone.swing.stiffness > 0.0) && (bone.swing.damping > 0.0);
}

/// @param {Struct.VBM_ModelBone} bone
/// @return {Bool}
function VBM_ModelBone_IsVisible(bone) {
	return (bone.flags & VBM_BONEFLAGS.HIDDEN) == 0;
}

/// @desc Returns parent index of bone
/// @param {Struct.VBM_ModelBone} bone
/// @return {Real}
function VBM_ModelBone_GetParentIndex(bone) {return bone.parent_index;}

/// @desc Returns model-space matrix of bone
/// @param {Struct.VBM_ModelBone} bone
/// @return {Array<Real>}
function VBM_ModelBone_GetMatrixBind(bone) {return bone.matrix_bind;}

/// @desc Returns inverse bind matrix of bone
/// @param {Struct.VBM_ModelBone} bone
/// @return {Array<Real>}
function VBM_ModelBone_GetMatrixInversebind(bone) {return bone.matrix_inversebind;}

/// @desc Returns bone-space matrix of bone
/// @param {Struct.VBM_ModelBone} bone
/// @return {Array<Real>}
function VBM_ModelBone_GetMatrixRelative(bone) {return bone.matrix_relative;}

// Material --------------------------------------------------------------------
enum VBM_MATERIALFLAG {
	TRANSPARENT  = 0b00000001,
	CULLFRONT	 = 0b00000010,
	USEDEPTH	 = 0b00000100,
};

enum VBM_MATERIALTEXTUREFLAG {
	FILTERLINEAR =	0b00000010,
	EXTEND =		0b00000100,
};

function VBM_ModelMaterial() constructor {
	name = "";
	shader_name = "";
	flags = 0;	// Mask of VBM_MATERIAL_FLAG values
	
	// Total of 4 texture_sprites
	texture_flags = [0,0,0,0];	// Mask of VBM_MATERIALTEXTUREFLAG values
	texture_indices = [0,0,0,0];	
	texture_paths = ["","","",""];
};

/// @desc Revmoves allocated data from struct
/// @param {Struct.VBM_ModelMaterial} material
function VBM_ModelMaterial_Free(material) {
	// Nothing yet
};

// Animation --------------------------------------------------------------------
enum VBM_ANIMATIONFLAG {
	CURVENAMES =	 0b00000001,
	BAKEDTRANSFORM = 0b00000010,
	BAKEDRELATIVE =  0b00000100,
	BAKEDORIGIN =	 0b00001000,
	BAKEDSKINNING =	 0b00010000,
};
enum VBM_ANIMATIONVIEW {offset, size, _len};

function VBM_ModelAnimation() constructor {
	name = "";
	animcurve = -1;	// GM animation curve asset containing channel keyframe data.
	curve_count = 0;	// Total number of curves
	curve_views = [];	// Flat array of VBM_ANIMATIONVIEW to index into animcurve.
	curve_lookup = {};	// {Curvename: curve_index} for each curve
	curve_names = [];	// Array of curve names matching index.
	
	props_offset = 0;	// First curve index of property curves (which is also the number of bone curves).
	fps_native = 60.0;	// Frames per second animation was exported in
	duration = 0.0;		// Maximum frame of animation
	loop_point = 0.0;	// Position to start from when sample frame exceeds duration
	flags = 0;
	namesum = 0;	// Sum of curve names. Faster when paired with equal bonesum
	
	baked_transforms_1d = [];	// array[ real[16*len(VBM_TRANSFORM)*curve_count], ... ] Fits model with same orientation
	baked_matrices_relative_2d = [];	// array[ matrix[curve_count], ... ] relative to parent bone. Fits model with same orientation
	baked_matrices_origin_2d = [];	// array[ matrix[curve_count], ... ] in model origin-space. Fits model with same bind pose
	baked_matrices_skinning_1d = [];	// array[ real[16*curve_count], ... ] in inverse bind-space. Fits model with same bind pose
};

/// @desc Revmoves allocated data from struct
/// @param {Struct.VBM_ModelAnimation} animation
function VBM_ModelAnimation_Free(animation) {
	animcurve_destroy(animation.animcurve);
	delete animation.curve_lookup;
};

/// @param {Struct.VBM_ModelAnimation} animation
/// @return {String}
function VBM_ModelAnimation_GetName(animation) {
	return animation.name;
}

/// @param {Struct.VBM_ModelAnimation} animation
/// @return {Asset.GMAnimCurve}
function VBM_ModelAnimation_GetAnimcurve(animation) {
	return animation.animcurve;
}

/// @param {Struct.VBM_ModelAnimation} animation
/// @return {Real}
function VBM_ModelAnimation_GetDuration(animation) {
	return animation.duration;
}

/// @param {Struct.VBM_ModelAnimation} animation
/// @param {Real} curve_index
/// @return {String}
function VBM_ModelAnimation_GetCurveName(animation, curve_index) {
	return animation.curve_names[curve_index];
}

/// @desc Returns number of channels in curve
/// @param {Struct.VBM_ModelAnimation} animation
/// @param {Real} curve_index
/// @return {Real}
function VBM_ModelAnimation_GetCurveSize(animation, curve_index) {
	return animation.curve_views[curve_index*VBM_ANIMATIONVIEW._len+VBM_ANIMATIONVIEW.size];
}

/// @desc Returns animation frame corrected with animation loop point
/// @param {Struct.VBM_ModelAnimation} animation
/// @param {Real} frame
/// @return {Real}
function VBM_ModelAnimation_EvaluateFrame(animation, frame) {
	return (frame > animation.duration)?
		((frame-animation.loop_point) % (animation.duration+1)) + animation.loop_point:
		frame;
}

/// @desc Returns normalized position of animation frame
/// @param {Struct.VBM_ModelAnimation} animation
/// @param {Real} frame
/// @return {Real}
function VBM_ModelAnimation_EvaluateFramePosition(animation, frame) {
	return VBM_ModelAnimation_EvaluateFrame(animation, frame) / animation.duration;
}

function VBM_ModelAnimation_GetCurveIndex(animation, curve_name) {
	var index = animation.curve_lookup[$ curve_name];
	return is_undefined(index)? -1: index;
}

/// @desc Returns curve index of first property curve, which is also the number of bone curves (if any)
/// @param {Struct.VBM_ModelAnimation} animation
/// @return {Real}
function VBM_ModelAnimation_GetPropertyOffset(animation) {
	return animation.props_offset;
}

function VBM_ModelAnimation_GetPropertyCount(animation) {
	return animation.curve_count - animation.props_offset;
}

/// @desc Samples value from animation curve
/// @param {Struct.VBM_ModelAnimation} animation
/// @param {Real} curve_index
/// @param {Real} channel_index
/// @param {Real} frame
/// @param {Real} default_value
/// @return {Real}
function VBM_ModelAnimation_SampleCurveIndex(animation, curve_index, channel_index, frame, default_value) {
	return animcurve_channel_evaluate(
		animation.animcurve.channels[animation.curve_views[curve_index*VBM_ANIMATIONVIEW._len+VBM_ANIMATIONVIEW.offset]+channel_index],
		VBM_ModelAnimation_EvaluateFramePosition(animation, frame)
	);
}

/// @desc Samples value from animation curve
/// @param {Struct.VBM_ModelAnimation} animation
/// @param {String} curve_name
/// @param {Real} channel_index
/// @param {Real} frame
/// @param {Real} default_value
/// @return {Real}
function VBM_ModelAnimation_SampleCurveName(animation, curve_name, channel_index, frame, default_value) {
	var curve_index = animation.curve_lookup[$ curve_name];
	return is_undefined(curve_index)? default_value: VBM_ModelAnimation_SampleCurveIndex(animation, curve_index, channel_index, frame, default_value);
}

/// @desc Samples property values from animation
/// @param {Struct.VBM_ModelAnimation} animation
/// @param {Real} frame
/// @param {Struct} outstruct
/// @return {Real}
function VBM_ModelAnimation_SampleProps_Struct(animation, frame, outstruct) {
	var n = animation.curve_count;
	var curvename = "";
	var channel;
	var numchannels;
	var channel_index;
	var channel_offset;
	var animcurve = animation.animcurve;
	var pos = VBM_ModelAnimation_EvaluateFramePosition(animation, frame);
	
	for (var curve_index = animation.props_offset; curve_index < n; curve_index++) {
		channel_offset = animation.curve_views[curve_index*VBM_ANIMATIONVIEW._len+VBM_ANIMATIONVIEW.offset];
		numchannels = animation.curve_views[curve_index*VBM_ANIMATIONVIEW._len+VBM_ANIMATIONVIEW.size];
		curvename = animation.curve_names[curve_index];
		
		// Reserve space for channel values
		if ( !variable_struct_exists(outstruct, curvename) ) {
			outstruct[$ curvename] = array_create(numchannels);
		}
		
		// Iterate channels
		channel_index = 0;
		repeat(numchannels) {
			outstruct[$ curvename][channel_index] = animcurve_channel_evaluate(
				animcurve.channels[channel_offset+channel_index], pos
			);
			channel_index++;
		}
	}
}

/// @desc Returns index of closest triangle hit in ray cast. -1 if no triangles are hit
/// @param {Struct.VBM_ModelPrism} prism
/// @param {Array<Real>} matprism
/// @param {Real} rx
/// @param {Real} ry
/// @param {Real} rz
/// @param {Real} dx
/// @param {Real} dy
/// @param {Real} dz
/// @param {Real} dist_start
/// @param {Real} dist_end
/// @param {Array<Real>} [outintersection3]
/// @param {Array<Real>} [outnormal3]
function VBM_ModelPrism_CastRay(prism, matprism, rx,ry,rz, dx,dy,dz, dist_start, dist_end, outintersection3=undefined, outnormal3=undefined) {
	var d, dist, dp, nx,ny,nz, px,py,pz;
	var v;
	
	// Convert ray into prism-space. (Instead of transforming each triangle vertex, normal, and center)
	var minv = matrix_inverse(matprism);
	v = matrix_transform_vertex(minv, rx,ry,rz, 1.0);
	rx = v[0]; ry = v[1]; rz = v[2];	// Ray position in prism-space
	
	v = matrix_transform_vertex(minv, dx,dy,dz, 0.0);
	d = point_distance_3d(0,0,0, v[0], v[1], v[2]);
	dx = v[0]/d; dy = v[1]/d; dz = v[2]/d;	// Normalized Ray direction in prism-space
	
	var hit_index = -1;
	var tris = prism.triangles;
	var t = 0;
	
	var n = array_length(tris) / VBM_PRISMTRIANGLE._len;
	repeat(n) {
		nx = tris[t+VBM_PRISMTRIANGLE.nx];
		ny = tris[t+VBM_PRISMTRIANGLE.ny];
		nz = tris[t+VBM_PRISMTRIANGLE.nz];
		
		dp = dot_product_3d(nx,ny,nz, dx,dy,dz);	// Inversion of amount normal matches ray_dir
		
		// Check if triangle is facing raydir
		if ( -dp <= 0.0 ) {t += VBM_PRISMTRIANGLE._len; continue;}
		
		// Intersection distance = dot(plane_point - ray_origin, normal) / dot(normal, ray_direction)
		dist = dot_product_3d(	
			tris[t+VBM_PRISMTRIANGLE.cx]-rx, tris[t+VBM_PRISMTRIANGLE.cy]-ry, tris[t+VBM_PRISMTRIANGLE.cz]-rz,
			nx,ny,nz
		) / dp;
		
		// Check distance against bounds
		if ( dist < dist_start || dist > dist_end ) {t += VBM_PRISMTRIANGLE._len; continue;}
		
		px = rx + dx * dist;	// Intersection point
		py = ry + dy * dist;
		pz = rz + dz * dist;
		
		// Check if intersection.xy is in triangle.xy
		if ( !point_in_triangle(	// Check collision in 2D space
			px,
			py,
			tris[t+VBM_PRISMTRIANGLE.v0x],
			tris[t+VBM_PRISMTRIANGLE.v0y],
			tris[t+VBM_PRISMTRIANGLE.v1x],
			tris[t+VBM_PRISMTRIANGLE.v1y],
			tris[t+VBM_PRISMTRIANGLE.v2x],
			tris[t+VBM_PRISMTRIANGLE.v2y]
		) ) {
			t += VBM_PRISMTRIANGLE._len;
			continue;
		}
		
		// Success
		hit_index = t div VBM_PRISMTRIANGLE._len;
		dist_end = dist;
		
		if ( !is_undefined(outintersection3) ) {
			v = matrix_transform_vertex(matprism, px, py, pz);
			outintersection3[@ 0] = px;
			outintersection3[@ 1] = py;
			outintersection3[@ 2] = pz;
		}
		if ( !is_undefined(outnormal3) ) {
			outnormal3[@ 0] = nx;
			outnormal3[@ 1] = ny;
			outnormal3[@ 2] = nz;
		}
		
		t += VBM_PRISMTRIANGLE._len;
	}
	
	return hit_index;
}

#endregion

// ==========================================================
#region // MODEL
// ==========================================================

function VBM_Model() constructor {
	name = "";	// Name of collection model was exported from
	format_key = 0;		// VBM format key that represents vertex format
	vertex_format = -1;	// Vertex format that matches vertex buffer
	vertex_buffer = -1;	// Individual meshes accessed through loop start
	texture_sprites = [];	// Array of sprites used as texture references
	meshdefs = [];	// Array of VBM_ModelMeshdef
	bones = [];		// Array of VBM_ModelBone
	materials = [];	// Array of VBM_ModelMaterial
	prisms = [];	// Array of VBM_ModelPrism
	animations = [];	// Array of VBM_ModelAnimation
};

/// @desc Returns allocated model struct
/// @return {Struct.VBM_Model}
function VBM_Model_Create() {return new VBM_Model(); }

/// @desc Removes allocated data from struct
/// @param {Struct.VBM_Model} model
function VBM_Model_Free(model) {
	var n;
	
	// VBM data ................................
	n = array_length(model.meshdefs);
	for (var i = 0; i < n; i++) {
		VBM_ModelMeshdef_Free(model.meshdefs[i]);
	}
	
	n = array_length(model.bones);
	for (var i = 0; i < n; i++) {
		VBM_ModelBone_Free(model.bones[i]);
	}
	
	n = array_length(model.materials);
	for (var i = 0; i < n; i++) {
		VBM_ModelMaterial_Free(model.materials[i]);
	}
	
	n = array_length(model.animations);
	for (var i = 0; i < n; i++) {
		VBM_ModelAnimation_Free(model.animations[i]);
	}
	
	n = array_length(model.prisms);
	for (var i = 0; i < n; i++) {
		VBM_ModelPrism_Free(model.prisms[i]);
	}
	
	// Non-VBM data ............................
	n = array_length(model.texture_sprites);
	for (var i = 0; i < n; i++) {
		sprite_delete(model.texture_sprites[i]);
	}
	
	vertex_delete_buffer(model.vertex_buffer);
	vertex_format_delete(model.vertex_format);
};

/// @param {Struct.VBM_Model} model
/// @return {Real}
function VBM_Model_GetVertexCount(model) {
	return vertex_get_number(model.vertex_buffer);
}

/// @desc Returns number of bytes each vertex uses.
/// @param {Struct.VBM_Model} model
/// @return {Real}
function VBM_Model_GetVertexStride(model) {
	return VBM_FormatStride(model.format_mask);
}

/// @param {Struct.VBM_Model} model
/// @return {Real}
function VBM_Model_GetMeshdefCount(model) {
	return array_length(model.meshdefs);
}

/// @param {Struct.VBM_Model} model
/// @return {Real}
function VBM_Model_GetPrismCount(model) {
	return array_length(model.prisms);
}

/// @param {Struct.VBM_Model} model
/// @return {Real}
function VBM_Model_GetBoneCount(model) {
	return array_length(model.bones);
}

/// @param {Struct.VBM_Model} model
/// @return {Real}
function VBM_Model_GetMaterialCount(model) {
	return array_length(model.material);
}

/// @param {Struct.VBM_Model} model
/// @return {Real}
function VBM_Model_GetTextureCount(model) {
	return array_length(model.texture_sprites);
}

/// @param {Struct.VBM_Model} model
/// @return {Real}
function VBM_Model_GetAnimationCount(model) {
	return array_length(model.animations);
}

/// @param {Struct.VBM_Model} model
/// @return {Id.VertexBuffer}
function VBM_Model_GetVertexBuffer(model) {
	return model.vertex_buffer;
}

/// @desc Returns sprite that represents the texture in model
/// @param {Struct.VBM_Model} model
/// @param {Real} index
/// @return {Id.Sprite}
function VBM_Model_GetTextureSprite(model, index) {
	return (index >= 0 && index < array_length(model.texture_sprites))? model.texture_sprites[index]: -1;
}

/// @desc Returns sprite that represents the texture in model
/// @param {Struct.VBM_Model} model
/// @param {Pointer.Texture, Real} texture_index
function VBM_Model_GetTexture(model, texture_index) {
	return (texture_index >= 0 && texture_index < array_length(model.texture_sprites))? 
		sprite_get_texture(model.texture_sprites[texture_index], 0): 
		-1;
}

/// @desc Adds texture sprite to model
/// @param {Struct.VBM_Model} model
/// @param {Id.Sprite} sprite
function VBM_Model_AddTextureSprite(model, sprite) {
	array_push(model.texture_sprites, sprite);
}

/// @param {Struct.VBM_Model} model
/// @param {Real} index
/// @return {Struct.VBM_ModelMeshdef}
function VBM_Model_GetMeshdef(model, index) {
	return (index >= 0 && index < array_length(model.meshdefs))? model.meshdefs[index]: undefined;
}

/// @param {Struct.VBM_Model} model
/// @param {Real} index
/// @return {String}
function VBM_Model_GetMeshdefName(model, index) {
	return (index >= 0 && index < array_length(model.meshdefs))? model.meshdefs[index].name: "";
}

/// @param {Struct.VBM_Model} model
/// @param {Real} index
/// @return {Struct.VBM_ModelBone}
function VBM_Model_GetBone(model, index) {
	return (index >= 0 && index < array_length(model.bones))? model.bones[index]: undefined;
}

/// @param {Struct.VBM_Model} model
/// @param {String} bone_name
/// @return {Struct.VBM_ModelBone, Undefined}
function VBM_Model_FindBone(model, bone_name) {
	var i = 0;
	repeat( array_length(model.bones) ) {
		if ( model.bones[i].name == bone_name ) {
			return model.bones[i];
		}
		i++;
	}
	return undefined;
}

/// @desc Returns index of bone in model. -1 if not found
/// @param {Struct.VBM_Model} model
/// @param {String} bone_name
/// @return {Real}
function VBM_Model_FindBoneIndex(model, bone_name) {
	var i = 0;
	repeat( array_length(model.bones) ) {
		if ( model.bones[i].name == bone_name ) {
			return i;
		}
		i++;
	}
	return -1;
}

/// @param {Struct.VBM_Model} model
/// @param {Real} index
/// @return {String}
function VBM_Model_GetBoneName(model, index) {
	return (index >= 0 && index < array_length(model.bones))? model.bones[index].name: "";
}

/// @param {Struct.VBM_Model} model
/// @param {Real} index
/// @return {Real}
function VBM_Model_GetBoneDepth(model, index) {
	var bone = model.bones[index];
	var _depth = 0;
	while ( bone.parent_index != VBM_NULLINDEX ) {
		bone = model.bones[bone.parent_index];
	}
	return _depth;
}

/// @param {Struct.VBM_Model} model
/// @param {Real} index
/// @return {Struct.Material, Undefined}
function VBM_Model_GetMaterial(model, index) {
	return (index >= 0 && index < array_length(model.materials))? 
		model.materials[index]: undefined;
}

/// @param {Struct.VBM_Model} model
/// @param {Real} animation_index
/// @return {Struct.VBM_ModelAnimation, Undefined}
function VBM_Model_GetAnimation(model, animation_index) {
	return (animation_index >= 0 && animation_index < array_length(model.animations))? 
		model.animations[animation_index]: undefined;
}

/// @param {Struct.VBM_Model} model
/// @param {Real} animation_name
/// @return {Struct.VBM_ModelAnimation, Undefined}
function VBM_Model_FindAnimation(model, animation_name) {
	var i = 0;
	repeat(array_length(model.animations)) {
		if ( model.animations[i].name == animation_name ) {
			return model.animations[i];
		}
		i++;
	}
	return undefined;
}

/// @param {Struct.VBM_Model} model
/// @param {Real} animation_index
/// @return {String}
function VBM_Model_GetAnimationName(model, animation_index) {
	return (animation_index >= 0 && animation_index < array_length(model.animations))? 
		model.animations[animation_index].name: "";
}

/// @param {Struct.VBM_Model} model
/// @param {Real} animation_index
/// @return {Real}
function VBM_Model_GetAnimationDuration(model, animation_index) {
	return (animation_index >= 0 && animation_index < array_length(model.animations))? 
		model.animations[animation_index].duration: 0;
}

/// @desc Sets layer mask of bone
/// @param {Struct.VBM_Model} model
/// @param {Real} bone_index
/// @param {Real} layer_mask
/// @return {Real}
function VBM_Model_BoneLayerSetIndex(model, bone_index, layer_mask) {
	model.bones[bone_index].layer_mask = layer_mask;
}

/// @desc Adds bone to layermask
/// @param {Struct.VBM_Model} model
/// @param {Real} bone_index
/// @param {Real} layer_mask
function VBM_Model_BoneLayerAddIndex(model, bone_index, layer_mask) {
	model.bones[bone_index].layer_mask |= layer_mask;
}

/// @desc Adds bones with names matching pattern to layermask
/// @param {Struct.VBM_Model} model
/// @param {Real} layer_mask
function VBM_Model_BoneLayerAddPattern(model, layer_mask) {
	var bones = array_create(model.bone_count);
	var n = array_length(bones);
	for (var i = 0; i < n; i++) {
		bones[i].layer_mask |= layer_mask;
	}
}

/// @desc Sets <outvec3> to location of bone in untransformed model-space
/// @param {Struct.VBM_Model} model
/// @param {Real} bone_index
/// @param {Array<Real>} outvec3
function VBM_Model_BoneGetLocationBind(model, bone_index, outvec3) {
	var bone = model.bones[bone_index];
	outvec3[@ 0] = bone.matrix_bind[VBM_M03];
	outvec3[@ 1] = bone.matrix_bind[VBM_M13];
	outvec3[@ 2] = bone.matrix_bind[VBM_M23];
}

/// @desc Fills array of bones matching given patterns. Returns number of bones
/// @param {Struct.VBM_Model} model
/// @param {Real} layer_mask
/// @param {Array} out_bones
/// @param {Real} out_capacity
/// @param {String} name_starts_with
/// @param {String} name_ends_with
/// @param {String} name_contains
/// @return {Real}
function VBM_Model_GetBonesByPattern(model, layer_mask, out_bones, out_capacity, name_starts_with="", name_ends_with="", name_contains="") {
	var bone;
	var hits = 0;
	var namelen;
	var name;
	var n = array_length(model.bones);
	for (var i = 0; i < n; i++) {
		bone = model.bones[i];
		name = bone.name;
		namelen = string_length(name);
		if ( 
			( name_contains != "" && string_pos(name_contains, name) != -1 ) ||
			( name_starts_with != "" && string_copy(name, 1, string_length(name_starts_with)) == name_starts_with ) ||
			( name_ends_with != "" && string_copy(name, namelen-string_length(name_ends_with)+1, string_length(name_ends_with)) == name_ends_with )
		) {
			out_bones[@ hits] = bone;
			hits++;
			if ( hits == out_capacity ) {break;}
		}
	}
	return hits;
}

/// @desc Fills array of bones in layer. Returns number of bones
/// @param {Struct.VBM_Model} model
/// @param {Real} layer_mask
/// @param {Array<Struct.VBM_ModelBone>} out_bones
/// @param {Real} out_capacity
/// @return {Real}
function VBM_Model_GetBonesByLayer(model, layer_mask, out_bones, out_capacity) {
	var bone;
	var hits = 0;
	var n = array_length(model.bones);
	for (var i = 0; i < n; i++) {
		bone = model.bones[i];
		if ( bone.layer_mask & layer_mask ) {
			out_bones[@ hits] = bone;
			hits++;
			if ( hits == out_capacity ) {break;}
		}
	}
	return hits;
}

/// @desc Renders all meshes in model
/// @param {Struct.VBM_Model} model
/// @param {Array<Real>} matrix
/// @param {Real} [visibility_mask]
/// @param {Bool} [change_drawstate]
function VBM_Model_Submit(model, matrix, visibility_mask=~0, change_drawstate=true, change_shader=false) {
	var drawflags = ~0;
	var n = array_length(model.meshdefs);
	var meshdef, mtl, tex, shd;
	var m;
	
	tex = VBM_Model_GetTexture(model, 0);
	
	for (var mesh_index = 0; mesh_index < n; mesh_index++) {
		if ( (visibility_mask & (1<<mesh_index)) == 0 ) {continue;}
		
		meshdef = model.meshdefs[mesh_index];
		
		if ( change_drawstate ) {
			mtl = VBM_Model_GetMaterial(model, meshdef.material_index);
		
			if ( !is_undefined(mtl) ) {
				// Compare drawstate to reduce gpu calls
				if ( mtl.flags != drawflags ) {
					drawflags = mtl.flags;
				
					// Set gpu state
					gpu_set_zwriteenable( (mtl.flags & VBM_MATERIALFLAG.USEDEPTH)? 1: 0);
					gpu_set_ztestenable( (mtl.flags & VBM_MATERIALFLAG.USEDEPTH)? 1: 0);
					gpu_set_cullmode( (mtl.flags & VBM_MATERIALFLAG.CULLFRONT)? cull_counterclockwise: cull_clockwise );
					gpu_set_blendenable( (mtl.flags & VBM_MATERIALFLAG.TRANSPARENT)? 1: 0 );
				
					// Set shader
					if ( change_shader ) {
						shd = asset_get_index(mtl.shader_name);
					
						if ( shd != -1 && shd != shader_current() ) {
							shader_set(shd);
						}
				
						// Set textures. 0 is passed in w/ vertex_submit()
						if ( shd != -1 ) {
							texture_set_stage(shader_get_sampler_index(shd, VBM_UNIFORMNAME_TEXTURE0), VBM_Model_GetTexture(model, 0));
							texture_set_stage(shader_get_sampler_index(shd, VBM_UNIFORMNAME_TEXTURE1), VBM_Model_GetTexture(model, 1));
							texture_set_stage(shader_get_sampler_index(shd, VBM_UNIFORMNAME_TEXTURE2), VBM_Model_GetTexture(model, 2));
							texture_set_stage(shader_get_sampler_index(shd, VBM_UNIFORMNAME_TEXTURE3), VBM_Model_GetTexture(model, 3));
						}
					}
				}
				
				tex = VBM_Model_GetTexture(model, mtl.texture_indices[0]);
				if ( mtl.texture_flags[0] & VBM_MATERIALTEXTUREFLAG.FILTERLINEAR ) {gpu_set_tex_filter(1);}
				else {gpu_set_tex_filter(0);}
			}
			else {
				tex = -1;
			}
			
			// Calculate matrix from bone
			if ( meshdef.bone_index != VBM_NULLINDEX ) {
				m = VBM_MAT4_MUTLIPLY(model.bones[meshdef.bone_index].matrix_bind, matrix);
			}
			else {
				m = matrix;
			}
			matrix_set(matrix_world, m);
		}
		
		// Submit region of vertex buffer
		vertex_submit_ext(
			model.vertex_buffer, 
			pr_trianglelist, 
			tex,
			meshdef.loop_start, 
			meshdef.loop_count
		);
	}
}

/// @desc Renders given mesh in model. Does NOT change draw state
/// @param {Struct.VBM_Model} model
function VBM_Model_SubmitMesh(model, mesh_index, texture=VBM_SUBMIT_TEXDEFAULT) {
	var meshdef = model.meshdefs[mesh_index];
	
	if ( texture == VBM_SUBMIT_TEXNONE ) {
		texture = -1;
	}
	else if ( texture == VBM_SUBMIT_TEXDEFAULT ) {
		var mtl = VBM_Model_GetMaterial(model, meshdef.material_index);
		texture = VBM_Model_GetTexture(model, mtl? mtl.texture_indices[0]: -1);
	}
		
	// Submit region of vertex buffer
	vertex_submit_ext(
		model.vertex_buffer,
		pr_trianglelist,
		texture,
		meshdef.loop_start,
		meshdef.loop_count
	);
}

#endregion

// ===========================================================
#region // MODEL ANIMATION
// ===========================================================

/// @desc Evaluates transforms from animation
/// @param {Struct.VBM_Model} model
/// @param {Struct.VBM_ModelAnimation} animation
/// @param {Real} animation_frame
/// @param {Array<Real>} outtransforms_1d
function VBM_Model_EvaluateAnimationTransforms(model, animation, animation_frame, outtransforms_1d) {
	//if ( !model || !animation ) {return;}
	var curve_count = animation.props_offset;
	var t = 0;
	var animcurve = animation.animcurve;
	var posx = animation_frame / animation.duration;
	posx = frac(posx);
	
	repeat(curve_count) {
		outtransforms_1d[t+0] = animcurve_channel_evaluate(animcurve.channels[t+0], posx);
		outtransforms_1d[t+1] = animcurve_channel_evaluate(animcurve.channels[t+1], posx);
		outtransforms_1d[t+2] = animcurve_channel_evaluate(animcurve.channels[t+2], posx);
		outtransforms_1d[t+3] = animcurve_channel_evaluate(animcurve.channels[t+3], posx);
		outtransforms_1d[t+4] = animcurve_channel_evaluate(animcurve.channels[t+4], posx);
		outtransforms_1d[t+5] = animcurve_channel_evaluate(animcurve.channels[t+5], posx);
		outtransforms_1d[t+6] = animcurve_channel_evaluate(animcurve.channels[t+6], posx);
		outtransforms_1d[t+7] = animcurve_channel_evaluate(animcurve.channels[t+7], posx);
		outtransforms_1d[t+8] = animcurve_channel_evaluate(animcurve.channels[t+8], posx);
		outtransforms_1d[t+9] = animcurve_channel_evaluate(animcurve.channels[t+9], posx);
		t += VBM_TRANSFORM._len;
	}
}

/// @desc Evaluates transforms from animation
/// @param {Struct.VBM_Model} model
/// @param {Struct.VBM_ModelAnimation} animation
/// @param {Real} animation_frame
/// @param {Real} blend_amt
/// @param {Array<Real>} lasttransforms_1d
/// @param {Array<Real>} outtransforms_1d
function VBM_Model_EvaluateAnimationTransforms_Blend(model, animation, animation_frame, blend_amt, lasttransforms_1d, outtransforms_1d) {
	//if ( !model || !animation ) {return;}
	
	var bone_count = animation.props_offset;	// Bones come first
	var animcurve = animation.animcurve;
	var t = 0;
	var posx = VBM_ModelAnimation_EvaluateFramePosition(animation, animation_frame);
	
	if (blend_amt < 1.0) {
		repeat(bone_count) {
			outtransforms_1d[t+0] = lerp(lasttransforms_1d[t+0], animcurve_channel_evaluate(animcurve.channels[t+0], posx), blend_amt);
			outtransforms_1d[t+1] = lerp(lasttransforms_1d[t+1], animcurve_channel_evaluate(animcurve.channels[t+1], posx), blend_amt);
			outtransforms_1d[t+2] = lerp(lasttransforms_1d[t+2], animcurve_channel_evaluate(animcurve.channels[t+2], posx), blend_amt);
			outtransforms_1d[t+3] = lerp(lasttransforms_1d[t+3], animcurve_channel_evaluate(animcurve.channels[t+3], posx), blend_amt);
			outtransforms_1d[t+4] = lerp(lasttransforms_1d[t+4], animcurve_channel_evaluate(animcurve.channels[t+4], posx), blend_amt);
			outtransforms_1d[t+5] = lerp(lasttransforms_1d[t+5], animcurve_channel_evaluate(animcurve.channels[t+5], posx), blend_amt);
			outtransforms_1d[t+6] = lerp(lasttransforms_1d[t+6], animcurve_channel_evaluate(animcurve.channels[t+6], posx), blend_amt);
			outtransforms_1d[t+7] = lerp(lasttransforms_1d[t+7], animcurve_channel_evaluate(animcurve.channels[t+7], posx), blend_amt);
			outtransforms_1d[t+8] = lerp(lasttransforms_1d[t+8], animcurve_channel_evaluate(animcurve.channels[t+8], posx), blend_amt);
			outtransforms_1d[t+9] = lerp(lasttransforms_1d[t+9], animcurve_channel_evaluate(animcurve.channels[t+9], posx), blend_amt);
			t += VBM_TRANSFORM._len;
		}
	}
	else {
		repeat(bone_count) {
			outtransforms_1d[t+0] = animcurve_channel_evaluate(animcurve.channels[t+0], posx);
			outtransforms_1d[t+1] = animcurve_channel_evaluate(animcurve.channels[t+1], posx);
			outtransforms_1d[t+2] = animcurve_channel_evaluate(animcurve.channels[t+2], posx);
			outtransforms_1d[t+3] = animcurve_channel_evaluate(animcurve.channels[t+3], posx);
			outtransforms_1d[t+4] = animcurve_channel_evaluate(animcurve.channels[t+4], posx);
			outtransforms_1d[t+5] = animcurve_channel_evaluate(animcurve.channels[t+5], posx);
			outtransforms_1d[t+6] = animcurve_channel_evaluate(animcurve.channels[t+6], posx);
			outtransforms_1d[t+7] = animcurve_channel_evaluate(animcurve.channels[t+7], posx);
			outtransforms_1d[t+8] = animcurve_channel_evaluate(animcurve.channels[t+8], posx);
			outtransforms_1d[t+9] = animcurve_channel_evaluate(animcurve.channels[t+9], posx);
			t += VBM_TRANSFORM._len;
		}
	}
}

/// @desc Evaluates model-space matrices from transforms
/// @param {Struct.VBM_Model} model
/// @param {Array<Real>} transforms_1d
/// @param {Array<Array<Real>>} outmat4modelspace_1d
/// @param {Array<Array<Real>>} [outmat4bonespace_2d]
function VBM_Model_EvaluateTransformMatrices(model, transforms_1d, outmat4modelspace_1d, outmat4bonespace_2d=undefined) {
	//if ( !model ) {return;}
	
	var bone_count = array_length(model.bones);
	var m = matrix_build_identity(), mparent = matrix_build_identity();
	var t = 0;
	var bone;
	var bone_index, parent_index = -1;
	var qw, qx, qy, qz, xx, xy, xz, xw, yy, yz, yw, zz, zw, sx, sy, sz;
	
	// Transform -> Relative -> Origin
	bone_index = 0;
	repeat(bone_count) {
		bone = model.bones[bone_index];
		
		// Parent-space matrix = mat4_compose(location, quat, scale)
		qw = transforms_1d[t+VBM_TRANSFORM.qw];
		qx = transforms_1d[t+VBM_TRANSFORM.qx];
		qy = transforms_1d[t+VBM_TRANSFORM.qy];
		qz = transforms_1d[t+VBM_TRANSFORM.qz];
		sx = transforms_1d[t+VBM_TRANSFORM.sx];
		sy = transforms_1d[t+VBM_TRANSFORM.sy];
		sz = transforms_1d[t+VBM_TRANSFORM.sz];
		xx = sqr(qx); xy = qx*qy; xz = qx*qz; xw = qx*qw;
		yy = sqr(qy); yz = qy*qz; yw = qy*qw; zz = sqr(qz); zw = qz*qw;

		m[VBM_M00] = (1.0 - 2.0 * (yy + zz)) * sx;
		m[VBM_M01] = (2.0 * (xy - zw)) * sx;
		m[VBM_M02] = (2.0 * (xz + yw)) * sx;
		m[VBM_M03] = transforms_1d[t+VBM_TRANSFORM.x];	// x
		m[VBM_M10] = (2.0 * (xy + zw)) * sy;
		m[VBM_M11] = (1.0 - 2.0 * (xx + zz)) * sy;
		m[VBM_M12] = (2.0 * (yz - xw)) * sy;
		m[VBM_M13] = transforms_1d[t+VBM_TRANSFORM.y];	// y
		m[VBM_M20] = (2.0 * (xz - yw)) * sz;
		m[VBM_M21] = (2.0 * (yz + xw)) * sz;
		m[VBM_M22] = (1.0 - 2.0 * (xx + yy)) * sz;
		m[VBM_M23] = transforms_1d[t+VBM_TRANSFORM.z];	// z
		//m[VBM_M30] = 0.0;
		//m[VBM_M31] = 0.0;
		//m[VBM_M32] = 0.0;
		m[VBM_M33] = 1.0;
		
		m = VBM_MAT4_MUTLIPLY(m, bone.matrix_relative);
		if ( outmat4bonespace_2d ) {
			array_copy(outmat4bonespace_2d[bone_index], 0, m, 0, 15);
		}
		
		// Reduce number of matrix reads by checking change in parents from last bone
		if ( parent_index != bone.parent_index ) {
			parent_index = bone.parent_index;
			if ( parent_index != VBM_NULLINDEX ) {
				array_copy(mparent, 0, outmat4modelspace_1d, 16*parent_index, 15);
			}
		}
		
		// Model-space matrix = Relative * Parent
		m = VBM_MAT4_MUTLIPLY(m, mparent);
		array_copy(outmat4modelspace_1d, 16*bone_index, m, 0, 15);
		
		bone_index++;
		t += VBM_TRANSFORM._len;
	}
}

/// @desc Processes matrices for swing bones
/// @param {Struct.VBM_Model} model
/// @param {Array<Real>} mat4_world
/// @param {Array<Real>} particles_1d
/// @param {Array<Real>} outmat4modelspace_1d
/// @param {Real} [time_factor]
function VBM_Model_EvaluateSwingMatrices(model, mat4_world, particles_1d, outmat4modelspace_1d, time_factor=1.0) {
	//if ( !model ) {return;}
	
	var bone_count = array_length(model.bones);
	var bone_index, parent_index = -1;
	var bone;
	
	var minv = matrix_inverse(mat4_world);
	var mroot = matrix_build_identity();
	var mparent = matrix_build_identity();
	var v = [0,0,0];
	
	// The obscene number of variables is better for performance than working with arrays:
	var px,py,pz, rx,ry,rz, gx,gy,gz, vx,vy,vz, ux,uy,uz, fx,fy,fz, dx,dy,dz, cx,cy,cz;
	var damping, stiffness, limit, force_strength;
	var d, plength, bone_length, dot1;
	var cosom, sinom, omega, w0, w1;	// slerp() variables
	
	var i, b, p;
	
	// Origin -> Vertex
	bone_index = 0;
	b = 0;
	p = 0;
	repeat(bone_count) {
		bone = model.bones[bone_index];
		
		// Swing not enabled, skip bone
		if ( !VBM_ModelBone_SwingEnabled(bone) ) {
			//particles_1d[p+VBM_BONEPARTICLE.xcurr+0] = outmat4modelspace_1d[b + VBM_M03];
			//particles_1d[p+VBM_BONEPARTICLE.xcurr+1] = outmat4modelspace_1d[b + VBM_M13];
			//particles_1d[p+VBM_BONEPARTICLE.xcurr+2] = outmat4modelspace_1d[b + VBM_M23];
			//array_copy(particles_1d, p+VBM_BONEPARTICLE.xlast, particles_1d, p+VBM_BONEPARTICLE.xcurr, 3);
			p += VBM_BONEPARTICLE._len;
			b += 16;
			bone_index++;
			continue;
		}
		
		// Staging ...............................................
		bone_length = bone.length;
		if ( bone_length <= 0.0 ) {bone_length = model.bones[bone.parent_index].length/2;}	// Use parent bone
		
		// Reduce number of matrix reads by checking change in parents from last bone
		if ( parent_index != bone.parent_index ) {
			parent_index = bone.parent_index;
			if ( parent_index != VBM_NULLINDEX ) {
				array_copy(mparent, 0, outmat4modelspace_1d, 16*parent_index, 15);
			}
		}
		
		// Get model-space bone up vector. Used later in track_to() section
		mroot = VBM_MAT4_MUTLIPLY(bone.matrix_relative, mparent);
		v = matrix_transform_vertex(mroot, 0,0,1);
		ux = v[0]; uy = v[1]; uz = v[2];
		
		// Model-space to World-space. Particles are evaluated in world space
		mroot = VBM_MAT4_MUTLIPLY(mroot, mat4_world);
		v = matrix_transform_vertex(mroot, 0,0,0);
		rx = v[0]; ry = v[1]; rz = v[2];
		
		v = matrix_transform_vertex(mroot, 0,bone_length,0);
		gx = v[0]; gy = v[1]; gz = v[2];
		
		// Pull in particle variables
		px = particles_1d[p+VBM_BONEPARTICLE.xcurr+0]; 
		py = particles_1d[p+VBM_BONEPARTICLE.xcurr+1]; 
		pz = particles_1d[p+VBM_BONEPARTICLE.xcurr+2];
		vx = particles_1d[p+VBM_BONEPARTICLE.xlast+0];	// "v" var temporarily holds plast 
		vy = particles_1d[p+VBM_BONEPARTICLE.xlast+1];
		vz = particles_1d[p+VBM_BONEPARTICLE.xlast+2];
		
		// Reset particle to goal if zero
		if ( px == 0 && py == 0 && pz == 0 ) {
			px = gx; py = gy; pz = gz;
			vx = gx; vy = gy; vz = gz;
		}
		
		// Verlet Integration ...........................................
		damping = (1.0 - bone.swing.damping * time_factor);
		stiffness = bone.swing.stiffness * time_factor;
		limit = bone.swing.limit;
		force_strength = bone.swing.force_strength * time_factor;
		
		// Velocity = current - last
		vx = (px-vx) * (damping) + (gx-px) * stiffness;
		vy = (py-vy) * (damping) + (gy-py) * stiffness;
		vz = (pz-vz) * (damping) + (gz-pz) * stiffness;
		
		// Current = current + velocity + acceleration * dt*dt
		particles_1d[p+VBM_BONEPARTICLE.xlast+0] = px;	// Update last particle
		particles_1d[p+VBM_BONEPARTICLE.xlast+1] = py;
		particles_1d[p+VBM_BONEPARTICLE.xlast+2] = pz;
		
		px += vx;
		py += vy;
		pz += vz;
		
		// Constraints .................................................
		plength = point_distance_3d(0,0,0, px-rx, py-ry, pz-rz);
		
		// Clamp distance
		if ( 1 ) {
			vx = (px - rx) / plength;	// Current axis
			vy = (py - ry) / plength;
			vz = (pz - rz) / plength;
			
			px = lerp(px, rx + vx * bone_length, 0.99);
			py = lerp(py, ry + vy * bone_length, 0.99);
			pz = lerp(pz, rz + vz * bone_length, 0.99);
			plength = bone_length;
		}
		
		// Rotation Constraint
		if ( limit > 0.01 ) {
			dx = (px-rx) / plength;
			dy = (py-ry) / plength;
			dz = (pz-rz) / plength;
			
			d = point_distance_3d(0,0,0, gx-rx, gy-ry, gz-rz);
			fx = (gx-rx) / d;
			fy = (gy-ry) / d;
			fz = (gz-rz) / d;
			
			d = dot_product_3d_normalized(fx,fy,fz, dx,dy,dz);
			d = sqrt((1.001-(d*0.5+0.5))*limit);
			dx = lerp(dx, fx, d);
			dy = lerp(dy, fy, d);
			dz = lerp(dz, fz, d);
			d = point_distance_3d(0,0,0, dx,dy,dz);
			
			px = rx + (dx/d) * plength;
			py = ry + (dy/d) * plength;
			pz = rz + (dz/d) * plength;
			
		}
		else if ( limit > 0.01 ) 
		{
			dx = (px-rx) / plength;
			dy = (py-ry) / plength;
			dz = (pz-rz) / plength;
			
			d = point_distance_3d(0,0,0, gx-rx, gy-ry, gz-rz);
			fx = (gx-rx) / d;
			fy = (gy-ry) / d;
			fz = (gz-rz) / d;
			
			// This dot product is WRONG. It is always some value shorter than the target dot.
			dot1 = dot_product_3d(dx,dy,dz, fx,fy,fz);
			
			// Early guess if slerp code needs to be run
			if ( (dot1*0.5+0.5) < limit*1.2 )  {
				vx = (dy*fz - dz*fy);	// Up Axis = Forward x Current
				vy = (dz*fx - dx*fz);
				vz = (dx*fy - dy*fx);
				d = point_distance_3d(0,0,0, vx,vy,vz);
				vx /= d; vy /= d; vz /= d;
	
				cx = (fy*vz - fz*vy);	// Right Axis = Up x Forward
				cy = (fz*vx - fx*vz);
				cz = (fx*vy - fy*vx);
				d = point_distance_3d(0,0,0, cx,cy,cz);
				
				// Check if vectors are the same, somehow
				if ( d > 0.0 ) {
					cx /= d; cy /= d; cz /= d;
				
					// Slerp(right, goal, limit)
					// Source: https://github.com/blender/blender/blob/cb22938fe942b994541b3e80715ef8042d5320c7/source/blender/blenlib/intern/math_vector.cc#L58
					d = limit*2.0-1.0;
					cosom = dot_product_3d(fx,fy,fz, cx,cy,cz);
					{
						//show_debug_message([string_format(cosom, 8, 8), [vx,vy,vz], [fx,fy,fz], [cx,cy,cz]]);
						omega = arccos(cosom);
						sinom = sin(omega);
						w0 = sin( (1.0-d)*omega ) / sinom;
						w1 = sin( d*omega ) / sinom;
					}
	
					vx = cx*w0 + fx*w1;
					vy = cy*w0 + fy*w1;
					vz = cz*w0 + fz*w1;
				
					// Test ACCURATE dot product against first dot product
					if ( dot_product_3d_normalized(fx,fy,fz, vx,vy,vz) < dot1 ) {
						d = point_distance_3d(0,0,0, vx,vy,vz);
						px = lerp(px, rx + (vx/d) * plength, 1.0);
						py = lerp(py, ry + (vy/d) * plength, 1.0);
						pz = lerp(pz, rz + (vz/d) * plength, 1.0);
					
						particles_1d[@ p+VBM_BONEPARTICLE.xlast] = px;
						particles_1d[@ p+VBM_BONEPARTICLE.ylast] = py;
						particles_1d[@ p+VBM_BONEPARTICLE.zlast] = pz;
					}
				}
			}

		}
		
		// Apply .......................................................
		particles_1d[@ p+0] = px;
		particles_1d[@ p+1] = py;
		particles_1d[@ p+2] = pz;
		
		// Convert back to Model-space
		v = matrix_transform_vertex(minv, px,py,pz);
		vx = v[0]; vy = v[1]; vz = v[2];
		
		v = matrix_transform_vertex(minv, rx, ry, rz);
		rx = v[0]; ry = v[1]; rz = v[2];
		
		// Track to bone.
		// Source: https://github.com/blender/blender/blob/main/source/blender/blenkernel/intern/constraint.cc#L1219
		d = point_distance_3d(rx, ry, rz, vx, vy, vz);
		vx = (vx - rx) / d;
		vy = (vy - ry) / d;
		vz = (vz - rz) / d;
		
		d = (
			dot_product_3d(ux, uy, uz, vx, vy, vz) / 
			dot_product_3d(vx, vy, vz, vx, vy, vz)
		);
		ux = ux - (vx * d);
		uy = uy - (vy * d);
		uz = uz - (vz * d);
	
		if ( point_distance_3d(0,0,0, ux, uy, uz) <= 0.1 ) {ux = 0; uy = 1; uz = 0;}
		gx = uy*vz - uz*vy;
		gy = uz*vx - ux*vz;
		gz = ux*vy - uy*vx;
	
		d = point_distance_3d(0,0,0, gx, gy, gz);
		gx /= d; gy /= d; gz /= d;
		
		d = point_distance_3d(0,0,0, ux, uy, uz);
		ux /= d; uy /= d; uz /= d;
	
		outmat4modelspace_1d[@ b+VBM_M00] = -gx;
		outmat4modelspace_1d[@ b+VBM_M10] = -gy;
		outmat4modelspace_1d[@ b+VBM_M20] = -gz;
		outmat4modelspace_1d[@ b+VBM_M02] = ux;
		outmat4modelspace_1d[@ b+VBM_M12] = uy;
		outmat4modelspace_1d[@ b+VBM_M22] = uz;
		outmat4modelspace_1d[@ b+VBM_M01] = vx;
		outmat4modelspace_1d[@ b+VBM_M11] = vy;
		outmat4modelspace_1d[@ b+VBM_M21] = vz;
		outmat4modelspace_1d[@ b+VBM_M03] = rx;
		outmat4modelspace_1d[@ b+VBM_M13] = ry;
		outmat4modelspace_1d[@ b+VBM_M23] = rz;
		
		p += VBM_BONEPARTICLE._len;
		b += 16;
		bone_index++;
	}
}

/// @desc Evaluates vertex-space matrices from model-space matrices
/// @param {Struct.VBM_Model} model
/// @param {Array<Array<Real>>} mat4modelspace_1d
/// @param {Array<Array<Real>>} outmat4skinning_1d
function VBM_Model_EvaluateSkinningMatrices(model, mat4modelspace_1d, outmat4skinning_1d) {
	//if ( !model ) {return;}
	
	var bone_count = array_length(model.bones);
	var m = matrix_build_identity()
	var bone_index = bone_count-1;
	var b = 16*bone_index;
	
	// Origin -> Vertex
	repeat(bone_count) {
		// Vertex-space matrix = Model * Inverse
		array_copy(m, 0, mat4modelspace_1d, b, 15);
		m = VBM_MAT4_MUTLIPLY(model.bones[bone_index].matrix_inversebind, m);
		array_copy(outmat4skinning_1d, b, m, 0, 15);
		bone_index--;
		b -= 16;
	}
}

#endregion

// ===========================================================
#region // FORMAT
// ===========================================================

/// @desc Returns GM vertex format from VBM format key
/// @param {Real} format_mask
/// @return {Id.VertexFormat}
function VBM_FormatBuild(format_mask) {
	vertex_format_begin();
	for (var i = 0; i < 16; i++) {
		if ( format_mask & (1<<i) ) {
			// Byteflag
			if ( format_mask & (1<<(i+16)) ) {
				vertex_format_add_color();
			}
			// Float vector
			else {
				switch(1<<i) {
					case VBM_FORMATMASK.POSITION: vertex_format_add_position_3d(); break;
					case VBM_FORMATMASK.NORMAL: vertex_format_add_normal(); break;
					case VBM_FORMATMASK.TANGENT: vertex_format_add_custom(vertex_type_float3, vertex_usage_texcoord); break;
					case VBM_FORMATMASK.BITANGENT: vertex_format_add_custom(vertex_type_float3, vertex_usage_texcoord); break;
					case VBM_FORMATMASK.UV: vertex_format_add_texcoord(); break;
					case VBM_FORMATMASK.COLOR: vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); break;
					case VBM_FORMATMASK.BONE: vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); break;
					case VBM_FORMATMASK.WEIGHT: vertex_format_add_custom(vertex_type_float4, vertex_usage_texcoord); break;
					default: vertex_format_add_color(); break;
				}
			}
		}
	}
	return vertex_format_end();
}

/// @desc Returns number of bytes per vertex in format
/// @param {Real} format_mask
/// @return {Real}
function VBM_FormatStride(format_mask) {
	var stride = 0;
	var bytes_per_element = 0;
	var is_byte = 0;
	var attribute_type = 0;
	for (var i = 0; i < 16; i++) {
		attribute_type = 1<<i;
		if (format_mask & attribute_type) {
			is_byte = format_mask & (1<<(i+16));
			bytes_per_element = is_byte? 1: 4;
			
			switch(1<<i) {
				case VBM_FORMATMASK.POSITION: stride += 3*bytes_per_element; break;
				case VBM_FORMATMASK.UV: stride += 2*bytes_per_element; break;
				case VBM_FORMATMASK.UV2: stride += 2*bytes_per_element; break;
				case VBM_FORMATMASK.NORMAL: stride += 3*bytes_per_element; break;
				case VBM_FORMATMASK.TANGENT: stride += 3*bytes_per_element; break;
				case VBM_FORMATMASK.BITANGENT: stride += 3*bytes_per_element; break;
				case VBM_FORMATMASK.BONE: stride += 4*bytes_per_element; break;
				case VBM_FORMATMASK.WEIGHT: stride += 4*bytes_per_element; break;
				default: stride += 4*bytes_per_element; break;
			}
		}
	}
	return stride;
}

/// @desc Returns long name of VBM_FORMATMASK.... type
/// @param {Real} vbm_attribute_type
/// @return {String}
function VBM_FormatAttributeName(vbm_attribute_type) {
	switch(vbm_attribute_type) {
		case VBM_FORMATMASK.POSITION: return "POSITION";
		case VBM_FORMATMASK.NORMAL: return "NORMAL";
		case VBM_FORMATMASK.TANGENT: return "TANGENT";
		case VBM_FORMATMASK.BITANGENT: return "BITANGENT";
		case VBM_FORMATMASK.COLOR: return "COLOR";
		case VBM_FORMATMASK.UV: return "UV";
		case VBM_FORMATMASK.UV2: return "UV2";
		case VBM_FORMATMASK.BONE: return "BONE";
		case VBM_FORMATMASK.WEIGHT: return "WEIGHT";
	}
	return "???";
}

/// @desc Returns short name of VBM_FORMATMASK.... type
/// @param {Real} vbm_attribute_type
/// @return {String}
function VBM_FormatAttributeKey(vbm_attribute_type) {
	switch(vbm_attribute_type) {
		case VBM_FORMATMASK.POSITION: return "POS";
		case VBM_FORMATMASK.NORMAL: return "NOR";
		case VBM_FORMATMASK.TANGENT: return "TAN";
		case VBM_FORMATMASK.BITANGENT: return "BIT";
		case VBM_FORMATMASK.COLOR: return "COL";
		case VBM_FORMATMASK.UV: return "UVS";
		case VBM_FORMATMASK.UV2: return "UV2";
		case VBM_FORMATMASK.BONE: return "BON";
		case VBM_FORMATMASK.WEIGHT: return "WEI";
	}
	return "???";
}

#endregion

// ===========================================================
#region // UTILITY
// ===========================================================

function VBM_ParticleApplyForce(particles_1d, force_x, force_y, force_z, time_step=1.0) {
	var n = array_length(particles_1d) / VBM_BONEPARTICLE._len;
	var t = 0;
	force_x *= time_step;
	force_y *= time_step;
	force_z *= time_step;
	repeat(n) {
		particles_1d[t+VBM_BONEPARTICLE.xcurr+0] += force_x;
		particles_1d[t+VBM_BONEPARTICLE.xcurr+1] += force_y;
		particles_1d[t+VBM_BONEPARTICLE.xcurr+2] += force_z;
		t += VBM_BONEPARTICLE._len;
	}
}

/// @desc Opens and loads vbm data from file. Returns 1 if successful
/// @param {Struct.VBM_Model} outvbm
/// @param {String} filepath
/// @param {Real} [openflags]
/// @return {Real}
function VBM_Open(outvbm, filepath, openflags=0) {
	var f = buffer_load(filepath);
	if ( f == -1 ) {
		return 0;
	}
	var success = VBM_Load(outvbm, f, 0, openflags);
	buffer_delete(f);
	return success;
}

/// @desc Loads vbm data from buffer. Returns number of bytes read if successful
/// @param {Struct.VBM_Model} outvbm
/// @param {Id.Buffer} file_buffer
/// @param {Real} file_buffer_offset
/// @param {Real} [openflags]
/// @return {Real}
function VBM_Load(outvbm, file_buffer, file_buffer_offset, openflags=0) {
	var _startingoffset = buffer_tell(file_buffer);
	var f = file_buffer;
	buffer_seek(f, buffer_seek_start, file_buffer_offset);
	
	var chunk_type_ord = [0,0,0];
	var chunk_type = "000";
	var chunk_version;
	var chunk_len;
	var chunk_jump;
	
	while ( chunk_type != "END" ) {
		// Read chunk header
		chunk_type_ord[0] = buffer_read(f, buffer_u8);	
		chunk_type_ord[1] = buffer_read(f, buffer_u8);	
		chunk_type_ord[2] = buffer_read(f, buffer_u8);	
		chunk_type = (
			chr(chunk_type_ord[0]) + 
			chr(chunk_type_ord[1]) + 
			chr(chunk_type_ord[2])
		);
		chunk_version = buffer_read(f, buffer_u8);
		chunk_len = buffer_read(f, buffer_s32);
		chunk_jump = buffer_tell(f) + chunk_len;
		
		//show_debug_message(chunk_type);
		
		// End .......................................
		if ( chunk_type == "END" ) {
			buffer_read(f, buffer_u32);	// Zero 
		}
		// Name .......................................
		if ( chunk_type == "NAM" ) {
			outvbm.name = buffer_read(f, buffer_string); 
		}
		// Vertex Buffer .............................
		else if ( chunk_type == "VTX" ) {
			var format_key = buffer_read(f, buffer_s32);
			var buffer_size = buffer_read(f, buffer_u32);
			var stride = VBM_FormatStride(format_key);
			
			outvbm.format_key = format_key;
			outvbm.vertex_format = VBM_FormatBuild(format_key);
			
			outvbm.vertex_buffer = vertex_create_buffer_from_buffer_ext(
				f, outvbm.vertex_format, buffer_tell(f), buffer_size / stride
			);
			
			vertex_freeze(outvbm.vertex_buffer);
		}
		// Mesh ......................................
		else if ( chunk_type == "MSH" ) {
			var mesh_count = buffer_read(f, buffer_u32);
			outvbm.meshdefs = array_create(mesh_count);
			for (var mesh_index = 0; mesh_index < mesh_count; mesh_index++) {
				var meshdef = new VBM_ModelMeshdef();
				meshdef.flags = buffer_read(f, buffer_s32);
				meshdef.name = buffer_read(f, buffer_string);
				meshdef.bone_index = buffer_read(f, buffer_s32);
				meshdef.material_index = buffer_read(f, buffer_s32);
				meshdef.loop_start = buffer_read(f, buffer_u32);
				meshdef.loop_count = buffer_read(f, buffer_u32);
				
				for (var i = 0; i < 2; i++) {
					for (var j = 0; j < 3; j++) {
						meshdef.bounds[i][j] = buffer_read(f, buffer_f32);
					}
				}
				outvbm.meshdefs[@ mesh_index] = meshdef;
			}
		}
		// Prism ......................................
		else if ( chunk_type == "PSM" ) {
			var prism_count = buffer_read(f, buffer_u32);
			outvbm.prism = array_create(prism_count);
			for (var prism_index = 0; prism_index < prism_count; prism_index++) {
				var prism = new VBM_ModelPrism();
				prism.flags = buffer_read(f, buffer_s32);
				prism.bone_index = buffer_read(f, buffer_s32);
				var loop_count = buffer_read(f, buffer_u32);
				
				var triangle_count = loop_count / 3;
				var tris = array_create(triangle_count*VBM_PRISMTRIANGLE._len);
				var t = 0;
				repeat(triangle_count) {
					// Vertices from file
					tris[t+VBM_PRISMTRIANGLE.v0x] = buffer_read(f, buffer_f32);
					tris[t+VBM_PRISMTRIANGLE.v0y] = buffer_read(f, buffer_f32);
					tris[t+VBM_PRISMTRIANGLE.v0z] = buffer_read(f, buffer_f32);
					tris[t+VBM_PRISMTRIANGLE.v1x] = buffer_read(f, buffer_f32);
					tris[t+VBM_PRISMTRIANGLE.v1y] = buffer_read(f, buffer_f32);
					tris[t+VBM_PRISMTRIANGLE.v1z] = buffer_read(f, buffer_f32);
					tris[t+VBM_PRISMTRIANGLE.v2x] = buffer_read(f, buffer_f32);
					tris[t+VBM_PRISMTRIANGLE.v2y] = buffer_read(f, buffer_f32);
					tris[t+VBM_PRISMTRIANGLE.v2z] = buffer_read(f, buffer_f32);
					
					// Calc Center
					tris[t+VBM_PRISMTRIANGLE.cx] = mean(
						tris[t+VBM_PRISMTRIANGLE.v0x], 
						tris[t+VBM_PRISMTRIANGLE.v1x], 
						tris[t+VBM_PRISMTRIANGLE.v2x],
					);
					tris[t+VBM_PRISMTRIANGLE.cy] = mean(
						tris[t+VBM_PRISMTRIANGLE.v0y], 
						tris[t+VBM_PRISMTRIANGLE.v1y], 
						tris[t+VBM_PRISMTRIANGLE.v2y],
					);
					tris[t+VBM_PRISMTRIANGLE.cz] = mean(
						tris[t+VBM_PRISMTRIANGLE.v0z], 
						tris[t+VBM_PRISMTRIANGLE.v1z], 
						tris[t+VBM_PRISMTRIANGLE.v2z],
					);
					
					// Calc Normal
					var edge1 = [
						tris[t+VBM_PRISMTRIANGLE.v1x] - tris[t+VBM_PRISMTRIANGLE.v0x],
						tris[t+VBM_PRISMTRIANGLE.v1y] - tris[t+VBM_PRISMTRIANGLE.v0y],
						tris[t+VBM_PRISMTRIANGLE.v1z] - tris[t+VBM_PRISMTRIANGLE.v0z]
					];
					var edge2 = [
						tris[t+VBM_PRISMTRIANGLE.v2x] - tris[t+VBM_PRISMTRIANGLE.v0x],
						tris[t+VBM_PRISMTRIANGLE.v2y] - tris[t+VBM_PRISMTRIANGLE.v0y],
						tris[t+VBM_PRISMTRIANGLE.v2z] - tris[t+VBM_PRISMTRIANGLE.v0z]
					];
					var nx = edge1[1]*edge2[2] - edge1[2]*edge2[1];	// Cross product
					var ny = edge1[2]*edge2[0] - edge1[0]*edge2[2];
					var nz = edge1[0]*edge2[1] - edge1[1]*edge2[0];
					var d = point_distance_3d(0,0,0, nx,ny,nz);
					tris[t+VBM_PRISMTRIANGLE.nx] = nx;
					tris[t+VBM_PRISMTRIANGLE.ny] = ny;
					tris[t+VBM_PRISMTRIANGLE.nz] = nz;
					
					t += VBM_PRISMTRIANGLE._len;
				}
				prism.triangles = tris;
				outvbm.prisms[@ prism_index] = prism;
			}
		}
		// Materials ....................................
		else if ( chunk_type == "MTL" ) {
			var material_count = buffer_read(f, buffer_u32);
			outvbm.materials = array_create(material_count);
			for (var material_index = 0; material_index < material_count; material_index++) {
				var mtl = new VBM_ModelMaterial();
				mtl.flags = buffer_read(f, buffer_s32) | VBM_MATERIALFLAG.USEDEPTH;
				mtl.shader_name = buffer_read(f, buffer_string);
				
				// Each material can hold up to 4 texture_sprites
				for (var i = 0; i < 4; i++) {
					mtl.texture_flags[i] = buffer_read(f, buffer_s32);
					mtl.texture_indices[i] = buffer_read(f, buffer_s32);
					mtl.texture_paths[i] = buffer_read(f, buffer_string);
				}
				outvbm.materials[@ material_index] = mtl;
			}
		}
		// Textures ......................................
		else if ( chunk_type == "TEX" ) {
			var texture_count = buffer_read(f, buffer_u32);
			outvbm.texture_sprites = array_create(texture_count);
			for (var texture_index = 0; texture_index < texture_count; texture_index++) {
				var width = buffer_read(f, buffer_u32);
				var height = buffer_read(f, buffer_u32);
				var palette_size = buffer_read(f, buffer_u32);
				
				// Read in texture palette
				var palette = array_create(palette_size);
				for (var i = 0; i < palette_size; i++) {
					palette[i] = buffer_read(f, buffer_u32);	
				}
				
				// Set pixels using list of palette indices
				var n = width*height;
				var pixels = buffer_create(n*4, buffer_fixed, 4);
				
				// Write pixels using indices from file
				if ( palette_size < 256 ) {	// 1 Byte indices
					repeat(n) {buffer_write(pixels, buffer_u32, palette[buffer_read(f, buffer_u8)]);}
				}
				else {	// 2 Byte Indices
					repeat(n) {buffer_write(pixels, buffer_u32, palette[buffer_read(f, buffer_u16)]);}
				}
				
				// Create sprite that holds texture
				var surf = surface_create(width, height, surface_rgba8unorm);
				buffer_set_surface(pixels, surf, 0);
				var tex = sprite_create_from_surface(surf, 0,0,width,height, 0,0,0,0);
				
				// Cleanup
				surface_free(surf);
				buffer_delete(pixels);
				surf = -1;
				palette = -1;
				
				outvbm.texture_sprites[@ texture_index] = tex;
			}
		}
		// Bones ....................................
		else if ( chunk_type == "SKE" ) {
			var bone_count = buffer_read(f, buffer_u32);
			outvbm.bones = array_create(bone_count);
			for (var bone_index = 0; bone_index < bone_count; bone_index++) {
				var bone = new VBM_ModelBone();
				var bone_flags = buffer_read(f, buffer_s32);
				
				for (var i = 0; i < 16; i++) {bone.matrix_bind[i] = buffer_read(f, buffer_f32);}
				bone.parent_index = buffer_read(f, buffer_s32);
				bone.name = buffer_read(f, buffer_string);
				
				// Has parent node
				bone.matrix_inversebind = matrix_inverse(bone.matrix_bind);
				if ( bone.parent_index != VBM_NULLINDEX ) {
					bone.matrix_relative = matrix_multiply(
						bone.matrix_bind,
						outvbm.bones[bone.parent_index].matrix_inversebind
					);
					
					// Calculate Bone length
					var pbone = outvbm.bones[bone.parent_index];
					if ( pbone.length == 0.0 ) {
						pbone.length = point_distance_3d(
							bone.matrix_bind[VBM_M03],
							bone.matrix_bind[VBM_M13],
							bone.matrix_bind[VBM_M23],
							pbone.matrix_bind[VBM_M03],
							pbone.matrix_bind[VBM_M13],
							pbone.matrix_bind[VBM_M23]
						);
					}
				}
				// No parent node
				else {
					array_copy(bone.matrix_relative, 0, bone.matrix_bind, 0, 16);
				}
				
				// Read swing bone params
				if ( bone_flags & VBM_BONEFLAGS.SWINGBONE ) {
					bone.swing.stiffness = buffer_read(f, buffer_f32);
					bone.swing.damping = buffer_read(f, buffer_f32);
					bone.swing.limit = buffer_read(f, buffer_f32);
					bone.swing.force_strength = buffer_read(f, buffer_f32);
				}
				
				outvbm.bones[@ bone_index] = bone;
			}
		}
		// Animation ....................................
		else if ( chunk_type == "ANI" ) {
			var animation_count = buffer_read(f, buffer_u32);
			outvbm.animations = array_create(animation_count);
			for (var animation_index = 0; animation_index < animation_count; animation_index++) {
				var anim = new VBM_ModelAnimation();
				
				buffer_read(f, buffer_u32);	// Animation Header = 'ANI[version]'
				anim.flags = buffer_read(f, buffer_s32);
				anim.name = buffer_read(f, buffer_string);
				anim.duration = buffer_read(f, buffer_u32);
				anim.loop_point = buffer_read(f, buffer_u32);
				anim.curve_count = buffer_read(f, buffer_u32);
				var channel_count = buffer_read(f, buffer_u32);
				var keyframe_count = buffer_read(f, buffer_u32);
				anim.props_offset = buffer_read(f, buffer_u32);
				
				anim.curve_names = array_create(anim.curve_count, "");
				anim.curve_views = array_create(anim.curve_count*VBM_ANIMATIONVIEW._len);
				anim.animcurve = animcurve_create();
				
				var channel_offset = 0;
				var channels = array_create(channel_count);
				var channel = undefined;
				var points = undefined;
				var point = undefined;
				var channel_index = 0, keyframe_index = 0;
				var hits = 0;
				for (var curve_index = 0; curve_index < anim.curve_count; curve_index++) {
					var curvename = string(curve_index);
					if ( anim.flags & VBM_ANIMATIONFLAG.CURVENAMES ) {
						curvename = buffer_read(f, buffer_string);
					}
					
					channel_count = buffer_read(f, buffer_u32);
					
					anim.curve_names[curve_index] = curvename;
					anim.curve_views[VBM_ANIMATIONVIEW._len*curve_index + VBM_ANIMATIONVIEW.offset] = channel_offset;
					anim.curve_views[VBM_ANIMATIONVIEW._len*curve_index + VBM_ANIMATIONVIEW.size] = channel_count;
					
					for (channel_index = 0; channel_index < channel_count; channel_index++) {
						keyframe_count = buffer_read(f, buffer_u32);
						
						points = array_create(keyframe_count);
						keyframe_index = 0;
						repeat (keyframe_count) {
							point = animcurve_point_new();
							point.posx = buffer_read(f, buffer_f32) / anim.duration;
							point.value = buffer_read(f, buffer_f32);
							points[keyframe_index] = point;
							keyframe_index++;
						}
						
						// Game Maker crashes if a curve has less than two points. Add of necessary
						while ( keyframe_count < 2 ) {
							point = animcurve_point_new();
							point.posx = points[0].posx;
							point.value = points[0].value;
							array_push(points, point);
							keyframe_count++;
						}
						
						channel = animcurve_channel_new();
						channel.name = curvename + string(channel_index);
						channel.type = animcurvetype_linear;
						channel.iterations = 0;
						channel.points = points;
						
						channels[channel_offset] = channel;
						channel_offset++;
					}
				}
				anim.animcurve.channels = channels;
				
				outvbm.animations[@ animation_index] = anim;
			}
		}
		// Unknown chunk type ..........................
		else {
			
		};
		
		// Jump to next chunk
		buffer_seek(f, buffer_seek_start, chunk_jump);
	}
	
	var _bytes_read = buffer_tell(f) - _startingoffset;
	buffer_seek(f, buffer_seek_start, _startingoffset);
	return _bytes_read;
}

#endregion
