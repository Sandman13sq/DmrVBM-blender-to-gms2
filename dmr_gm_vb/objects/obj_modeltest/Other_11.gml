/// @desc Layout

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
layout.Bool("Orbit Model").DefineControl(obj_camera, "orbitmodel").Operator(OP_ToggleOrbit);
layout.Real("Orbit Speed").SetIDName("orbitspeed").DefineControl(obj_camera, "orbitspeed").interactable = false;
