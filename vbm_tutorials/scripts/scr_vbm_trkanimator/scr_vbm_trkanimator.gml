/*
*/

enum TRKANIMATORFLAG
{
	forcematrices = 1<<0,
	bakelocal = 1<<1,
}

enum TRKANIMATORLAYERFLAG
{
	ignorebones = 1<<0,
	ignorecurves = 1<<1,
}

enum TRK_AnimatorCalculation
{
	evaluated = 0,
	pose = 1,
	track = 2,
}

#macro ARMATUREANIMATOR_MANUAL "<MANUAL>"

// =================================================================================
#region // Structs
// =================================================================================

/*
	Handles layered TRK animation
*/
function TRKAnimator() constructor
{
	static toString = function()
	{
		var _timestr = string_format(__updatetime*.001, 2, 2);
		
		var out = "{" +
			"Animations: " + string(variable_struct_names_count(animationpool)) +
			", " + (bonemap? "VBM 1": "VBM 0") +
			", Spd: " + string_format(animationspeed, 1, 2) +
			", Lyrs: " + string(layercount) +
			", Update: " + _timestr + "ms" +
		"}";
		
		return out;
	}
	
	static forcematrices_default = false;	// Prioritize matrices over curves
	static bakespace_default = TRK_Space.none;	// Bake curves to matrices when adding animations
	
	forcematrices = forcematrices_default;
	bakespace = bakespace_default;
	
	animationpool = {};
	animationspeed = 1;
	haslooped = 0;
	
	trkactive = 0;
	targetspace = TRK_Space.local;
	calculationmode = TRK_AnimatorCalculation.track;
	
	mattransform = Mat4();
	outposesize = VBM_MATPOSEMAX;
	outpose = Mat4ArrayFlat(outposesize);
	poseanimationdata = Mat4Array(outposesize);
	outcurves = {};
	
	parentindices = [];
	localtransforms = [];
	inversetransforms = [];
	bonemap = 0;
	
	layers = [];
	layercount = 0;
	
	framespersecond = game_get_speed(gamespeed_fps);
	__updatetime = 0;
	
	// DATA ===================================================================
	
	// Reads appropriate values from vbm data for local-space transforms
	function ReadTransformsFromVBM(vbm)
	{
		parentindices = vbm.BoneParentIndices();
		localtransforms = vbm.BoneLocalMatrices();
		inversetransforms = vbm.BoneInverseMatrices();
		bonemap = vbm.bonemap;
		
		return self;
	}
	
	function BakeAnimations(frame_step=1, compare_thresh=0.1, to_local=true, to_evaluated=true)
	{
		if (bonemap)
		{
			for (var i = 0; i < layercount; i++)
			{
				layers[i].BakeAnimations(frame_step, compare_thresh, to_local, to_evaluated);
			}
		}
	}
	
	function Layer(index) {return layers[index];}
	function LayerCount(index) {return layercount;}
	
	// Adds and returns newly created layer
	function AddLayer(_flags=0)
	{
		var lyr = new TRKAnimator_Layer(self);
		lyr.flags = _flags;
		layers[layercount] = lyr;
		layercount += 1;
		lyr.CopyAnimations(animationpool, true);
		return lyr;
	}
	
	// Initializes number of layers to fit given number
	function InitializeLayers(_layercount)
	{
		while ( layercount > _layercount )
		{
			delete layers[layercount]
			layercount -= 1;
		}
		
		while ( layercount < _layercount )
		{
			layers[layercount] = new TRKAnimator_Layer(self);
			layercount += 1;
		}
		
		return self;
	}
	
	// 
	function ReadAnimationMap(data)
	{
		for (var i = 0; i < layercount; i++) {layers[i].SetAnimationMap(data);}
		return self;
	}
	
	// Adds animation to pool for all layers
	function DefineAnimation(key, trk)
	{
		animationpool[$ string_upper(key)] = trk;
		
		for (var i = 0; i < layercount; i++) {layers[i].DefineAnimation(key, trk);}
		
		return self;
	}
	
	// Copies animations from struct. {animationname: trkdata}
	function CopyAnimations(_animationstruct, _overwrite=true)
	{
		if (!_animationstruct) {return;}
		
		var keys = variable_struct_get_names(_animationstruct);
		var n = array_length(keys);
			
		for (var i = 0; i < n; i++)
		{
			if ( _overwrite || !variable_struct_exists(animationpool, keys[i]) )
			{
				DefineAnimation(keys[i], _animationstruct[$ keys[i]]);
			}
		}
	}
		
	function CopyAnimations_Map(_animationmap, _overwrite=true)
	{
		if (!_animationmap) {return;}
		
		var k = ds_map_find_first(_animationmap);
			
		while ( ds_map_exists(_animationmap, k) )
		{
			if ( _overwrite || !variable_struct_exists(animationpool, k) )
			{
				DefineAnimation(k, _animationmap[? k]);
				k = ds_map_find_next(_animationmap, k);
			}
		}
	}
	
	// CONTROL ==========================================================================
	
	// Enables/Disables layer at index
	function SetLayerEnabled(index, enabled)
	{
		layers[index].enabled = enabled;
		return self;
	}
	
	// Sets next animation key for all layers to play
	function SetAnimationKey(key)
	{
		for (var i = 0; i < layercount; i++) {layers[i].SetAnimationKey(key);}
		return self;
	}
	
	// Sets next animation for all layers to play
	function SetAnimationData(trkdata)
	{
		for (var i = 0; i < layercount; i++) {layers[i].SetAnimationData(trkdata);}
		return self;
	}
	
	function SetAnimationPosition(pos)
	{
		for (var i = 0; i < layercount; i++) {layers[i].SetAnimationPosition(pos);}
		return self;
	}
	
	// Queues animation key to play after animation finishes
	function QueueAnimationKey(key)
	{
		for (var i = 0; i < layercount; i++) {layers[i].QueueAnimationKey(key);}
		return self;
	}
	
	// Clears queued animations
	function ClearAnimationQueue()
	{
		for (var i = 0; i < layercount; i++) {layers[i].ClearAnimationQueue();}
		return self;
	}
	
	// Sets position to marker in animation
	function SetPositionToMarker(markername)
	{
		for (var i = 0; i < layercount; i++) {layers[i].SetPositionToMarker();}
		return self;
	}
	
	// Progresses animation for all enabled layers
	function UpdateAnimation(ts)
	{
		__updatetime = get_timer();
		
		var _updated = 0;
		for (var i = 0; i < layercount; i++)
		{
			if ( layers[i].enabled )
			{
				if ( layers[i].UpdateAnimation(ts * animationspeed) )
				{
					_updated |= 1 << i;
				}
			}
		}
		
		if ( calculationmode > TRK_AnimatorCalculation.evaluated )
		{
			CalculateAnimationPose(
				parentindices,
				localtransforms, 
				inversetransforms, 
				poseanimationdata, 
				outpose,
				mattransform
				);
			
		}
		
		__updatetime = get_timer()-__updatetime;
		
		return _updated;
	}
	
	function SetMatTransform(mat4transform)
	{
		array_copy(mattransform, 0, mat4transform, 0, 16);
	}
	
	// OUTPUT ==========================================================================
	
	// Returns final pose to give to shader matrix uniform call
	function OutputPose()
	{
		return outpose;
	}
	
	// Returns value from curves if exists, else default_value
	function CurveValue(curvename, default_value=undefined, index=0)
	{
		return variable_struct_exists(outcurves, curvename)? outcurves[$ curvename][index]: default_value;
	}
	
	// Returns vector from curves if exists, else default_vector
	function CurveVector(curvename, default_vector=undefined)
	{
		return variable_struct_exists(outcurves, curvename)? outcurves[$ curvename]: default_vector;
	}
	
	// Returns true if curve exists
	function CurveExists(curvename)
	{
		return variable_struct_exists(outcurves, curvename);
	}
	
	function SetMatrixIndex(mat4index, _mat4)
	{
		array_copy(outpose, mat4index*16, _mat4, 0, 16);
	}
}

