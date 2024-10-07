![Repo Banner](https://github.com/Sandman13sq/DmrVBM-blender-to-gms2/blob/main/images/banner.png)

# Vertex Buffer Model Exporter and Importer by Sandman13sq
### Import/Export tools for loading vertex buffer data out of Blender and in to GameMaker.

#### .vb is GameMaker's **vertex buffer data** format used for `vertex_submit()`.
#### .vbm is a custom file format for exporting mesh data, skeleton bones, and action curves. 

NOTE: If cloned straight from GitHub not all features are guranteed to work correctly.  
For stable versions see the **Releases** on the GitHub page.

Support me on: [Patreon](https://www.patreon.com/sandman13sq) | [Ko-fi](https://ko-fi.com/sandman13sq)

![Preview](https://github.com/Sandman13sq/DmrVBM-blender-to-gms2/blob/main/images/preview.gif)

# [Quick Start Guide](https://github.com/Sandman13sq/DmrVBM-blender-to-gms2/wiki/Quick-Start-Guide)

-----

## Blender 4.x Addon Installation
* In Blender, go to `Edit` > `Preferences` > `Add-ons`
* Click `Install` on the top right of the Preferences window
* Navigate to the `DmrVBM_Blender.zip` file (keep this zipped). Select it and click `Install Add-on`
* Enable the `DmrVBM Vertex Buffer Model Export` addon
* The VBM export panel can be found in the `Properties` > `Scene`
     * If nothing shows up try `Edit` > `Preferences` > `Interface` > `Display` > Enable `Developer Extras`

## GameMaker Installation
* With a GameMaker project open, go to `Tools` > `Import Local Package`
* Navigate to the `DmrVBM_GameMaker.yymps` file. Select the file and click `Open`
* Choose *scr_dmrvbm* to import into the project
* NOTE: To avoid conflicts when upgrading to v1.4, remove existing DmrVBM scripts before importing.
* NOTE again: v1.4 is NOT backwards compatible with v1.3 models or below. Old models will have to be re-exported.

# FEATURES
### Blender Addon
- Mesh exports
	- Design vertex format attributes to export model with.
		- Position - Location of vertex.
		- UV - Texture coordinate per loop. 
		- Normal - Surface orientation of vertex
		- Tangent - Vector perpendicular to the normal.
		- Bitangent - Cross product of normal and tangent.
		- Color - Vertex colors as Linear or sRGB values.
		- Bone Indices - Index of bone from deform vertex groups.
		- Weights - Weight from deform vertex groups.
		- Group Value - Vertex weight value from named vertex group.
		- Padding - A constant value for all vertices
	- Attributes can be set to export as floats or bytes
	- Pack textures from materials into files.
	- Override materials on export.
- Skeleton exports
	- Choose to export deform only bones
	- Mask out bones for export to reduce bone count
	- Set dynamic bone settings for things like hair/clothing, etc.
- Animation exports
	- Mask out bones to export curves for.
- Queues
	- Design a custom export queue with specific object order.
	- Exports can be repeated in a single click via the Star button.

### Game Maker Package
- No-fuss Rendering
	- Rendering models takes very few steps. 
		- Load model from file > evaluate animation > set matrices > submit model
	- Data relevant to model is stored with model, including vertex format and textures.

Game Maker's native format is [Position 3f, Color 4B, UV 2f]

-----------------------------------------------------------------------------------------------

![Addon Panels](https://github.com/Sandman13sq/DmrVBM-blender-to-gms2/blob/main/images/addon.png)

-----------------------------------------------------------------------------------------------

# FEATURE CHANGELOG

## v1.4-BETA
- Blender Addon
	- Rewritten from scratch focused on Blender 4.x support.
	- Attribute byte option moved to a boolean.
	- Queues have a checkout list for more customizable exports.
	- Bone mask option added to action exports.
	- Added option to replace materials during export.
	- Textures can now be packed into model file.
- GMS2 Package
	- Rewritten from scratch focused on data-driven style.
	- Added basic support for dynamic bone animation.

## v1.3.1 June 2024 Update
- Blender Addon
	- Updated to support Blender 4.1.x
	- Implemented exporting objects by material.
	- Added Bone Dissolve panel for omitting specific bones on export.
- GMS2 Scripts
	- New VBMModel methods for managing mesh visibility.
	- Animator can blend transforms from last animation to new animation.
	- Small animation optimizations and bugfixes.

## v1.3 January 2024 Update
- Blender Addon
	- Addon code condensed to single script
	- Merged VBM and TRK format into one filetype
		- VBM files now contain mesh, skeleton, and action data
		- TRK files are discontinued
		- VB files remain as raw vertex buffer data
	- New Export Queues Tab
		- Define a list of exports to re-export models with one click
		- Execute multiple file exports with one click
	- Overhauled UI
		- All export types (.vb, .vbm, .trk, batched) combined into one operator
		- More customization options for exports
	- Optimizations for repeat exports
		- Star button repeats last export of selected object in one click
		- VB data is cached to object when exporting, so repeat exports with same parameters don't recalculate unchanged data
		- Baked actions are reused if source action data is not changed
- GMS2 Scripts
	- Merged VBM and TRK struct into single struct
		- VBM data is now stored in one VBM_Model struct
		- Struct contains meshes (vertex buffers), bone data, and animations
		- VBM struct has an animator used for animating poses and curves
	- Single script used for VBM functionality
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
