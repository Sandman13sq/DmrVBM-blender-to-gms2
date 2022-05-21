/*
	Operations and functions for 4x4 Matrices
*/

/*
	GM matrix index ref:
	[
		 0,  4,  8, 12,	| (x)
		 1,  5,  9, 13,	| (y)
		 2,  6, 10, 14,	| (z)
		 3,  7, 11, 15	|
		----------------
		(0) (0) (0)     
	]
*/

// ====================================================================
#region // Mat4 Initializations
// ====================================================================

// Returns identity matrix
function Mat4()
{
	gml_pragma("forceinline"); return matrix_build_identity();
}

// Returns array filled with given matrix m
// [ mat, mat, ... ]
function Mat4Array(nummatrices, m = matrix_build_identity())
{
	var out = array_create(nummatrices, 0);
	for (var i = 0; i < nummatrices; i++)
	{
		out[i] = array_create(16); // Make new mat4
		array_copy(out[i], 0, m, 0, 16); // Copy default value to new mat4
	}
	
	return out;
}

// Returns 1d array filled with given matrix m
// [ 0, 0, 0, 1, 0, 0, 1, 0, ... ]
function Mat4ArrayFlat(nummatrices, m = matrix_build_identity())
{
	var out = array_create(nummatrices*16);
	
	if nummatrices > 0
	{
		// Set first entry
		array_copy(out, 0, m, 0, 16);
	
		if nummatrices > 1
		{
			// Copy section of copied matrices to index of non-copied position
			/*
				10000000 (Start with first matrix copied)
				11000000 (Copy values [0-1] to index 1. Num copies = 2)
				11110000 (Copy values [0-2] to index 2. Copies = 4)
				11111111 (Copy values [0-4] to index 4. Copies = 8)
				[0-8] to 8, [0-16] to 16, [0-32] to 32, and so on...
				
				iterations = log2(n)
				leftover = n - 2^log2(n)
			*/
			
			var nn = 1; // Number of copied matrices
			
			// Fill up most of array
			repeat( log2(nummatrices) ) //while (nn*2 <= n)
			{
				array_copy(out, nn*16, out, 0, nn*16);
				nn *= 2;
			}
			
			// Fill in leftoveer
			if nn < nummatrices
			{
				array_copy(out, (nummatrices-nn)*16, out, 0, nn*16);
			}
		}
	}
	
	return out;
}

// Returns flattened mat4 array (2D -> 1D)
function Mat4ArrayFlatten(mat4array)
{
	var n = array_length(mat4array) * 16;
	var out = array_create(n, 0);
	for (var i = 0; i < n; i += 16)
	{
		array_copy(out, i, mat4array[i div 16], 0, 16); // Copy default array to position
	}
	
	return out;
}

// Returns array of mat4s (1D -> 2D)
function Mat4ArrayPartition(flatarray)
{
	var n = array_length(flatarray);
	var out = array_create(n/16);
	for (var i = 0; i < n; i += 16)
	{
		out[i div 16] = array_create(16);
		array_copy(out[i div 16], 0, flatarray, i, 16);
	}
	
	return out;
}

// Set value in flat mat4 Array to "m"
function Mat4ArrayFlatSet(flatarray, index, m)
{
	gml_pragma("forceinline");
	array_copy(flatarray, index * 16, m, 0, 16);
}

// Returns matrix at index in flat array
function Mat4ArrayFlatGet(flatarray, index, out = array_create(16))
{
	array_copy(out, 0, flatarray, index*16, 16);
	return out;
}

// Sets all matrices in flat array to matrix "m"
function Mat4ArrayFlatClear(flatarray, m)
{
	var n = array_length(flatarray) div 16;
	
	if n > 0
	{
		// Set first entry
		array_copy(flatarray, 0, m, 0, 16);
	
		if n > 1
		{
			var nn = 1; // Number of copied matrices
			
			// Fill up most of array
			repeat( log2(n) ) //while (nn*2 <= n)
			{
				array_copy(flatarray, nn*16, flatarray, 0, nn*16);
				nn *= 2;
			}
			
			// Fill in leftover
			if nn < n
			{
				array_copy(flatarray, (n-nn)*16, flatarray, 0, nn*16);
			}
		}
	}
}