/*
	Instantiated via TRKAnimator struct. DO NOT CONSTRUCT OUTSIDE OF ANIMATOR
	Calculates animation matrices and curve values.
*/
function TRKAnimator_Layer(_rootanimator) constructor
{
	root = _rootanimator;
		
	enabled = true;
	flags = 0;
		
	animationpool = {};
	animationkey = "";
	animationkeylast = "";
	animationspeed = 1;
	animationlooppos = 0;
	haslooped = false;
	
	animationqueue = array_create(16);
	animationqueueindex = 0;
	animationqueuecount = 0;
		
	animationframe = 0;
	animationframelast = 0;
	animationframecount = 0;
	animationposition = 0;
	animationtimestep = 1;
	
	trkactive = 0;
	tracksavailable = false;
	matricesavailable = false;
	targetspace = TRK_Space.local;
		
	processpose = true;
	processcurves = true;
		
	interpolationtype = TRK_Intrpl.linear;
	
	swingbones = [];
		
	static toString = function()
	{
		return "{" +
			"Key: " + string(animationkey) +
			"Frame: " + string(animationframe) +
		"}";
	}
	
	function EnableFlag(_flags) {flags |= _flags; return self;}
	function DisableFlag(_flags) {flags &= ~_flags; return self;}
		
	function DefineAnimation(key, trk)
	{
		animationpool[$ string_upper(key)] = trk;
		return self;
	}
		
	// Copies animations from struct. {animationname: trkdata}
	function CopyAnimations(_animationstruct, _overwrite=true)
	{
		var keys = variable_struct_get_names(_animationstruct);
		var n = array_length(keys);
			
		for (var i = 0; i < n; i++)
		{
			if ( _overwrite || !variable_struct_exists(animationpool, keys[i]) )
			{
				DefineAnimation(keys[i], _animationstruct[$ keys[i]]);
			}
		}
	}
		
	function CopyAnimations_Map(_animationmap, _overwrite=true)
	{
		var k = ds_map_find_first(_animationmap);
			
		while ( ds_map_exists(_animationmap, k) )
		{
			if ( _overwrite || !variable_struct_exists(animationpool, k) )
			{
				DefineAnimation(k, _animationmap[? k]);
				k = ds_map_find_next(_animationmap, k);
			}
		}
	}
		
	function BakeAnimations(frame_step=1, compare_thresh=0.001, to_local=true, to_evaluated=true)
	{
		var trk;
		var keys = variable_struct_get_names(animationpool);
		var numkeys = array_length(keys);
		var numframes;
		var f;
		
		for (var i = 0; i < numkeys; i++)
		{
			trk = animationpool[$ keys[i]];
				
			trk.BakeToMatrices(
				root.bonemap,
				root.parentindices, 
				root.localtransforms, 
				root.inversetransforms,
				frame_step,
				compare_thresh,
				to_local, 
				to_evaluated
			);
		}
	}
		
	function SetAnimationMap(_map)
	{
		animationpool = _map;
		return self;
	}
	
	function SetAnimationKey(key)
	{
		animationkey = string_upper(key);
		ClearAnimationQueue();
		return self;
	}
	
	function SetAnimationData(trkdata)
	{
		animationkey = ARMATUREANIMATOR_MANUAL;
		
		if (trkactive != trkdata)
		{
			animationkeylast = "";
			trkactive = trkdata;
		}
		
		return self;
	}
	
	function SetAnimationSpeed(_speed)
	{
		animationspeed = _speed;
		return self;
	}
		
	function SetAnimationPosition(pos)
	{
		animationframe = pos / animationframecount;
		UpdateAnimation(0);
	}
	
	function KeyExists(key)
	{
		return animationpool != -1? variable_struct_exists(animationpool, key): false;
	}
		
	function QueueAnimationKey(key)
	{
		animationqueue[animationqueuecount] = key;
		animationqueuecount++;
		return self;
	}
	
	/// @arg key1,key2,...
	function QueueAnimationKeys()
	{
		for (var i = 0; i < argument_count; i++)
		{
			QueueAnimationKey(argument[i]);
		}
		return self;
	}
	
	function ClearAnimationQueue()
	{
		animationqueueindex = 0;
		animationqueuecount = 0;
		return self;
	}
	
	function NextAnimation()
	{
		if (trkactive)
		{
			animationframe = trkactive.Duration();
		}
		UpdateAnimation(0);
		
		return self;
	}
	
	function HasCompleted(clear_on_true=false)
	{
		if (haslooped && clear_on_true)
		{
			haslooped = false;
			return true;
		}
		
		return haslooped;
	}
	
	function SetPoseMatrix(mat4index, m)
	{
		array_copy(root.poseanimationdata[mat4index], 0, m, 0, 16);
	}
	
	function GetAnimationPosition()
	{
		return animationposition;
	}
	
	function UpdateAnimation(ts)
	{
		var _doupdate = 1;
		var _animationended = false;
		
		// Change Animation
		if (animationkey != animationkeylast)
		{
			animationkeylast = animationkey;
			animationframe = 0;
			animationframelast = -1;
			animationposition = 0;
			animationlooppos = 0;
			haslooped = false;
				
			if (animationkey != ARMATUREANIMATOR_MANUAL)
			{
				trkactive = animationpool[$ animationkey];
			}
				
			// Loop animation
			if (trkactive)
			{
				animationframecount = trkactive.Duration();
				animationtimestep = trkactive.CalculateTimeStep(root.framespersecond);
					
				if ( trkactive.MarkerExists("loop") )
				{
					animationlooppos = trkactive.GetMarkerPositionKey("loop")*animationframecount;
				}
			}
			
			_doupdate = 0;
		}
		
		// Update Animation
		if (trkactive)
		{
			animationframe = animationframe+animationspeed*_doupdate*ts;
				
			// Loop Animation / Move to next in queue
			if ( animationframe >= trkactive.Duration() )
			{
				_animationended = true;
				haslooped = true;
				
				// Move to next in queue
				if ( animationqueueindex < animationqueuecount )
				{
					animationkey = animationqueue[animationqueueindex];
					animationqueueindex += 1;
					UpdateAnimation(0);
				}
				// Loop animation
				else
				{
					var d = animationframecount-animationlooppos;
					while (animationframe < animationlooppos) {animationframe += d;}
					while (animationframe >= animationframecount) {animationframe -= d;}
				}
			}
				
			animationposition = animationframe / animationframecount;
			
			// Change Frame
			if ( animationframe != animationframelast )
			{
				// Update Pose
				if ( (flags & TRKANIMATORLAYERFLAG.ignorebones) == 0 && processpose)
				{
					// Realtime
					// VBM parent indices required for track animation
					if ( root.calculationmode >= TRK_AnimatorCalculation.track && trkactive.trackcount > 0 )
					{
						EvaluateAnimationTracks(
							trkactive, 
							animationposition, 
							interpolationtype, 
							root.bonemap,
							root.poseanimationdata
							);
					}
					// Calculated ahead of time = Local space
					else if ( root.calculationmode >= TRK_AnimatorCalculation.pose && trkactive.poses.count > 0 )
					{
						var pose = trkactive.FindPoseByPosition(animationposition);
						var tracknames = trkactive.TrackNames();
						
						for (var i = 0; i < trkactive.trackcount; i++)
						{
							if ( variable_struct_exists(root.bonemap, tracknames[i]) )
							{
								array_copy(
									root.poseanimationdata[root.bonemap[$ tracknames[i]]],
									0,
									pose[i],
									0,
									16
									);
							}
						}
					}
					// Evaluated ahead of time = Object Space
					else if ( root.calculationmode >= TRK_AnimatorCalculation.evaluated && trkactive.evaluations.count > 0 )
					{
						var evaluated = trkactive.FindEvaluationByPosition(animationposition);
						var tracknames = trkactive.TrackNames();
						
						for (var i = 0; i < trkactive.trackcount; i++)
						{
							if ( variable_struct_exists(root.bonemap, tracknames[i]) )
							{
								Mat4ArrayFlatSet(root.outpose, root.bonemap[$ tracknames[i]], Mat4ArrayFlatGet(evaluated, i));
							}
						}
						
						//array_copy(root.outpose, 0, trkactive.FindEvaluation(animationposition), 0, root.outposesize*16);
					}
				}
				
				// Update Curves
				if ((flags & TRKANIMATORLAYERFLAG.ignorecurves) == 0 && processcurves)
				{
					EvaluateAnimationCurves(trkactive, animationposition, root.outcurves);
				}
					
				animationframelast = animationframe;
			}
		}
		
		return _animationended;
	}
}

