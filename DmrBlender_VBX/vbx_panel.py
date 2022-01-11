import bpy

classlist = []

def DrawVBXPanel(self, context):
    layout = self.layout
       
    section = layout.box().column()
    section.column().label(text='-- Vertex Buffer --')
    section = section.row()
    section.operator("dmr.gm_export_vb", text='Export VB', icon='OBJECT_DATA')
    section.operator("dmr.gm_export_vbx", text='Export VBX', icon='MOD_ARRAY')
    
    section = layout.box().column()
    section.column().label(text='-- Animations --')
    #section.operator("dmr.gm_export_pose", text='Export Current Pose', icon='ARMATURE_DATA')
    #section.operator("dmr.gm_export_poselib", text='Export PoseLib', icon='POSE_HLT')
    section.operator("dmr.gm_export_action", text='Export Action', icon='RENDER_ANIMATION')
    section.operator("dmr.gm_export_posematrix", text='Export Pose Matrices', icon='LIGHTPROBE_GRID')
'''
class DMR_PT_ExportVBPanel(bpy.types.Panel):
    bl_label = 'Vertex Buffer Export'
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'VB'
    draw = DrawVBXPanel
classlist.append(DMR_PT_ExportVBPanel)
'''
class DMR_PT_ExportVBPanel_Scene(bpy.types.Panel):
    bl_label = 'Vertex Buffer Export'
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = 'scene'
    draw = DrawVBXPanel
classlist.append(DMR_PT_ExportVBPanel_Scene)

# ==================================================================

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in reversed(classlist):
        bpy.utils.unregister_class(c)