// Sets all matrices in flat array to matrix "m"
function Mat4ArrayFlatClearExt(flatarray, m, startindex = 0, endindex = -1)
{
	if startindex < 0 {startindex = 0;}
	if endindex < 0 {endindex = array_length(flatarray) div 16;}
	if startindex > endindex
	{
		var temp = startindex;
		startindex = endindex;
		endindex = temp;
	}
	
	startindex *= 16;
	endindex *= 16;
	
	for (var i = startindex; i < endindex; i++)
	{
		array_copy(flatarray, i, m, 0, 16);
	}
}

#endregion

// ====================================================================
#region // Mat4 Base Operations
// ====================================================================

/// Game Maker's "matrix_multiply" works left to right
/// @desc Applys matrices in the order they are given
/// @arg mat4,mat4,...
function Mat4Multiply2()
{
	var _mat = argument[0];
		
	for (var i = 1; i < argument_count; i++)
	{
		_mat = matrix_multiply(_mat, argument[i]);
	}
		
	return _mat;
}
	

// Does Scale > Rotate > Translate
function Mat4Transform(x, y, z, xrot, yrot, zrot, xscale, yscale, zscale)
{
	return matrix_multiply(
		matrix_multiply(
			Mat4ScaleXYZ(xscale, yscale, zscale), 
			Mat4Rotate(xrot, yrot, zrot)
			),
		Mat4Translate(x, y, z)
		);
}
	
// Returns scale matrix using one value
function Mat4Scale(scale)
{
	gml_pragma("forceinline");
	return [
		scale, 0, 0, 0,
		0, scale, 0, 0,
		0, 0, scale, 0,
		0, 0, 0, 1
		];
}
	
// Returns scale matrix using x, y, and z values
function Mat4ScaleXYZ(xscale, yscale, zscale)
{
	gml_pragma("forceinline");
	return [
		xscale, 0, 0, 0,
		0, yscale, 0, 0,
		0, 0, zscale, 0,
		0, 0, 0, 1
		];
}
	
function Mat4Translate(x, y, z)
{
	gml_pragma("forceinline");
	return [
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		x, y, z, 1
		];
}
	
function Mat4TranslateScale(x, y, z, scale)
{
	gml_pragma("forceinline");
	return [
		scale, 0, 0, 0,
		0, scale, 0, 0,
		0, 0, scale, 0,
		x, y, z, 1
		];
}
	
function Mat4TranslateScaleXYZ(x, y, z, xscale, yscale, zscale)
{
	gml_pragma("forceinline");
	return [
		xscale, 0, 0, 0,
		0, yscale, 0, 0,
		0, 0, zscale, 0,
		x, y, z, 1
		];
}
	
function Mat4TranslateVec3(vec3)
{
	gml_pragma("forceinline");
	return [
		1, 0, 0, 0,
		0, 1, 0, 0,
		0, 0, 1, 0,
		vec3[0], vec3[1], vec3[2], 1
		];
}
	
function Mat4Rotate(xrot, yrot, zrot)
{
	gml_pragma("forceinline");
	return matrix_build(0, 0, 0, xrot, yrot, -zrot, 1, 1, 1);
}

// Returns translation component from matrix [x,y,z]
function Mat4GetTranslation(mat4)
{
	return [mat4[12], mat4[13], mat4[14]];
}

// Sets translation in matrix
function Mat4TranslateSet(mat4, x, y, z)
{
	mat4[@ 12] = x; mat4[@ 13] = y; mat4[@ 14] = z;
}

// Removes translation component from matrix
function Mat4TranslateClear(mat4)
{
	mat4[@ 12] = 0; mat4[@ 13] = 0; mat4[@ 14] = 0;
}

#endregion

// ====================================================================
#region // Mat4 Complex Operations
// ====================================================================

function Mat4RotVector(dirx, diry, dirz, up_x, up_y, up_z, out = matrix_build_identity())
{
	// Source: https://stackoverflow.com/questions/18558910/direction-vector-to-rotation-matrix
	
	var xaxis = CrossProduct3dNormalized(up_x, up_y, up_z, dirx, diry, dirz);
	var yaxis = CrossProduct3dNormalized(dirx, diry, dirz, xaxis[0], xaxis[1], xaxis[2]);
	
	out[@ 0] = xaxis[0];
    out[@ 1] = yaxis[0];
    out[@ 2] = dirx;

    out[@ 4] = xaxis[1];
    out[@ 5] = yaxis[1];
    out[@ 6] = diry;

    out[@ 8] = xaxis[2];
    out[@ 9] = yaxis[2];
    out[@10] = dirz;
	
	return out;
	
	out[@ 0] = xaxis[0];
    out[@ 4] = yaxis[0];
    out[@ 8] = dirx;

    out[@ 1] = xaxis[1];
    out[@ 5] = yaxis[1];
    out[@ 9] = diry;

    out[@ 2] = xaxis[2];
    out[@ 6] = yaxis[2];
    out[@10] = dirz;
	
	return out;
}
	
