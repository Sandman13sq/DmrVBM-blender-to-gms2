import bpy

Items_BoneSetSettings = (
    ('EXCLUDE', 'Exclude', 'Bones in list will be excluded form export'),
    ('INCLUDE', 'Include', 'Only bones in list will be included in export'),
)

classlist = []

'# =========================================================================================================================='
'# PROPERTY GROUPS'
'# =========================================================================================================================='

class DMR_ItemGroup_Super(bpy.types.PropertyGroup):
    def UpdateActive(self, context):
        self.active = self.items[self.item_index] if self.size > 0 else None
        print(self.active)
    
    name : bpy.props.StringProperty(name="Name", default="New Item")
    size : bpy.props.IntProperty()
    #items : bpy.props.CollectionProperty(type=TRK_BoneSettings_Bone)
    item_index : bpy.props.IntProperty(
        name="Item Index",
        description="Index of current item in list",
        update=UpdateActive
        )
    
    update_mutex : bpy.props.BoolProperty(default=False)
    
    def __init__(self):
        self.active = None
    
    def __getitem__(self, index_or_key):
        return self.FindItem(index_or_key) if isinstance(index_or_key, str) else self.items[index_or_key]
    
    def __setitem__(self, index_or_key, value):
        return self.Set(index_or_key) if isinstance(index_or_key, str) else self.items[index_or_key]
    
    def GetActive(self):
        return self.items[self.item_index] if self.size > 0 else None
    
    def GetItem(self, index):
        return self.items[index] if self.size else None 
    
    def GetItems(self):
        return [x for x in self.items]
    
    def FindItem(self, name, default_value=None):
        return ([x for x in self.items if x.name == name]+[default_value])[0]
    
    def CopyFromOther(self, other):
        self.items.clear()
        self.size = 0
        
        for otheritem in other.items:
            self.Add().CopyFromOther(otheritem)
        return self
    
    def Define(self, name):
        item = self.FindItem(name, None)
        if not item:
            item = self.Add()
        return item
    
    def RemoveAt(self, index):
        if len(self.items) > 0:
            self.items.remove(index)
            self.size -= 1
            
            self.item_index = max(min(self.item_index, self.size-1), 0)
    
    def MoveItem(self, index, move_down=True):
        newindex = index + (1 if move_down else -1)
        self.items.move(index, newindex)
    
    def UpdateSuper(self, context):
        if self.update_mutex:
            return
            
        self.update_mutex = True
        
        # Remove
        if self.op_remove_item:
            self.op_remove_item = False
            self.RemoveAt(self.item_index)
        
        # Move
        if self.op_move_down:
            self.op_move_down = False
            self.items.move(self.item_index, self.item_index+1)
            self.item_index = max(min(self.item_index+1, self.size-1), 0)
        
        if self.op_move_up:
            self.op_move_up = False
            self.items.move(self.item_index, self.item_index-1)
            self.item_index = max(min(self.item_index-1, self.size-1), 0)
        
        self.Update(context)
        
        self.update_mutex = False
    
    def Update(self, context):
        return
    
    def ResetMutex(self, context):
        if self.reset_mutex:
            self.reset_mutex = False
            self._ResetMutex()
    
    def _ResetMutex(self):
        self.update_mutex = False
        for item in self.items:
            if hasattr(item, '_ResetMutex'):
                item._ResetMutex()
        for att in dir(self):
            if att[:3] == "op_":
                setattr(self, att, False)
    
    op_add_item : bpy.props.BoolProperty(default=False, update=UpdateSuper)
    op_remove_item : bpy.props.BoolProperty(default=False, update=UpdateSuper)
    op_move_up : bpy.props.BoolProperty(default=False, update=UpdateSuper)
    op_move_down : bpy.props.BoolProperty(default=False, update=UpdateSuper)
    
    reset_mutex : bpy.props.BoolProperty(
        name="Reset Mutex",
        description="Resets mutex values for all items. Use if buttons get \"stuck\".",
        default=False, 
        update=ResetMutex
        )

# ------------------------------------------------------------------------------------

class TRK_BoneSettings_String(bpy.types.PropertyGroup):
    name : bpy.props.StringProperty(name="Name")
classlist.append(TRK_BoneSettings_String)

# ------------------------------------------------------------------------------------

class TRK_BoneSettings_Bone(bpy.types.PropertyGroup):
    name : bpy.props.StringProperty(
        name="Bone Name", 
        description="Name of bone", 
        default="",
        )
    
    enabled : bpy.props.BoolProperty(
        name="Enabled",
        description="Entry will be checked when finding bones to export",
        default=True
        )
    
    def CopyFromOther(self, other):
        self.name = other.name
        self.enabled = other.enabled
        return self
classlist.append(TRK_BoneSettings_Bone)

# ------------------------------------------------------------------------------------

