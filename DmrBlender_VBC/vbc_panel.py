import bpy

classlist = []

def DrawVBCPanel(self, context):
    layout = self.layout
    
    section = layout.box().column()
    section.column().label(text='-- Vertex Buffer --')
    section = section.row()
    section.operator("dmr.vbc_export_vb", text='Export VB', icon='OBJECT_DATA')
    section.operator("dmr.vbc_export_vbc", text='Export VBC', icon='MOD_ARRAY')
    
    section = layout.box().column()
    section.column().label(text='-- Animations --')
    #section.operator("dmr.vbc_export_action_matrices", text='Export Armature Matrices', icon='CON_TRANSFORM_CACHE')
    section.operator("dmr.vbc_export_action_tracks", text='Export Armature Tracks', icon='ACTION')
'''
class DMR_PT_ExportVBPanel(bpy.types.Panel):
    bl_label = 'Vertex Buffer Export'
    bl_space_type = 'VIEW_3D'
    bl_region_type = 'UI'
    bl_category = 'VB'
    draw = DrawVBCPanel
classlist.append(DMR_PT_ExportVBPanel)
'''
class DMR_PT_ExportVBPanel_Scene(bpy.types.Panel):
    bl_label = 'Vertex Buffer Export'
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = 'scene'
    draw = DrawVBCPanel
classlist.append(DMR_PT_ExportVBPanel_Scene)

# ==================================================================

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in reversed(classlist):
        bpy.utils.unregister_class(c)
