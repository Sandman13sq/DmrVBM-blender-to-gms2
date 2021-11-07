/// @desc Operators

#region // Operators ======================================================

function OP_ModelMode(value, btn)
{
	obj_modeltest.modelmode = value;
	instance_deactivate_object(obj_demomodel);
	instance_activate_object(obj_modeltest.modelobj[value]);
	
	with obj_modeltest.modelobj[value] event_perform(ev_draw, 65);
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

layout.Bool("Show Grid").DefineControl(self, "drawgrid");
layout.Bool("Show Camera Anchor").DefineControl(self, "drawcamerapos");

layout_model = new Layout()
	.SetPosXY(camera.width-200, 16, camera.width-16, 2)
layout_model.common.uiscale = 1;

layout_model.Button().Label("Open VBX").Operator(OP_LoadVBX);

var b = layout_model.Box();
b.Label("Model");

/*
var el;
var _vbx = curly.vbx_model;
for (var i = 0; i < _vbx.vbcount; i++)
{
	el = b.Bool().Label(_vbx.vbnames[i]).Operator(OP_MeshVisibility);
	el.vbindex = i;
	el.Value(curly.meshvisible & (1<<i));
}
*/

var _vbx = curly.vbx_model;

// Mesh Select
layout_meshselect = b.List()
	.Operator(function(value) {obj_modeltest.meshindex = value; obj_modeltest.UpdateActiveVBX();})

layout_meshselect.ClearListItems();
for (var i = 0; i < _vbx.vbcount; i++)
{
	layout_meshselect.DefineListItem(i, _vbx.vbnames[i], _vbx.vbnames[i]);
}

// Mesh Attributes
layout_meshattributes = b.Column();
layout_meshattributes.Bool()
	.Label("Visible")
	.SetIDName("meshvisible")
	.Operator(OP_MeshVisibility)
	.Value(curly.meshvisible & (1 << meshindex), false);

//layout_meshattributes.Enum().Operator(0);

layout_meshattributes.Real().Label("Shine").SetIDName("meshshine").SetBounds(0, 1, 0.1)
	.Operator(OP_DmShine).operator_on_change=true;
layout_meshattributes.Real().Label("Fake SSS").SetIDName("meshsss").SetBounds(0, 1, 0.1)
	.Operator(OP_DmSSS).operator_on_change=true;
layout_meshattributes.Real().Label("Emission").SetIDName("meshemission").SetBounds(0, 1, 0.1)
	.Operator(OP_DmEmission).operator_on_change=true;

// Animation
layout_model.Button().Label("Bind Pose").Operator(OP_BindPose);
layout_model.Button().SetIDName("toggleplayback")
	.Operator(OP_TogglePlayback).Value(curly.isplaying).toggle_on_click = 1;
layout_model.Button().Label("Reload Poses").Operator(OP_ReloadPoses);

layout_model.Enum().Label("Interpolation").DefineListItems([
	[AniTrack_Intrpl.constant, "Constant"],
	[AniTrack_Intrpl.linear, "Linear"],
	[AniTrack_Intrpl.smooth, "Smooth"],
	]).Operator(OP_SetInterpolation);

layout_model.Real().Label("Hue").DefineControl(obj_curly, "hue").SetBounds(-1, 1, 0.02)
layout_model.Real().Label("Saturation").DefineControl(obj_curly, "sat").SetBounds(-2, 2, 0.02)
layout_model.Real().Label("Brightness").DefineControl(obj_curly, "lum").SetBounds(-2, 2, 0.02)

#endregion
