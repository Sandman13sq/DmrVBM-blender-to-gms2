/// @desc Layout

layout = new Layout().SetPosXY(8, 24, 216, 240);
layout.Enum().Label("Model")
	.DefineControl(self, "modelmode")
	.Operator(OP_ModelMode)
	.DefineListItems([
	[ModelType.simple, "Simple", "One vertex buffer with vertex colors (curly_simple.vb)"],
	[ModelType.normal, "Normal", "One vertex buffer with normal shading (curly_normal.vb)"],
	[ModelType.vbc, "VBC", "VBC model -- multiple vertex buffers (curly.vbc)"],
	[ModelType.normalmap, "VBC Normal Map", "VBC model with normal mappings (curly_nor.vbc)"],
	[ModelType.rigged, "VBC Rigged", "VBC model with bone transforms (curly_rigged.vbc)"],
	[ModelType.complete, "VBC Complete", "VBC model with all features (curly_complete.vbc)"],
	]);

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
