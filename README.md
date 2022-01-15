# DmrVBX by Dreamer13sq
### Import/Export tools for loading .vb and .vbx vertex buffer data out of Blender and in to Game Maker Studio 2.3

#### NOTE: If cloned straight from GitHub not all features are guranteed to work correctly.  
#### For stable versions see the **Releases** on the GitHub page (when they're ready).

-----
  
## Blender 3.0 Addon Installation
* In Blender, go to `Edit` > `Preferences` > `Add-ons`
* Click `Install` on the top right of the Preferences window
* Navigate to the `DmrBlender_VBX.zip` file (keep this zipped). Select it and click `Install Add-on`
* Enable the `DmrBlender VBX Export` addon
* The VBX export panel can be found in the `Properties` > `Scene`
     * If nothing shows up try `Edit` > `Preferences` > `Interface` > `Display` > Enable `Developer Extras`

## Game Maker Studio 2 Installation
* With a GMS2 project open, go to `Tools` > `Import Local Package`
* Navigate to the `dmr_vbx.yymps` file. Select the file and click `Open`
* Choose which scripts to import into the project
    * *scr_dmr_vbx* is written to be independent of any other script.  The other scripts use elements from all scripts.