function Mat4PointAt(x1, y1, z1, x2, y2, z2)
{
	return matrix_build(
		0, 0, 0,
		0,
		LineToAngle(x1, z1, x2, z2),
		point_direction(x1, y1, x2, y2),
		1, 1, 1
		);
}
	
function Mat4RotateAxisAngle(angle, _x, _y, _z)
{
	var _c = dcos(angle), _s = dsin(angle), _t = 1 - _c;
		
	return [
		_t*_x*_x + _c,		_t*_x*_y + _z*_s,	_t*_x*_z - _y*_s, 0,
		_t*_x*_y + _z*_s,	_t*_y*_y + _c,		_t*_y*_z + _x*_s, 0,
		_t*_x*_z + _y*_s,	_t*_y*_z - _x*_s,	_t*_z*_z + _c, 0,
		0, 0, 0, 1
		];
		
	/*
	return [
		_t*_x*_x + _c,		_t*_x*_y, _z*_s,	_t*_x*_z + _y*_s, 0,
		_t*_x*_y + _z*_s,	_t*_y*_y + _c,		_t*_y*_z - _x*_s, 0,
		_t*_x*_z - _y*_s,	_t*_y*_z + _x*_s,	_t*_z*_z + _c, 0,
		0, 0, 0, 1
		];
	*/
}
	
function Mat4RotateAxisAngleV(angle, _arr)
{
	var _c = dcos(angle), _s = dsin(angle), _t = 1 - _c,
		_x = _arr[0], _y = _arr[1], _z = _arr[2];
		
	return [
		_t*_x*_x + _c,		_t*_x*_y + _z*_s,	_t*_x*_z - _y*_s, 0,
		_t*_x*_y + _z*_s,	_t*_y*_y + _c,		_t*_y*_z + _x*_s, 0,
		_t*_x*_z + _y*_s,	_t*_y*_z - _x*_s,	_t*_z*_z + _c, 0,
		0, 0, 0, 1
		];
}
	
