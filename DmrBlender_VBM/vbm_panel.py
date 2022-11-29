import bpy

classlist = []

def DrawVBMPanel(self, context):
    layout = self.layout
    
    section = layout.box().column()
    section.column().label(text='-- Vertex Buffer --')
    section = section.row()
    section.operator("vbm.export_vb", text='Export VB', icon='OBJECT_DATA')
    section.operator("vbm.export_vbm", text='Export VBM', icon='MOD_ARRAY')
    
    section = layout.box().column()
    section.column().label(text='-- Animations --')
    
    r = section.row()
    r.operator("vbm.export_trk", text='Export TRK', icon='ACTION')
    bb = section.box()
    last = context.scene.get('LastTRKExport', None)
    bb.enabled = last != None
    op = bb.operator("vbm.export_trk_repeat", text=('...'+last['filepath'][-32:]) if last != None else 'Repeat Last', icon='FILE_REFRESH')

# ---------------------------------------------------------------------------------

class VBM_PT_ExportVBPanel_Scene(bpy.types.Panel):
    bl_label = 'VBM / TRK Export'
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = 'scene'
    draw = DrawVBMPanel
classlist.append(VBM_PT_ExportVBPanel_Scene)

# ==================================================================

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in reversed(classlist):
        bpy.utils.unregister_class(c)
