![Repo Banner](https://github.com/Dreamer13sq/DmrVBM-blender-to-gms2/blob/main/images/banner.png)

# Vertex Buffer Model Exporter by Dreamer13sq
### Import/Export tools for loading .vb and .vbm vertex buffer data out of Blender and in to Game Maker Studio 2
#### .vb is Game Maker Studio's **vertex buffer data** format used in functions like `vertex_submit()`.
#### .vbm is a custom file format for exporting **multiple meshes** with extra metadata.  
#### .trk is a custom file format for exporting action animation data from Blender.

NOTE: If cloned straight from GitHub not all features are guranteed to work correctly.  
For stable versions see the **Releases** on the GitHub page (when they're ready).

The example model's character is of Curly Brace from Cave Story. I own nothing related to Cave Story.

# [Quick Start Guide](https://github.com/Dreamer13sq/DmrVBM-blender-to-gms2/wiki/Quick-Start-Guide)

-----
  
## Blender 3.x Addon Installation
* In Blender, go to `Edit` > `Preferences` > `Add-ons`
* Click `Install` on the top right of the Preferences window
* Navigate to the `DmrBlender_VBM.zip` file (keep this zipped). Select it and click `Install Add-on`
* Enable the `DmrBlender VBM Export` addon
* The VBM export panel can be found in the `Properties` > `Scene`
     * If nothing shows up try `Edit` > `Preferences` > `Interface` > `Display` > Enable `Developer Extras`

## Game Maker Studio 2 Installation
* With a GMS2 project open, go to `Tools` > `Import Local Package`
* Navigate to the `DmrVBM.yymps` file. Select the file and click `Open`
* Choose which scripts to import into the project
    * *scr_dmr_vbm* is written to be independent of any other script. The other scripts use elements from all scripts.

=================================================================================================

# CHANGELOG

## v1.1 June Update
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
	- Updated vbm_tutorials with 3 new examples and better camera.
	- Removed vbm_demo

## v1.0
- Initial Release