function Mat4Invert(m)
{
	// Lifted from: https://stackoverflow.com/questions/1148309/inverting-a-4x4-matrix
	
	var inv = matrix_build_identity(), det, i;

	inv[0] = m[5]  * m[10] * m[15] - 
	            m[5]  * m[11] * m[14] - 
	            m[9]  * m[6]  * m[15] + 
	            m[9]  * m[7]  * m[14] +
	            m[13] * m[6]  * m[11] - 
	            m[13] * m[7]  * m[10];

	inv[4] = -m[4]  * m[10] * m[15] + 
	            m[4]  * m[11] * m[14] + 
	            m[8]  * m[6]  * m[15] - 
	            m[8]  * m[7]  * m[14] - 
	            m[12] * m[6]  * m[11] + 
	            m[12] * m[7]  * m[10];

	inv[8] = m[4]  * m[9] * m[15] - 
	            m[4]  * m[11] * m[13] - 
	            m[8]  * m[5] * m[15] + 
	            m[8]  * m[7] * m[13] + 
	            m[12] * m[5] * m[11] - 
	            m[12] * m[7] * m[9];

	inv[12] = -m[4]  * m[9] * m[14] + 
	            m[4]  * m[10] * m[13] +
	            m[8]  * m[5] * m[14] - 
	            m[8]  * m[6] * m[13] - 
	            m[12] * m[5] * m[10] + 
	            m[12] * m[6] * m[9];

	inv[1] = -m[1]  * m[10] * m[15] + 
	            m[1]  * m[11] * m[14] + 
	            m[9]  * m[2] * m[15] - 
	            m[9]  * m[3] * m[14] - 
	            m[13] * m[2] * m[11] + 
	            m[13] * m[3] * m[10];

	inv[5] = m[0]  * m[10] * m[15] - 
	            m[0]  * m[11] * m[14] - 
	            m[8]  * m[2] * m[15] + 
	            m[8]  * m[3] * m[14] + 
	            m[12] * m[2] * m[11] - 
	            m[12] * m[3] * m[10];

	inv[9] = -m[0]  * m[9] * m[15] + 
	            m[0]  * m[11] * m[13] + 
	            m[8]  * m[1] * m[15] - 
	            m[8]  * m[3] * m[13] - 
	            m[12] * m[1] * m[11] + 
	            m[12] * m[3] * m[9];

	inv[13] = m[0]  * m[9] * m[14] - 
	            m[0]  * m[10] * m[13] - 
	            m[8]  * m[1] * m[14] + 
	            m[8]  * m[2] * m[13] + 
	            m[12] * m[1] * m[10] - 
	            m[12] * m[2] * m[9];

	inv[2] = m[1]  * m[6] * m[15] - 
	            m[1]  * m[7] * m[14] - 
	            m[5]  * m[2] * m[15] + 
	            m[5]  * m[3] * m[14] + 
	            m[13] * m[2] * m[7] - 
	            m[13] * m[3] * m[6];

	inv[6] = -m[0]  * m[6] * m[15] + 
	            m[0]  * m[7] * m[14] + 
	            m[4]  * m[2] * m[15] - 
	            m[4]  * m[3] * m[14] - 
	            m[12] * m[2] * m[7] + 
	            m[12] * m[3] * m[6];

	inv[10] = m[0]  * m[5] * m[15] - 
	            m[0]  * m[7] * m[13] - 
	            m[4]  * m[1] * m[15] + 
	            m[4]  * m[3] * m[13] + 
	            m[12] * m[1] * m[7] - 
	            m[12] * m[3] * m[5];

	inv[14] = -m[0]  * m[5] * m[14] + 
	            m[0]  * m[6] * m[13] + 
	            m[4]  * m[1] * m[14] - 
	            m[4]  * m[2] * m[13] - 
	            m[12] * m[1] * m[6] + 
	            m[12] * m[2] * m[5];

	inv[3] = -m[1] * m[6] * m[11] + 
	            m[1] * m[7] * m[10] + 
	            m[5] * m[2] * m[11] - 
	            m[5] * m[3] * m[10] - 
	            m[9] * m[2] * m[7] + 
	            m[9] * m[3] * m[6];

	inv[7] = m[0] * m[6] * m[11] - 
	            m[0] * m[7] * m[10] - 
	            m[4] * m[2] * m[11] + 
	            m[4] * m[3] * m[10] + 
	            m[8] * m[2] * m[7] - 
	            m[8] * m[3] * m[6];

	inv[11] = -m[0] * m[5] * m[11] + 
	            m[0] * m[7] * m[9] + 
	            m[4] * m[1] * m[11] - 
	            m[4] * m[3] * m[9] - 
	            m[8] * m[1] * m[7] + 
	            m[8] * m[3] * m[5];

	inv[15] = m[0] * m[5] * m[10] - 
	            m[0] * m[6] * m[9] - 
	            m[4] * m[1] * m[10] + 
	            m[4] * m[2] * m[9] + 
	            m[8] * m[1] * m[6] - 
	            m[8] * m[2] * m[5];

	det = m[0] * inv[0] + m[1] * inv[4] + m[2] * inv[8] + m[3] * inv[12];

	if (det == 0)
	    return false;

	det = 1.0 / det;

	for (i = 0; i < 16; i++) {inv[i] *= det;}

	return inv;
}
	
function Mat4Transpose(_mat)
{
	return [
		_mat[0],	_mat[1],	_mat[2],	_mat[3],
		_mat[4],	_mat[5],	_mat[6],	_mat[7],
		_mat[8],	_mat[9],	_mat[10],	_mat[11],
		_mat[12],	_mat[13],	_mat[14],	_mat[15],
	];
}

function Mat4LookAtVec3(eyevec3, posvec3, upvec3)
{
	return matrix_build_lookat(
		eyevec3[0], eyevec3[1], eyevec3[2],
		posvec3[0], posvec3[1], posvec3[2],
		upvec3[0], upvec3[1], upvec3[2],
	);	
}

function Mat4LookAtVec3Fwrd(eyevec3, fwrdvec3, upvec3)
{
	return matrix_build_lookat(
		eyevec3[0], eyevec3[1], eyevec3[2],
		eyevec3[0]+fwrdvec3[0], eyevec3[1]+fwrdvec3[1], eyevec3[2]+fwrdvec3[2],
		upvec3[0], upvec3[1], upvec3[2],
	);	
}

function DrawMatrix(_x, _y, _matrix)
{
	var _xstart = _x;
	
	for (var _col = 0; _col < 4; _col++)
	{
		_x = _xstart;
		for (var _row = 0; _row < 4; _row++)
		{
			draw_text(_x, _y, _matrix[_row * 4 + _col]);
			_x += 40;
		}
		_y += 16;
	}
}

#endregion
