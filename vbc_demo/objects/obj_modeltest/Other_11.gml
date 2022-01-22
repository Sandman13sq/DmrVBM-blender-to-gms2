/// @desc Layout

layout = new Layout().SetPosXY(8, 24, 216, 240);
layout.Enum().Label("Model")
	.DefineControl(self, "modelmode")
	.Operator(OP_ModelMode)
	.DefineItems([
	[ModelType.simple, "Simple", "One vertex buffer with vertex colors (curly_simple.vb)"],
	[ModelType.normal, "Normal", "One vertex buffer with normal shading (curly_normal.vb)"],
	[ModelType.vbm, "VBM", "VBM model -- multiple vertex buffers (curly.vbm)"],
	[ModelType.normalmap, "VBM Normal Map", "VBM model with normal mappings (curly_nor.vbm)"],
	[ModelType.rigged, "VBM Rigged", "VBM model with bone transforms (curly_rigged.vbm)"],
	[ModelType.complete, "VBM Complete", "VBM model with all features (curly_complete.vbm)"],
	])
	.SetDefault(modelmode);

layout_worlds = layout.Enum("World")
	.DefineControl(self, "worldindex")
	.Operator(OP_WorldSelect);
for (var i = 0; i < worldcount; i++)
{
	layout_worlds.DefineListItem(i, worldnames[i]);
}

layout.Bool("Show World").DefineControl(self, "drawworld");
layout.Bool("Show Grid").DefineControl(self, "drawgrid");
layout.Bool("Show Camera Anchor").DefineControl(self, "drawcamerapos");
layout.Button("Reset Model Position").Operator(self.ResetModelPosition);
layout.Button("Reset Camera Position").Operator(obj_camera.ResetCameraPosition);
layout.Bool("Orbit Model").DefineControl(obj_camera, "orbitmodel").Operator(OP_ToggleOrbit);
layout.Real("Orbit Speed").SetIDName("orbitspeed").DefineControl(obj_camera, "orbitspeed").interactable = false;
