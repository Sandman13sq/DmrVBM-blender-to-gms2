import bpy

# Include
try:
    from .vbm_utils import *
except:
    from vbm_utils import *

classlist = []

'# =========================================================================================================================='
'# PROPERTY GROUPS'
'# =========================================================================================================================='

class VBM_ExportList_Entry(bpy.types.PropertyGroup):
    def UpdateObjectName(self, context):
        if self.name in [obj.name for obj in bpy.data.objects]:
            self.name = self.object.name
    
    def UpdateEntryName(self, context):
        if self.name == "":
            self.name = self.object.name
    
    name : bpy.props.StringProperty(name='Object Name', default="", update=UpdateEntryName)
    object : bpy.props.PointerProperty(type=bpy.types.Object, update=UpdateEntryName)
classlist.append(VBM_ExportList_Entry)

# ---------------------------------------------------------------------------

class VBM_ExportList_Objects(DMR_ItemGroup_Super, bpy.types.PropertyGroup):
    items : bpy.props.CollectionProperty(type=VBM_ExportList_Entry)
    
    op_from_selected : bpy.props.BoolProperty(
        name="Add Selected Objects To List",
        description="Add selected objects to list",
        default=False,
        update=lambda s,c: s.UpdateSuper(c)
        )
    
    op_flush : bpy.props.BoolProperty(
        name="Flush Items",
        description="Remove entries with invalid objects",
        default=False,
        update=lambda s,c: s.UpdateSuper(c)
        )
    
    def CopyFrom(self, other):
        for e in other.items:
            self.Add(e.object)
    
    def GetObjects(self):
        return [x.object for x in self.items]
    
    def Add(self, object, allow_duplicates=False):
        if allow_duplicates or object not in [x.object for x in self.items]:
            e = self.items.add()
            e.object = object
            self.size = len(self.items)
            self.item_index = self.size-1
    
    def Sort(self, type='NAME', reverse=False):
        sorted = False
        blenddataobjects = [obj.name for obj in bpy.data.objects]
        vertexcounts = {obj: len(obj.data.vertices) if obj.type == 'MESH' else 0 for obj in bpy.data.objects}
        
        while not sorted:
            sorted = True
            # By Name
            if type == 'NAME':
                for i, item1 in enumerate(self.items[:-1]):
                    item2 = self.items[i+1]
                    if (item2.name < item1.name) if not reverse else (item2.name > item1.name):
                        self.items.move(i, i+1)
                        sorted = False
            # By Name
            elif type == 'MATERIAL':
                for i, item1 in enumerate(self.items[:-1]):
                    item2 = self.items[i+1]
                    if (item2.name < item1.name) if not reverse else (item2.name > item1.name):
                        self.items.move(i, i+1)
                        sorted = False
            # By Data Index
            elif type == 'DATA':
                for i, item1 in enumerate(self.items[:-1]):
                    item2 = self.items[i+1]
                    if item1.object == None or (
                        (blenddataobjects.index(item2.object.name) < blenddataobjects.index(item1.object.name)) if not reverse else
                        (blenddataobjects.index(item2.object.name) > blenddataobjects.index(item1.object.name))
                        ):
                        self.items.move(i, i+1)
                        sorted = False
            # By Size
            elif type == 'SIZE':
                for i, item1 in enumerate(self.items[:-1]):
                    item2 = self.items[i+1]
                    if item1.object == None or (
                        (vertexcounts[item2.object] < vertexcounts[item1.object]) if not reverse else
                        (vertexcounts[item2.object] > vertexcounts[item1.object])
                        ):
                        self.items.move(i, i+1)
                        sorted = False
    
    def Flush(self):
        noneitems = [item for item in self.items if item.object == None]
        [self.items.remove(list(self.items).index(item)) for item in noneitems[::-1]]
        self.size = len(self.items)
        self.item_index = max(0, min(self.item_index, self.size-1))
        
    def Clear(self):
        while len(self.items) > 0:
            self.items.remove(0)
        
        self.size = len(self.items)
        self.item_index = max(0, min(self.item_index, self.size-1))
    
    def Update(self, context):
        if self.op_from_selected:
            self.op_from_selected = False
            for obj in context.selected_objects:
                self.Add(obj, False)
        
        if self.op_flush:
            self.op_flush = False
            self.Flush()
    
    def DrawPanel(self, context, layout, rows=4):
        # Item List
        r = layout.row()
        c = r.column(align=1)
        c.template_list(
            "VBM_UL_ExportList_Entry", "", 
            self, "items", 
            self, "item_index", 
            rows=rows)
        
        # List Control
        c = r.column(align=1)
        c.prop(self, 'reset_mutex', text="", icon='FILE_REFRESH')
        c.separator()
        c.prop(self, 'op_add_item', text="", icon='ADD')
        c.prop(self, 'op_remove_item', text="", icon='REMOVE')
        c.separator()
        c.prop(self, 'op_move_up', text="", icon='TRIA_UP')
        c.prop(self, 'op_move_down', text="", icon='TRIA_DOWN')
        
        return c
