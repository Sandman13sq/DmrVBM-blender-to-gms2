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

class VBM_StringItem(bpy.types.PropertyGroup):
    name : bpy.props.StringProperty(name="Name")
classlist.append(VBM_StringItem)

# ------------------------------------------------------------------------------------

class VBM_FormatDef_Attribute(bpy.types.PropertyGroup):
    type : bpy.props.EnumProperty(
        name="Attribute Type",
        description='Data to write for each vertex', 
        items=Items_VBF, 
        default=VBF_000,
        update=lambda s,c: s.Update(c, False, True)
        )
    
    size : bpy.props.IntProperty(
        name="Attribute Size", 
        description='Number of floats to write for this attribute.\n\nFor Position: 3 = XYZ, 2 = XY\nFor Colors, 4 = RGBA, 3 = RGB, 2 = RG, 1 = R', 
        min=1, max=4, default=4,
        update=lambda s,c: s.Update(c)
        )
    
    layer : bpy.props.StringProperty(
        name="Attribute Layer", 
        description='Specific Color or UV layer to reference. ', 
        default=LYR_GLOBAL,
        update=lambda s,c: s.Update(c)
        )
    
    convert_to_srgb : bpy.props.BoolProperty(
        name="Is SRGB", 
        description='Convert color values from linear to SRGB', 
        default=True
        )
    
    padding_floats : bpy.props.FloatVectorProperty(
        name="Padding",
        description="Constant values for this attribute",
        size=4,
        default=(1.0,1.0,1.0,1.0)
        )
    
    padding_bytes : bpy.props.IntVectorProperty(
        name="Padding Bytes",
        description="Constant values for this attribute",
        size=4,
        default=(255,255,255,255)
        )
    
    update_mutex : bpy.props.BoolProperty(default=False)
    
    def ToJson(self):
        return {
            "class": "attribute",
            "type": self.type,
            "size": self.size,
            "layer": self.layer,
            "convert_to_srgb": self.convert_to_srgb,
            "padding_floats": list(self.padding_floats),
            "padding_bytes": list(self.padding_bytes),
            }
    
    def FromJson(self, jsonitem):
        if jsonitem.get("class", "") == "attribute":
            self.type = jsonitem["type"]
            self.size = jsonitem["size"]
            self.layer = jsonitem["layer"]
            self.convert_to_srgb = jsonitem["convert_to_srgb"]
            self.padding_floats = jsonitem["padding_floats"]
            self.padding_bytes = jsonitem["padding_bytes"]
    
    def CopyFromOther(self, other):
        self.type = other.type
        self.size = other.size
        self.layer = other.layer
        self.convert_to_srgb = other.convert_to_srgb
        self.padding_floats = other.padding_floats
        self.padding_bytes = other.padding_bytes
        
        return self
    
    def GetByteSize(self):
        return self.size * 4 if self.type in VBFByteType else self.size
    
    def Update(self, context, process_enums=False, type_change=False):
        if self.update_mutex:
            return
        
        self.update_mutex = True
        
        self.name = self.type
        
        # Set Size
        if type_change:
            self.size = VBFSize[self.type]
            
        # Clamp Size
        else:
            self.size = min(self.size, VBFSize[self.type])
        
        self.update_mutex = False
    
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        c = layout.column(align=1)
        
        master = context.scene.vbm
        
        # Attribute Type and Size
        r = c.row(align=1)
        rr = r.row(align=1)
        rr.scale_x = 0.4
        rr.label(text="[%d]" % index)
        r.prop(item, 'type', text="")
        
        if item.type in VBFSizeControl:
            rr = r.row(align=1)
            rr.scale_x = 0.4
            rr.prop(item, 'size', text="", icon_only=True)
        
        # Vertex Color
        if item.type in VBFUseVCLayer:
            split = c.row(align=1)
            rr = split.row(align=1)
            rr.scale_x = 0.32
            rr.label(text='')
            split.prop_search(item, 'layer', master, 'vcnames', text='Layer')
            split.prop(item, 'convert_to_srgb', text='', toggle=False, 
                icon='BRUSHES_ALL' if getattr(item, 'convert_to_srgb') else 'IPO_SINE')
            split.label(text="", icon='BLANK1')
        
        # UVs
        elif item.type in VBFUseUVLayer:
            split = c.row(align=1)
            rr = split.row(align=1)
            rr.scale_x = 0.32
            rr.label(text='')
            split.prop_search(item, 'layer', master, 'uvnames', text='Layer')
            split.label(text="", icon='BLANK1')
        
        # Group
        elif item.type == VBF_GRO:
            split = c.row(align=1)
            rr = split.row(align=1)
            rr.scale_x = 0.32
            rr.label(text='')
            split.prop_search(item, 'layer', master, 'vgnames', text='Layer')
            split.label(text="", icon='BLANK1')
        
        # Padding Floats
        elif item.type == VBF_PAD:
            split = c.row(align=1)
            rr = split.row(align=1)
            rr.scale_x = 0.32
            rr.label(text='')
            rrr = rr.row(align=0)
            n = item.size
            for i in range(0, 4):
                split.prop(item, 'padding_floats', text="", index=i, emboss=i<n)
            rrr.label(text="", icon='BLANK1')
        
        # Padding Bytes
        elif item.type == VBF_PAB:
            split = c.row(align=1)
            rr = split.row(align=1)
            rr.scale_x = 0.32
            rr.label(text='')
            rrr = rr.row(align=0)
            n = item.size
            for i in range(0, 4):
                split.prop(item, 'padding_bytes', text="", index=i, emboss=i<n)
            rrr.label(text="", icon='BLANK1')