#endregion // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

// =================================================================================
#region // Functions
// =================================================================================

// Evaluates animation at given position and fills "outpose" with pose matrices
// Set "bonekeys" to 0 to use indices instead of bone names
function EvaluateAnimationTracks(
	trk,	// TRK struct for animation
	pos,	// 0-1 Value for animation position
	interpolationtype,	// Interpolation method for blending keyframes
	bonemap,	// Bone names to map tracks to bones. 0 for track indices
	outpose
	)
{
	// ~16% of original time / ~625% speed increase with the YYC compiler
	
	var tracknames, tracklist, tracklistmax;
	var outposematrix;
	var t, trackindex, track, trackframes, trackvectors;
	var transformtracks;
	var posnext, posprev;
	var findexprev, findexnext, findexmax, blendamt;
	var vecprev, vecnext;
	
	var possearchstart;
	var ttype;
	
	// Quat Slerp
	var q1_0, q1_1, q1_2, q1_3,
		q2_0, q2_1, q2_2, q2_3,
		qOut0, qOut1, qOut2, qOut3,
		xml, d, sqrD, sqrT, f0, f1;
	// Quat to Mat4
	var q_length, q_hyp_sqr,
		q_c, q_s, q_omc;
	
	var mm = matrix_build_identity();
	var mmscale = Mat4();
	mmscale[15] = 1;
	
	pos = clamp(pos, 0, 1);
	
	var _lastepsilon = math_get_epsilon();
	math_set_epsilon(0.0000000000001);
	
	// Trk values
	tracklist = trk.transformtracks;
	tracklistmax = array_length(tracklist);
	tracknames = trk.tracknames;
	
	var transformorder = [1,2,0] // Performs in this order: Rotation, Scale, Translation
	
	// For each track
	trackindex = 0; repeat(tracklistmax)
	{
		transformtracks = tracklist[trackindex]; // [frames[], vectors[]]
		
		if transformtracks == 0 {trackindex++; continue;}
		
		// Switch to correct index in outpose
		if ( bonemap != 0 )
		{
			if ( variable_struct_exists(bonemap, tracknames[trackindex]) )
			{
				t = bonemap[$ tracknames[trackindex]];
			}
			else
			{
				trackindex++; 
				continue;
			}
		}
		else
		{
			t = trackindex;
		}
		
		outposematrix = outpose[@ t]; // Target Bone Matrix
		
		// For each transform (location, scale, rotation)
		// Performs in this order: Rotation, Scale, Translation
		ttype = 0;
		repeat(3)
		{
			track = transformtracks[transformorder[ttype]]; // TRKData_TrackTransform
			trackframes = track.framepositions;
			trackvectors = track.vectors;
			findexmax = track.count - 1;
			
			// Single Keyframe
			if (findexmax == 0)
			{
				vecprev = trackvectors[0];
				
				switch(transformorder[ttype])
				{
					case(0): // Transform
						// Only copy to the location values (indices 12 to 15)
						array_copy(outposematrix, 12, vecprev, 0, 3);
						break;
					
					case(2): // Scale
						// Update the diagonal values of the temporary scale matrix
						mmscale[0] = vecprev[0];
						mmscale[5] = vecprev[1];
						mmscale[10] = vecprev[2];
						array_copy( outposematrix, 0, matrix_multiply(mmscale, outposematrix), 0, 16);
						break;
				
					case(1): // Quaternion
						// Quaternion to Mat4 ===================================================
						q1_0 = vecprev[0]; q1_1 = vecprev[1]; q1_2 = vecprev[2]; q1_3 = vecprev[3];
						q_length = sqrt(q1_1*q1_1 + q1_2*q1_2 + q1_3*q1_3);
						
						if (q_length == 0)
						{
							outposematrix[@ 0] = 1; outposematrix[@ 1] = 0; outposematrix[@ 2] = 0; //out[@ 3] = 0;
							outposematrix[@ 4] = 0; outposematrix[@ 5] = 1; outposematrix[@ 6] = 0; //out[@ 7] = 0;
							outposematrix[@ 8] = 0; outposematrix[@ 9] = 0; outposematrix[@10] = 1; //out[@11] = 0;
						}
						else
						{
							q_hyp_sqr = q_length*q_length + q1_0*q1_0;
							// Calculate trig coefficients
							q_c   = 2*q1_0*q1_0 / q_hyp_sqr - 1;
							q_s   = 2*q_length*q1_0*q_hyp_sqr;
							q_omc = 1 - q_c;
							// Normalize the input vector
							q1_1 /= q_length; q1_2 /= q_length; q1_3 /= q_length;
							// Build matrix
							outposematrix[@ 0] = q_omc*q1_1*q1_1 + q_c;
							outposematrix[@ 1] = q_omc*q1_1*q1_2 + q_s*q1_3;
							outposematrix[@ 2] = q_omc*q1_1*q1_3 - q_s*q1_2;
							outposematrix[@ 4] = q_omc*q1_1*q1_2 - q_s*q1_3;
							outposematrix[@ 5] = q_omc*q1_2*q1_2 + q_c;
							outposematrix[@ 6] = q_omc*q1_2*q1_3 + q_s*q1_1;
							outposematrix[@ 8] = q_omc*q1_1*q1_3 + q_s*q1_2;
							outposematrix[@ 9] = q_omc*q1_2*q1_3 - q_s*q1_1;
							outposematrix[@10] = q_omc*q1_3*q1_3 + q_c;
						}
						break;
				}
				
			}
			// Multiple Keyframes
			else if (findexmax > 0)
			{
				// Guess initial position
				findexprev = clamp( floor(pos*findexmax), 0, findexmax);
				possearchstart = trackframes[findexprev];
				
				if (possearchstart < pos) // Search starting from beginning moving forwards
				{
					findexnext = findexprev;
					while (pos >= trackframes[findexnext] && findexnext < findexmax) {findexnext++;}
					findexprev = max(findexnext - 1, 0);
				}
				else // Search starting from end moving backwards
				{
					while (pos <= trackframes[findexprev] && findexprev > 0) {findexprev--;}
					findexnext = min(findexprev + 1, findexmax);
				}
				
				posprev = trackframes[findexprev];	// Position of keyframe that "pos" is ahead of
				posnext = trackframes[findexnext];	// Position of next keyframe
			
				// Find Blend amount (Map "pos" distance to [0-1] value)
				blendamt = clamp((pos - posprev) / (posnext - posprev), 0.0, 1.0);
				
				// Apply Interpolation
				if (interpolationtype == TRK_Intrpl.constant) {blendamt = blendamt >= 0.99;}
				else if (interpolationtype == TRK_Intrpl.smooth) {blendamt = 0.5*(1-cos(pi*blendamt));}
				
				// Apply Transform
				vecprev = trackvectors[findexprev];
				vecnext = trackvectors[findexnext];
				
				switch(transformorder[ttype])
				{
					case(0): // Transform
						// Only copy to the location values (indices 12 to 15)
						outposematrix[@ 12] = lerp(vecprev[0], vecnext[0], blendamt);
						outposematrix[@ 13] = lerp(vecprev[1], vecnext[1], blendamt);
						outposematrix[@ 14] = lerp(vecprev[2], vecnext[2], blendamt);
						break;
					
					case(2): // Scale
						// Update the diagonal values of the temporary scale matrix
						mmscale[0] = lerp(vecprev[0], vecnext[0], blendamt);
						mmscale[5] = lerp(vecprev[1], vecnext[1], blendamt);
						mmscale[10] = lerp(vecprev[2], vecnext[2], blendamt);
						mm = matrix_multiply(mmscale, outposematrix);
						array_copy(outposematrix, 0, mm, 0, 16);
						
						break;
					
					case(1): // Quaternion
						// Fast Quaternion Slerp =====================================================
						/*
							Sourced from this paper by David Eberly, licensed under CC 4.0.
							Paper: https://www.geometrictools.com/Documentation/FastAndAccurateSlerp.pdf
							CC License: https://creativecommons.org/licenses/by/4.0/
						*/
						
						q1_0 = vecprev[0]; q1_1 = vecprev[1]; q1_2 = vecprev[2]; q1_3 = vecprev[3];
						q2_0 = vecnext[0]; q2_1 = vecnext[1]; q2_2 = vecnext[2]; q2_3 = vecnext[3];
						
						xml = (q1_0*q2_0 + q1_1*q2_1 + q1_2*q2_2 + q1_3*q2_3)-1.0;
						
						if ( xml == 0 )
						{
							qOut0 = q1_0;
							qOut1 = q1_1;
							qOut2 = q1_2;
							qOut3 = q1_3;
						}
						else
						{
							d = 1.0-blendamt; 
							sqrT = blendamt*blendamt;
							sqrD = d*d;
						
							f0 = blendamt * (
								1+((QUATSLERP_U0 * sqrT - QUATSLERP_V0) * xml)*(
								1+((QUATSLERP_U1 * sqrT - QUATSLERP_V1) * xml)*(
								1+((QUATSLERP_U2 * sqrT - QUATSLERP_V2) * xml)*(
								1+((QUATSLERP_U3 * sqrT - QUATSLERP_V3) * xml)*(
								1+((QUATSLERP_U4 * sqrT - QUATSLERP_V4) * xml)*(
								1+((QUATSLERP_U5 * sqrT - QUATSLERP_V5) * xml)*(
								1+((QUATSLERP_U6 * sqrT - QUATSLERP_V6) * xml)*(
								1+((QUATSLERP_U7 * sqrT - QUATSLERP_V7) * xml)
								))))))));
						
							f1 = d * (
								1+((QUATSLERP_U0 * sqrD - QUATSLERP_V0) * xml)*(
								1+((QUATSLERP_U1 * sqrD - QUATSLERP_V1) * xml)*(
								1+((QUATSLERP_U2 * sqrD - QUATSLERP_V2) * xml)*(
								1+((QUATSLERP_U3 * sqrD - QUATSLERP_V3) * xml)*(
								1+((QUATSLERP_U4 * sqrD - QUATSLERP_V4) * xml)*(
								1+((QUATSLERP_U5 * sqrD - QUATSLERP_V5) * xml)*(
								1+((QUATSLERP_U6 * sqrD - QUATSLERP_V6) * xml)*(
								1+((QUATSLERP_U7 * sqrD - QUATSLERP_V7) * xml)
								))))))));
						
							qOut0 = f0 * q1_0 + f1 * q2_0;
							qOut1 = f0 * q1_1 + f1 * q2_1;
							qOut2 = f0 * q1_2 + f1 * q2_2;
							qOut3 = f0 * q1_3 + f1 * q2_3;
						}
						
						var qOut = [0,0,0,0]
						QuatSlerp_r(vecprev, vecnext, blendamt, qOut);
						
						qOut0 = qOut[0];
						qOut1 = qOut[1];
						qOut2 = qOut[2];
						qOut3 = qOut[3];
						
						// Quaternion to Mat4 ===================================================
						q_length = sqrt(qOut1*qOut1 + qOut2*qOut2 + qOut3*qOut3);
						
						if (q_length == 0)
						{
							outposematrix[@ 0] = 1; outposematrix[@ 1] = 0; outposematrix[@ 2] = 0; //out[@ 3] = 0;
							outposematrix[@ 4] = 0; outposematrix[@ 5] = 1; outposematrix[@ 6] = 0; //out[@ 7] = 0;
							outposematrix[@ 8] = 0; outposematrix[@ 9] = 0; outposematrix[@10] = 1; //out[@11] = 0;
						}
						else
						{
							q_hyp_sqr = q_length*q_length + qOut0*qOut0;
							// Calculate trig coefficients
							q_c   = 2*qOut0*qOut0 / q_hyp_sqr - 1;
							q_s   = 2*q_length*qOut0*q_hyp_sqr;
							q_omc = 1 - q_c;
							// Normalize the input vector
							qOut1 /= q_length; qOut2 /= q_length; qOut3 /= q_length;
							// Build matrix
							outposematrix[@ 0] = q_omc*qOut1*qOut1 + q_c;
							outposematrix[@ 1] = q_omc*qOut1*qOut2 + q_s*qOut3;
							outposematrix[@ 2] = q_omc*qOut1*qOut3 - q_s*qOut2;
							outposematrix[@ 4] = q_omc*qOut1*qOut2 - q_s*qOut3;
							outposematrix[@ 5] = q_omc*qOut2*qOut2 + q_c;
							outposematrix[@ 6] = q_omc*qOut2*qOut3 + q_s*qOut1;
							outposematrix[@ 8] = q_omc*qOut1*qOut3 + q_s*qOut2;
							outposematrix[@ 9] = q_omc*qOut2*qOut3 - q_s*qOut1;
							outposematrix[@10] = q_omc*qOut3*qOut3 + q_c;
						}
						
						break;
				}
			}
			
			ttype++;
		}
		
		trackindex++;
	}
	
	math_set_epsilon(_lastepsilon);
	
	return outpose;
}

