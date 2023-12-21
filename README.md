![Repo Banner](https://github.com/Sandman13sq/DmrVBM-blender-to-gms2/blob/main/images/banner.png)

# Vertex Buffer Model Exporter and Importer by Sandman13sq
### Import/Export tools for loading vertex buffer data out of Blender and in to Game Maker Studio 2

#### .vb is Game Maker Studio's **vertex buffer data** format used in functions like `vertex_submit()`.
#### .vbm is a custom file format for exporting mesh data, skeleton bones, and action curves. 

## [[ Current version is in BETA! The present file format is not finalized. Updates may (will) break compatibility and models will need re-exporting. ]]

NOTE: If cloned straight from GitHub not all features are guranteed to work correctly.  
For stable versions see the **Releases** on the GitHub page.

# [Quick Start Guide](https://github.com/Sandman13sq/DmrVBM-blender-to-gms2/wiki/Quick-Start-Guide)

-----
  
## Blender 3.x Addon Installation
* In Blender, go to `Edit` > `Preferences` > `Add-ons`
* Click `Install` on the top right of the Preferences window
* Navigate to the `DmrVBM_Blender.zip` file (keep this zipped). Select it and click `Install Add-on`
* Enable the `DmrVBM Vertex Buffer Model Export` addon
* The VBM export panel can be found in the `Properties` > `Scene`
     * If nothing shows up try `Edit` > `Preferences` > `Interface` > `Display` > Enable `Developer Extras`

## Game Maker Studio 2 Installation
* With a GMS2 project open, go to `Tools` > `Import Local Package`
* Navigate to the `DmrVBM_GameMaker.yymps` file. Select the file and click `Open`
* Choose *scr_vbm* to import into the project
* NOTE: To avoid conflicts when upgrading to v1.3, remove existing v1.2 scripts before importing.

### Supported Attributes
- Position - Location of vertex.
- UV - Texture coordinate per loop. 
- Normal - Surface orientation of vertex
- Tangent - Vector perpendicular to the normal.
- Bitangent - Cross product of normal and tangent.
- Color - Vertex colors as floats.
- Color Bytes - Vertex colors as 4 bytes
- Bone Indices - Index of bone from deform vertex groups.
- Bone Index Bytes - Above as 4 bytes
- Weights - Weight from deform vertex groups.
- Weight Bytes - Above as 4 bytes
- Vertex Group - Vertex weight value from named vertex group.  

Game Maker's default format is [Position, Color Bytes, UV]

-----------------------------------------------------------------------------------------------

![Addon Panels](https://github.com/Sandman13sq/DmrVBM-blender-to-gms2/blob/main/images/addon.png)

-----------------------------------------------------------------------------------------------

# CHANGELOG

## v1.3 BETA December 2023 Update
- Blender Addon
	- Addon code condensed to single script
	- Merged VBM and TRK format into one filetype
		- VBM files now contain mesh, skeleton, and action data
		- TRK files are no longer a thing
	- Overhauled UI
		- All export types (.vb, .vbm, .trk, batched) combined into one operator
		- More customization options for exports
	- Optimizations for repeat exports
		- Star button repeats last export of selected object in one click
		- VB data is cached to object when exporting, so repeat exports with same parameters don't recalculate same data
		- Baked actions are reused if source action data is not changed
- GMS2 Scripts
	- Merged VBM and TRK struct into single struct
		- VBM data is now stored in one VBM_Model struct
		- Struct contains meshes (vertex buffers), bone data, and animations
		- VBM struct has an animator used for animating poses and curves
	- Single script used for VBM functions
		- Extra math functions omitted from package
	- Tutorial project rewritten to reflect new changes

- Other
	- Current mascot is now Treat - A pumpkin witch.

## v1.2 December 2022 Update
- VBM Export Addon
	- New option to export Padding Floats and Bytes. Use to set a constant value for an attribute.
	- Formats are now in a list that can be defined outside of the export dialog.
	- Deform Only option creates a temporary armature with bones' parents re-evaluated, so exports are compatible with complex rigs (Rigify).
- TRK Export Addon
	- Code redone so that exporting actions no longer require a bake. Export times are faster as a result.
	- Deform Only option creates a temporary armature with bones' parents re-evaluated, so exports are compatible with complex rigs (Rigify).
	- Custom Property Curves on the armature object can now be exported to TRK.
	- New Bone List structure to mark which bones to export by name.
		- Include mode only exports bones in list
		- Exclude mode ignores bones in list from export.
- VBM Game Maker Scripts
	- Fixed compression header check.
- TRK Game Maker Scripts
	- Fixed compression header check.
	- New TRK Animator struct used for TRK animation.
- General
	- Current mascot is now Starcie. Space Karate Girl.
	- Reorganized addon files.
	- Data specific to the addon (vertex formats, export lists, bone lists) is now stored in the Blender Scene.
		- VBM Formats are accessed with `context.scene.vbm.formats`
		- VBM Export Lists are accessed with `context.scene.vbm.export_lists`
		- TRK Bone Lists are accessed with `context.scene.trk.bone_lists`

## v1.1 June 2022 Update
- VBM Export Addon
	- New option to export Vertex Group weights (armature not necessary) with default weight value.
	- Number of floats to export can be adjusted for Position, Color, Bone, and Weight attributes.
	- Optimized export code.
- TRK Export Addon
	- New option to only export frames that contain markers.
- VBM Game Maker Scripts
	- Added methods and functions to VBMData struct for accessing struct data.
	- Opening VB and VBM files checks for compression headers.
- TRK Game Maker Scripts
	- Added methods and functions to TRKData struct for accessing struct data.
	- Opening TRK files checks for compression headers.
- General
	- Updated vbm_tutorials with Blender-like camera controls and 3 new shader examples.
		- Outline: Makes use of exported weights from a Vertex Group for model outline position
		- Normal Map: Uses tangent and bitangent data to calculate normals from a texture.
		- PRM: A shader setup similar to games like Smash Ultimate. Makes use of several textures for styled shading.
	- Removed vbm_demo

## v1.0
- Initial Release
