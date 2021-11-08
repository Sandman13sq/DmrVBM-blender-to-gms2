/// @desc Operators

#region // Operators ======================================================

function OP_ModelMode(value, btn)
{
	obj_modeltest.modelmode = value;
	obj_modeltest.modelactive = modelobj[value];
	instance_deactivate_object(obj_demomodel);
	instance_activate_object(obj_modeltest.modelactive);
	
	with obj_modeltest.modelactive event_perform(ev_draw, 65);
}

function OP_BindPose(value, btn)
{
	with obj_curly
	CalculateAnimationPose(
		vbx_model.bone_parentindices,
		vbx_model.bone_localmatricies,
		vbx_model.bone_inversematricies,
		array_create(200, matrix_build_identity()),
		matpose
		);
}

function OP_MeshVisibility(value, btn) 
{
	if value {obj_curly.meshvisible |= (1 << obj_modeltest.meshindex);}
	else {obj_curly.meshvisible &= ~(1 << obj_modeltest.meshindex);}
	
	obj_modeltest.UpdateActiveVBX();
}

function OP_TogglePlayback(value, btn)
{
	btn.Label(value? "Stop Animation": "Play Animation");
	with obj_curly
	isplaying = value;
}

function OP_DmShine(value, btn) {obj_modeltest.meshdataactive.shine = value;}
function OP_DmEmission(value, btn) {obj_modeltest.meshdataactive.emission = value;}
function OP_DmSSS(value, btn) {obj_modeltest.meshdataactive.sss = value;}

function OP_FieldOvView(value, btn) {obj_curly.camera = value;}

function OP_ReloadPoses(value, btn) {with obj_curly ReloadPoses();}

function OP_SetInterpolation(value, btn) {with obj_curly interpolationtype = value;}

function OP_LoadVBX(value, btn) 
{
	var _fname = get_open_filename("*.vbx", "curly.vbx");
	if _fname != ""
	{
		var _vbx = LoadVBX(_fname, RENDERING.vbformat.rigged);
		if _vbx
		{
			VBXFree(obj_curly.vbx_model);
			obj_curly.vbx_model = _vbx;
		}
	}
}

#endregion

#region // Layout =============================================================

layout = new Layout().SetPosXY(16, 16, 200, 2);
layout.Enum().Label("Model")
	.DefineControl(self, "modelmode")
	.Operator(OP_ModelMode)
	.DefineListItems([
	[ModelType.simple, "Simple", "One vertex buffer with vertex colors (curly_simple.vb)"],
	[ModelType.normal, "Normal", "One vertex buffer with normal shading (curly_normal.vb)"],
	[ModelType.vbx, "VBX", "VBX model -- multiple vertex buffers (curly.vbx)"],
	[ModelType.normalmap, "VBX Normal Map", "VBX model with normal mappings (curly_nor.vbx)"],
	[ModelType.rigged, "VBX Rigged", "VBX model with bone transforms (curly_rigged.vbx)"],
	[ModelType.full, "VBX Full", "VBX model with all features (curly_full.vbx)"],
	]);

layout.Bool("Show World").DefineControl(self, "drawworld");
layout.Bool("Show Grid").DefineControl(self, "drawgrid");
layout.Bool("Show Camera Anchor").DefineControl(self, "drawcamerapos");
layout.Button("Reset Model Position").Operator(self.ResetModelPosition);
layout.Button("Reset Camera Position").Operator(obj_camera.ResetCameraPosition);

#endregion
