import bpy

classlist = [];

class DMR_ExportVBPanel(bpy.types.Panel):
    """Creates a Panel in the Object properties window"""
    bl_label = "Vertex Buffer Export"
    bl_idname = "DMR_PT_VBEXPORT"
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = "VB" # Name of sidebar
    
    def draw(self, context):
        layout = self.layout;
        
        section = layout.box().column();
        section.column().label(text='-- Vertex Buffer --');
        section = section.row();
        section.operator("dmr.gm_export_vb", text='Export VB', icon='OBJECT_DATA');
        section.operator("dmr.gm_export_vbx", text='Export VBX', icon='MOD_ARRAY');
        
        section = layout.box().column();
        section.column().label(text='-- Animations --');
        #section.operator("dmr.gm_export_pose", text='Export Current Pose', icon='ARMATURE_DATA');
        #section.operator("dmr.gm_export_poselib", text='Export PoseLib', icon='POSE_HLT');
        section.operator("dmr.gm_export_action", text='Export Action', icon='RENDER_ANIMATION');
        section.operator("dmr.gm_export_posematrix", text='Export Pose Matrices', icon='LIGHTPROBE_GRID');
        
        section = layout.box();
        section.column().label(text='-- Anim Exportables --');
        scene = context.scene;
		
classlist.append(DMR_ExportVBPanel);

class dmr_exportanimationslist(bpy.types.PropertyGroup):
    name : bpy.props.StringProperty();
    active : bpy.props.BoolProperty();
classlist.append(dmr_exportanimationslist);

def register():
    for c in classlist:
        bpy.utils.register_class(c);
    #bpy.types.Scene.dmr_exportanimationslist = bpy.props.CollectionProperty(type = dmr_exportanimationslist);

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)