classlist.append(VBM_FormatDef_Attribute)

# ------------------------------------------------------------------------------------

class VBM_FormatDef_Format(DMR_ItemGroup_Super, bpy.types.PropertyGroup):
    items : bpy.props.CollectionProperty(type=VBM_FormatDef_Attribute)
    
    def GetItems(self):
        return [x for x in self.items if x.type != VBF_000]
    
    def CopyFromOther(self, other):
        self.items.clear()
        self.size = 0
        
        for otheritem in other.items:
            self.Add(otheritem.type, otheritem.size, otheritem.layer).CopyFromOther(otheritem)
        return self
    
    def Serialize(self):
        return [
            [item.type, item.size, item.layer]
            for item in self.GetItems()
        ]
    
    def Unserialize(self, data):
        self.items.clear()
        self.size = 0
        
        for item in data:
            nn = len(item)
            if nn == 1:
                self.Add(item[0])
            elif nn == 2:
                self.Add(item[0], item[1])
            elif nn >= 3:
                self.Add(item[0], item[1], item[2])
    
    def ToJson(self):
        return {
            "class": "format",
            "name": self.name,
            "attributes": [item.ToJson() for item in self.items]
        }
    
    def FromJson(self, jsondata):
        if jsondata.get("class", "") == "format":
            self.Clear()
            for jsonitem in jsondata.get("attributes", []):
                self.Add().FromJson(jsonitem)
    
    def Add(self, type=VBF_000, size=4, layer=LYR_GLOBAL):
        item = self.items.add()
        self.size += 1
        item.type = type
        item.size = size
        item.layer = layer
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
        row = layout.row()
        
        # List Items
        r = layout.row()
        c = r.column(align=1)
        c.template_list(
            "VBM_UL_Attribute", "", 
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
    
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=1)
        
        r.prop(item, 'name', text="", emboss=False)
        rr = r.row(align=1)
        rr.scale_x = 0.89
        for att in item.items:
            rr.label(text="", icon=VBFIcon[att.type])
        
        r.separator()
        
        rr = r.row(align=1)
        rr.operator("vbm.export_vb", text='', icon='OBJECT_DATA').format = item.name
        rr.operator("vbm.export_vbm", text='', icon='MOD_ARRAY').format = item.name
classlist.append(VBM_FormatDef_Format)

# ------------------------------------------------------------------------------------

class VBM_FormatDef_FormatList(DMR_ItemGroup_Super, bpy.types.PropertyGroup):
    items : bpy.props.CollectionProperty(type=VBM_FormatDef_Format)
    
    op_refresh_strings : bpy.props.BoolProperty(
        name="Reload Layer Names",
        description="Parse all layer and vertex group names in file.",
        default=False,
        update=lambda s,c: s.UpdateSuper(c)
        )
    
    def ToJson(self):
        return {
            "class": "formatlist",
            "formats": [ item.ToJson() for item in self.items ]
        }
    
    def FromJson(self, jsondata):
        if jsondata.get("class", "") == "formatlist":
            for jsonitem in jsondata.get("formats", []):
                self.Define(jsonitem["name"]).FromJson(jsonitem)
    
    def Add(self):
        item = self.items.add()
        self.size += 1
        return item
    
    def Update(self, context):
        # Add
        if self.op_add_item:
            if self.size > 0:
                self.Add().CopyFromOther(self.GetActive())
            else:
                self.Add().Unserialize([
                    [VBF_POS],
                    [VBF_RGB],
                    [VBF_UVS]
                ])
            self.item_index = self.size-1
            self.op_add_item = False
        
        # Refresh Lists
        if self.op_refresh_strings:
            self.op_refresh_strings = False
            context.scene.vbm.RefreshStringLists()
    
    def DrawPanel(self, context, layout, rows=4):
        r = layout.row()
        c = r.column(align=1)
        c.template_list(
            "VBM_UL_FormatList", "", 
            self, "items", 
            self, "item_index", 
            rows=rows)
        
        c = r.column(align=1)
        c.prop(self, 'reset_mutex', text="", icon='FILE_REFRESH')
        c.separator()
        c.prop(self, 'op_add_item', text="", icon='ADD')
        c.prop(self, 'op_remove_item', text="", icon='REMOVE')
        c.separator()
        c.prop(self, 'op_move_up', text="", icon='TRIA_UP')
        c.prop(self, 'op_move_down', text="", icon='TRIA_DOWN')
        
        return c
        