class TRK_BoneSettings(DMR_ItemGroup_Super, bpy.types.PropertyGroup):
    items : bpy.props.CollectionProperty(type=TRK_BoneSettings_Bone)
    type : bpy.props.EnumProperty(name="List Type", items=Items_BoneSetSettings)
    case_sensitive : bpy.props.BoolProperty(default=True)
    deform_only : bpy.props.BoolProperty(
        name="Deform Only",
        description="Export bones with the 'use_deform' property enabled",
        default=True,
        )
    selected_only : bpy.props.BoolProperty(
        name="Selected Only",
        description="Export bones that have been selected in pose mode",
        default=False,
        )
    
    op_bones_from_selected : bpy.props.BoolProperty(
        name="Add Selected Bones To List",
        description="Add selected bones to list",
        default=False,
        update=lambda s,c: s.UpdateSuper(c)
        )
    
    def ParseExportBoneNames(self, armatureobj):
        targetnames = [x.name for x in self.items if x.enabled]
        if self.type == 'INCLUDE':
            return [b.name for b in armatureobj.data.bones if b.name in targetnames]
        elif self.type == 'EXLCUDE':
            return [b.name for b in armatureobj.data.bones if b.name not in targetnames]
    
    def Serialize(self):
        return [item.name for item in self.GetItems()]
    
    def Unserialize(self, values):
        self.items.clear()
        self.size = 0
        
        for name in values:
            self.Add(name)
    
    def Add(self, name=""):
        item = self.items.add()
        self.size += 1
        item.name = name
        return item
    
    def Update(self, context):
        # Add
        if self.op_add_item:
            if self.size > 0:
                self.Add().CopyFromOther(self.GetActive())
            else:
                self.Add()
            
            self.item_index = self.size-1
            self.op_add_item = False
        
        # From Selected
        if self.op_bones_from_selected:
            if context.object.type == 'ARMATURE':
                usednames = [x.name for x in self.items]
                for b in context.object.data.bones:
                    if b.select and b.name not in usednames:
                        self.Add().name = b.name
            
            self.op_bones_from_selected = False
            
    
    def DrawPanel(self, context, layout, rows=6):
        row = layout.row()
        
        c = row.column(align=1)
        r = c.row()
        r.label(text=self.name)
        r.prop(self, 'type', text="", toggle=True)
        r.prop(context.scene.trk, 'op_refresh_strings', text="Refresh Property Lists", toggle=True)
        
        r = c.row()
        r.prop(self, 'deform_only', icon='MOD_SIMPLEDEFORM')
        r.prop(self, 'selected_only', icon='RESTRICT_SELECT_OFF')
        
        # List Items
        r = layout.row()
        c = r.column(align=1)
        c.template_list(
            "TRK_UL_BoneSettings_Items", "", 
            self, "items", 
            self, "item_index", 
            rows=rows)
        
        # List Control
        c = r.column(align=1)
        c.prop(self, 'op_add_item', text="", icon='ADD')
        c.prop(self, 'op_remove_item', text="", icon='REMOVE')
        c.separator()
        c.prop(self, 'op_move_up', text="", icon='TRIA_UP')
        c.prop(self, 'op_move_down', text="", icon='TRIA_DOWN')
        
        return c
classlist.append(TRK_BoneSettings)

# ------------------------------------------------------------------------------------

class TRK_BoneSettingsList(DMR_ItemGroup_Super, bpy.types.PropertyGroup):
    items : bpy.props.CollectionProperty(type=TRK_BoneSettings)
    
    def Add(self):
        item = self.items.add()
        self.size += 1
        item.name = "New Settings"
        return item
    
    def Update(self, context):
        # Add
        if self.op_add_item:
            if self.size > 0:
                self.Add().CopyFromOther(self.GetActive())
            else:
                self.Add()
            
            self.item_index = self.size-1
            self.op_add_item = False
    
    def DrawPanel(self, context, layout, rows=4):
        # Item List
        r = layout.row()
        c = r.column(align=1)
        c.template_list(
            "TRK_UL_BoneSettings", "", 
            self, "items", 
            self, "item_index", 
            rows=5)
        
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
classlist.append(TRK_BoneSettingsList)

'# =========================================================================================================================='
'# UI LISTS'
'# =========================================================================================================================='

class TRK_UL_BoneSettings_Items(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        c = layout.column(align=1)
        
        master = context.scene.trk
        
        # Attribute Type and Size
        r = c.row(align=1)
        r.prop_search(item, 'name', master, 'bonenames', text='Bone')
classlist.append(TRK_UL_BoneSettings_Items)

# ------------------------------------------------------------------------------------

class TRK_UL_BoneSettings(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=1)
        
        r.prop(item, 'name', text="", emboss=False)
        rr = r.row(align=1)
        rr.scale_x = 0.9
        
        r.separator()
        
        r.prop(item, 'type', text="", toggle=True)
        r.prop(item, 'deform_only', text="", toggle=True, icon='MOD_SIMPLEDEFORM')
        r.prop(item, 'selected_only', text="", toggle=True, icon='RESTRICT_SELECT_OFF')
        
        rr = r.column(align=1)
        rr.scale_y = 0.5
        
        r.separator()
        
        rr = r.row(align=1)
        rr.operator("trk.export_trk", text='', icon='ACTION').bone_settings = item.name
classlist.append(TRK_UL_BoneSettings)

'# =========================================================================================================================='
'# OPERATORS'
'# =========================================================================================================================='

class TRK_OT_AddSelectedToBoneSettings(bpy.types.Operator):
    bl_idname = "vbm.trk_bonesettings_add_selected_bones"
    bl_label = "Add Selected Bones to Active Bone Settings"
    bl_description = "Adds Selected Bones to Active Bone Settings"
    bl_options = {'REGISTER', 'UNDO'}
    
    @classmethod
    def poll(self, context):
        return context.active_object and context.active_object.type == 'ARMATURE' and context.scene.trk.bone_settings.GetActive()
    
    def execute(self, context):
        obj = context.active_object
        
        if obj.mode == 'EDIT':
            bones = obj.data.edit_bones
        else:
            bones = obj.data.bones
        
        bonesettings = context.scene.trk.bone_settings.GetActive()
        usednames = [x.name for x in bonesettings.items]
        for b in bones:
            if b.select and not b.hide and b.name not in usednames:
                bonesettings.Add().name = b.name
        
        return {'FINISHED'}
classlist.append(TRK_OT_AddSelectedToBoneSettings)

'# =========================================================================================================================='
'# REGISTER'
'# =========================================================================================================================='

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in classlist[::-1]:
        bpy.utils.unregister_class(c)


    
