![Repo Banner](https://github.com/Sandman13sq/DmrVBM-blender-to-gms2/blob/main/images/banner.png)

# Vertex Buffer Model Exporter and Importer by Sandman13sq
### Import/Export tools for loading vertex buffer data out of Blender and in to GameMaker.

#### .vbm is a custom file format for exporting mesh data, skeleton bones, and action curves. 

NOTE: If cloned straight from GitHub not all features are guranteed to work correctly.  
For stable versions see the **Releases** on the GitHub page.

Support me on: [Patreon](https://www.patreon.com/sandman13sq) | [Ko-fi](https://ko-fi.com/sandman13sq)  
Ask questions or share your work on: [Twitter/X](https://twitter.com/Sandman13sq) | Discord (`#Sandman13sq6376`)

![Preview](https://github.com/Sandman13sq/DmrVBM-blender-to-gms2/blob/main/images/preview.gif)

# [Quick Start Guide (Not updated for v1.5)](https://github.com/Sandman13sq/DmrVBM-blender-to-gms2/wiki/Quick-Start-Guide)

-----

## Blender 4.5 Addon Installation
* In Blender, go to `Edit` > `Preferences` > `Add-ons`
* Click the dropdown arrow on the top right of the Preferences window and click `Install from Disk..`
* Navigate to the `DmrVBM_Blender.zip` file (keep this zipped). Select it and click `Install Add-on`
* Enabled the `DmrVBM` addon by clicking the checkbox (if not done already.)
* The DmrVBM panel can be found in the `Properties` > `Scene`
     * If nothing shows up try `Edit` > `Preferences` > `Interface` > `Display` > Enable `Developer Extras`

## GameMaker Installation
* With a GameMaker project open, go to `Tools` > `Import Local Package`
* Navigate to the `DmrVBM_GameMaker.yymps` file. Select the file and click `Open`
* Choose *scr_dmrvbm* to import into the project
* NOTE: To avoid conflicts when upgrading to v1.5, remove existing DmrVBM scripts before importing.
* NOTE again: v1.5 is NOT backwards compatible with v1.4 models or below. Old models will have to be re-exported.

# FEATURES
### Blender Addon
- Collection-based workflow
	- Individual collections can be marked as files to export.
		- Each collection holds its own unique settings for the file it creates.
		- Running the export on a parent collection will export marked child collections as individual files.
		- Linked collections (like one containing a model) can be used to export model variants.
		- Non-marked collections have their objects read as part of the file.
- Vertex buffer exports
	- Vertex formats can be defined per collection out of a set of pre-defined attributes.
	- Attributes can be set to export as floats or bytes
	- Pack textures from materials into files.
	- Override materials on export.
	- Apply a python script before and/or after applying mesh modifiers.
- Skeleton exports
	- Bones marked as deform are exported.
	- Parameters for dynamic animation can be set with the Swing Bones panel.
	- Collections not containing an Armature object will treat each object as a bone instead.
- Animation exports
	- Mask out bones to export curves for.
	- Property animations on object are also included in animation.
- Collision geometry exports
	- Objects marked as collision will be exported as a list of triangle vertices for a Prism struct.
- Utilities
	- Pad edges of textures under the 'MTL' tab to fill empty space.

### Game Maker Package
- No-fuss Rendering
	- Rendering models takes very few steps.
		- Load model from file > Evaluate Animation > Set Matrices > Submit Model
	- Data relevant to model is stored with model, including vertex format and textures.
- DmrVBM Types
	- Model: Holds data needed to render vertex buffers with materials. Vertex buffer, format, and textures are stored here.
	- Meshdef: Defines the start and number of vertices in vertex buffer to render, as well as a material index.
	- Prism: Holds a list of triangles used for collision testing. Functions are provided to cast rays.
	- Material: Specifies texture index and gpu state for rendering.
	- Bone: Defines matrices for skeletal animation and vertex skinning. Represents object positions on non-character models.
	- Animation: Can be sampled to retrieve values from exported curves. Holds transform and property curves.

Game Maker's native format is [Position 3f, Color 4B, UV 2f]

-----------------------------------------------------------------------------------------------

![Addon Panels](https://github.com/Sandman13sq/DmrVBM-blender-to-gms2/blob/main/images/addon.png)

-----------------------------------------------------------------------------------------------