classlist.append(VBM_FormatDef_FormatList)

'# =========================================================================================================================='
'# UI Lists'
'# =========================================================================================================================='

class VBM_UL_Attribute(bpy.types.UIList):
    draw_item = VBM_FormatDef_Attribute.draw_item
classlist.append(VBM_UL_Attribute)

# ------------------------------------------------------------------------------------

class VBM_UL_FormatList(bpy.types.UIList):
    draw_item = VBM_FormatDef_Format.draw_item
classlist.append(VBM_UL_FormatList)

'# =========================================================================================================================='
'# OPERATORS'
'# =========================================================================================================================='

class VBM_OT_FormatExport(ExportHelper, bpy.types.Operator):
    """Writes vertex format to json file"""
    bl_idname = "vbm.format_export"
    bl_label = "Export Vertex Buffer Format"
    bl_options = {'PRESET'}
    
    # ExportHelper mixin class uses this
    filename_ext = ".json"
    filter_glob: bpy.props.StringProperty(default="*.json", options={'HIDDEN'}, maxlen=255)
    
    data: bpy.props.EnumProperty(
        name="Data Type",
        description="Which data to export",
        items = (
            ('LIST', 'Format List', 'Export all formats in list'),
            ('FORMAT', 'Active Format', 'Export active format in list'),
        ),
        default='LIST',
    )
    
    @classmethod
    def poll(self, context):
        return context.scene.vbm.formats
    
    def execute(self, context):
        path = os.path.realpath(bpy.path.abspath(self.filepath))
        
        if not os.path.exists(os.path.dirname(path)):
            self.report({'WARNING'}, 'Invalid path specified: "%s"' % path)
            return {'FINISHED'}
        
        formats = context.scene.vbm.formats
        targetdata = formats if self.data == 'LIST' else formats.GetActive()
        
        f = open(path, 'w')
        f.write(json.dumps(targetdata.ToJson(), indent=4))
        f.close()
        
        return {'FINISHED'}
classlist.append(VBM_OT_FormatExport)

# ---------------------------------------------------------------------------------

class VBM_OT_FormatImport(ImportHelper, bpy.types.Operator):
    """Reads vertex format from json file"""
    bl_idname = "vbm.format_import"
    bl_label = "Import Vertex Buffer Format"
    bl_options = {'PRESET'}
    
    # ImportHelper mixin class uses this
    filename_ext = ".json"
    filter_glob: bpy.props.StringProperty(default="*.json", options={'HIDDEN'}, maxlen=255)
    
    data: bpy.props.EnumProperty(
        name="Data Type",
        description="Which data to import",
        items = (
            ('LIST', 'Format List', 'Import list of formats'),
            ('FORMAT', 'Active Format', 'Import to active format in list'),
        ),
        default='LIST',
    )
    
    @classmethod
    def poll(self, context):
        return context.scene.vbm.formats
    
    def execute(self, context):
        path = os.path.realpath(bpy.path.abspath(self.filepath))
        
        if not os.path.exists(os.path.dirname(path)):
            self.report({'WARNING'}, 'Invalid path specified: "%s"' % path)
            return {'FINISHED'}
        
        formats = context.scene.vbm.formats
        targetdata = formats if self.data == 'LIST' else formats.GetActive()
        
        f = open(path)
        jsondata = f.read()
        f.close()
        
        targetdata.FromJson(json.loads(jsondata))
        
        return {'FINISHED'}
classlist.append(VBM_OT_FormatImport)

'# =========================================================================================================================='
'# REGISTER'
'# =========================================================================================================================='

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in classlist[::-1]:
        bpy.utils.unregister_class(c)