classlist.append(VBM_ExportList_Objects)

# ---------------------------------------------------------------------------

class VBM_ExportList_List(DMR_ItemGroup_Super, bpy.types.PropertyGroup):
    items : bpy.props.CollectionProperty(type=VBM_ExportList_Objects)
    
    def Add(self):
        item = self.items.add()
        self.size += 1
        item.name = "New Export List"
        return item
    
    def Update(self, context):
        # Add
        if self.op_add_item:
            self.op_add_item = False
            if self.size > 0:
                self.Add().CopyFromOther(self.GetActive())
            else:
                self.Add()
            self.item_index = self.size-1
    
    def DrawPanel(self, context, layout, rows=4):
        # List Items
        r = layout.row()
        c = r.column(align=1)
        c.template_list(
            "VBM_UL_ExportList_Objects", "", 
            self, "items", 
            self, "item_index", 
            rows=rows)
        
        # List Control
        c = r.column(align=1)
        c.prop(self, 'reset_mutex', text="", icon='FILE_REFRESH')
        c.separator()
        c.prop(self, 'op_add_item', text="", icon='ADD')
        c.prop(self, 'op_remove_item', text="", icon='REMOVE')
        c.separator()
        c.prop(self, 'op_move_up', text="", icon='TRIA_UP')
        c.prop(self, 'op_move_down', text="", icon='TRIA_DOWN')
        
        return c
classlist.append(VBM_ExportList_List)

'# =========================================================================================================================='
'# OPERATORS'
'# =========================================================================================================================='

class VBM_OT_ExportList_Sort(bpy.types.Operator):
    bl_idname = "vbm.exportlist_entry_sort"
    bl_label = "Sort Export List Entries"
    bl_description = "Sorts entries by given type"
    bl_options = {'REGISTER', 'UNDO'}
    
    type : bpy.props.EnumProperty(
        name="Sorting Type",
        description='Direction to move layer',
        items=(
            ('NAME', 'By Name', 'Sort by name'),
            ('DATA', 'By Internal Index', 'Sort by position in blender data'),
            ('SIZE', 'By Size', 'Sort by number of vertices'),
            ('MATERIAL', 'By Material Name', 'Sort by material'),
        )
    )
    
    reverse : bpy.props.BoolProperty(
        name="Reverse",
        default=False
    )
    
    @classmethod
    def poll(self, context):
        return context.scene.vbm.export_lists.GetActive()
    
    def invoke(self, context, event):
        return context.window_manager.invoke_props_dialog(self)
    
    def execute(self, context):
        context.scene.vbm.export_lists.GetActive().Sort(self.type, self.reverse)
        
        return {'FINISHED'}
classlist.append(VBM_OT_ExportList_Sort)

'# =========================================================================================================================='
'# UI LIST'
'# =========================================================================================================================='

class VBM_UL_ExportList_Entry(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=0)
        
        rr = r.row()
        rr.scale_x = 0.4
        rr.label(text='[%d]' % index)
        
        #r.prop(item, "name", text="")
        
        if item.object != None:
            r.prop(item, "object", text="", icon=item.object.type+'_DATA')
        else:
            r.prop(item, "object", text="", icon='QUESTION')
classlist.append(VBM_UL_ExportList_Entry)

# ------------------------------------------------------------------------------------
class VBM_UL_ExportList_Objects(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=1)
        
        r.prop(item, 'name', text="", emboss=False)
        
        r.separator()
        
        rr = r.row(align=1)
        op = rr.operator("vbm.export_vb", text='', icon='OBJECT_DATA')
        op.export_list = item.name
        op.collection = ""
        op = rr.operator("vbm.export_vbm", text='', icon='MOD_ARRAY')
        op.export_list = item.name
        op.collection = ""
classlist.append(VBM_UL_ExportList_Objects)

'# =========================================================================================================================='
'# REGISTER'
'# =========================================================================================================================='

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in classlist[::-1]:
        bpy.utils.unregister_class(c)