// Evaluates animation at given position and fills "outvalues" with evaluated values/vectors
function EvaluateAnimationCurves(
	trk,		// TRK struct for animation
	pos,		// 0-1 Value for animation position
	outvalues={}	// A struct to store evaluated values in. Creates entries if not present
	)
{
	var outvector;
	var curvegroups = trk.curvegroups;
	var curvedatacount = trk.curvecount;
	var curvenames = trk.curvenames;
	var activecurvebundle;
	var curve;
	var curvename;
	var curvearrayindex;
	var curvefrequency;
	var curveentryindex;
	var t, trackframes, trackvalues;
	
	var possearchstart;
	var posnext, posprev;
	var findexprev, findexnext, findexmax, blendamt;
	
	pos = clamp(pos, 0, 1);
	
	var _lastepsilon = math_get_epsilon();
	math_set_epsilon(0.0000000000001);
	
	// For each track
	t = 0; repeat(curvedatacount)
	{
		activecurvebundle = curvegroups[t]; // [curve, curve, ...]
		
		curvefrequency = array_length(activecurvebundle);
		curvename = curvenames[t];
		
		// For each transform
		curveentryindex = 0;
		
		if ( !variable_struct_exists(outvalues, curvename) )
		{
			variable_struct_set(outvalues, curvename, []);
		}
		
		repeat(curvefrequency)
		{
			curve = activecurvebundle[curveentryindex]; // TRKData_FCurve
			curvearrayindex = curve.array_index;
			
			outvalues[$ curvename][curvearrayindex] = curve.Evaluate(pos);
			curveentryindex += 1;
		}
		
		t++;
	}
	
	math_set_epsilon(_lastepsilon);
}

