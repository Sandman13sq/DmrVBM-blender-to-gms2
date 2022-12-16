/*
*/

#macro ARMATUREANIMATOR_MANUAL "<MANUAL>"

function TRKAnimator() constructor
{
	function TRKAnimator_Layer(_rootanimator) constructor
	{
		root = _rootanimator;
		
		enabled = true;
		
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
	
		trkactive = 0;
		tracksavailable = false;
		matricesavailable = false;
		targetspace = TRK_Space.local;
		
		processpose = true;
		processcurves = true;
		
		interpolationtype = TRK_Intrpl.linear;
		
		static toString = function()
		{
			return "{" +
				"Key: " + string(animationkey) +
				"Frame: " + string(animationframe) +
			"}";
		}
		
		function DefineAnimation(key, trk)
		{
			animationpool[$ key] = trk;
			return self;
		}
		
		function CopyAnimations(_animationdict, _overwrite=true)
		{
			var keys = variable_struct_get_names(_animationdict);
			var n = array_length(keys);
			
			for (var i = 0; i < n; i++)
			{
				if ( _overwrite || !variable_struct_exists(animationpool, keys[i]) )
				{
					animationpool[$ keys[i]] = _animationdict[$ keys[i]];
				}
			}
		}
	
		function SetAnimationMap(_map)
		{
			animationpool = _map;
			return self;
		}
	
		function SetAnimationKey(key)
		{
			animationkey = key;
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
				animationframe = trkactive.FrameCount();
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
			CalculateAnimationPose(
				root.parentindices,
				root.localtransforms, 
				root.inversetransforms, 
				root.poseanimationdata, 
				root.outpose);
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
					animationframecount = trkactive.FrameCount();
					
					if ( trkactive.MarkerExists("loop") )
					{
						animationlooppos = trkactive.GetMarkerPositionKey("loop")*animationframecount;
					}
					
					tracksavailable = (trkactive.TrackSpace() == targetspace) && (array_length(root.parentindices) > 0);
					matricesavailable = (trkactive.MatrixSpace() == targetspace) || (trkactive.MatrixSpace() == TRK_Space.evaluated);
				}
			
				_doupdate = 0;
			}
		
			// Update Animation
			if (trkactive)
			{
				animationframe = animationframe+animationspeed*_doupdate*ts;
				
				// Loop Animation / Move to next in queue
				if ( animationframe >= trkactive.FrameCount() )
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
					if (processpose)
					{
						// Realtime
						// VBM parent indices required for track animation
						
						if ( !(root.forcematrices && matricesavailable) && tracksavailable )
						{
							EvaluateAnimationTracks(
								trkactive, 
								animationposition, 
								interpolationtype, 
								root.bonemap, 
								root.poseanimationdata
								);
							
							CalculateAnimationPose(
								root.parentindices, 
								root.localtransforms, 
								root.inversetransforms, 
								root.poseanimationdata, 
								root.outpose
								);
						}
						// Evaluated
						else if ( matricesavailable )
						{
							array_copy(root.outpose, 0, trkactive.GetFrameMatrices(animationframe), 0, root.outposesize*16);
						}
					}
					
					// Update Curves
					if (processcurves)
					{
						EvaluateAnimationCurves(trkactive, animationposition, root.outcurves);
					}
					
					animationframelast = animationframe;
				}
			}
		
			return _animationended;
		}
	}
	
	static forcematrices = false;
	
	animationpool = {};
	animationspeed = 1;
	haslooped = 0;
	
	trkactive = 0;
	tracksavailable = false;
	matricesavailable = false;
	targetspace = TRK_Space.local;
	
	outposesize = 200;
	outpose = Mat4ArrayFlat(outposesize);
	poseanimationdata = Mat4Array(outposesize);
	outcurves = {};
	
	parentindices = [];
	localtransforms = [];
	inversetransforms = [];
	bonemap = 0;
	
	layers = [];
	layercount = 0;
	
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
	
	function Layer(index) {return layers[index];}
	function LayerCount(index) {return layercount;}
	
	// Adds and returns newly created layer
	function AddLayer()
	{
		var lyr = new TRKAnimator_Layer(self);
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
		animationpool[$ key] = trk;
		
		for (var i = 0; i < layercount; i++) {layers[i].DefineAnimation(key, trk);}
		return self;
	}
	
	// Copies animations from struct. {animationname: trkdata}
	function CopyAnimations_Struct(_animationstruct, _overwrite=true)
	{
		var keys = variable_struct_get_names(_animationstruct);
		var n = array_length(keys);
		
		for (var i = 0; i < n; i++)
		{
			if ( _overwrite || !variable_struct_exists(animationpool, keys[i]) )
			{
				animationpool[$ keys[i]] = _animationstruct[$ keys[i]];
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
		for (var i = 0; i < layercount; i++)
		{
			if ( layers[i].enabled )
			{
				layers[i].UpdateAnimation(ts * animationspeed);
			}
		}
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
	
}