/*
	Fills outtransform with calculated animation pose
	bone_parentindices = Array of parent index for bone at current index
	bone_localmatricies = Array of local 4x4 matrices for bones
	bone_inversemodelmatrices = Array of inverse 4x4 matrices for bones
	posedata = Array of 4x4 matrices. 2D
	outposetransform = Flat Array of matrices in localspace, size = len(posedata) * 16, give to shader
	outbonetransform = Array of bone matrices in modelspace
*/
function CalculateAnimationPose(
	bone_parentindices, bone_localmatricies, bone_inversemodelmatrices, posedata, 
	outposetransform, mattransform=matrix_build_identity(), outbonetransform = [])
{
	var n = min( array_length(bone_parentindices), array_length(posedata));
	var i;
	var m;
	var localtransform = array_create(n);	// Parent -> Bone
	//var outbonetransform = array_create(n);	// Origin -> Bone
	array_resize(outbonetransform, n);
	
	// Calculate animation for specific bone
	i = 0; repeat(n)
	{
		localtransform[i++] = matrix_multiply(
			posedata[i], bone_localmatricies[i]);
	}
	
	// Set the model transform of bone using parent transform
	// Only works if the parents preceed their children in array
	
	outbonetransform[@ 0] = matrix_multiply(localtransform[0], mattransform); // Edge case for root bone
	
	i = 1; repeat(n-1)
	{
		outbonetransform[@ i++] = matrix_multiply(
			localtransform[i], outbonetransform[ bone_parentindices[i] ]);
	}
	
	// Compute final matrix for bone
	i = 0; repeat(n)
	{
		array_copy(outposetransform, (i++)*16, matrix_multiply(bone_inversemodelmatrices[i], outbonetransform[i]), 0, 16);
	}
}

#endregion // ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
