import bpy
import numpy
import struct
import bmesh
import os
import zlib
import mathutils

from bpy_extras.io_utils import ExportHelper, ImportHelper

classlist = []

# VBM spec:
"""
    'VBM' (3B)
    VBM version = 3 (1B)
    
    flags (1B)
    
    jumpvbuffer (1I)
    jumpskeleton (1I)
    jumpanimations (1I)
    
    -- Vertex Buffers ----------------------------------------------
    numvbuffers (1I)
    
    formatlength (1B)
    formatentry[formatlength]
        attributetype (1B)
        attributefloatsize (1B)
    
    vbnames[vbcount]
        namelength (1B)
        namechars[namelength]
            char (1B)
    vbdata[vbcount]
        vbcompressedsize (1L)
        vbnumvertices (1L)
        vbcompresseddata (vbcompressedsize B)
    
    *vbmaterials[vbcount]
        namelength (1B)
        namechars[namelength]
            char (1B)
    
    -- Skeleton ---------------------------------------------------
    numbones (1I)
    bonenames[numbones]
        namelength (1B)
        namechars[namelength]
            char (1B)
    parentindices[numbones] 
        parentindex (1I)
    localmatrices[numbones]
        mat4 (16f)
    inversemodelmatrices[numbones]
        mat4 (16f)
    
    -- Animation --------------------------------------------------------
    numanimations (1I)
    animations[numanimations]
        namelength (1B)
        namechars[namelength]
            char (1B)
        
        fps (1f)
        numtracks (1I)
        numcurves (1I)
        nummarkers (1I)
        duration (1f)
        
        curves[numcurves]
            namelength (1B)
            namechars[namelength]
                char (1B)
            numchannels (1B)
            channels[]
                numframes (1I)
                arrayindex (1I)
                framepositions[numframes]
                    position (1f)
                framevalues[numframes]
                    value (1f)
                frameinterpolations[numframes]
                    interpolationtype (1B)
        
        tracknames[numtracks]
            namelength (1B)
            namechars[namelength]
                char (1B)
        
        trackspace (1B)
            0 = No Tracks
            1 = LOCAL
            2 = POSE
            3 = WORLD
        trackdata[numtracks]
            locationtransforms
                numframes (1I)
                framepositions[numframes]
                    position (1f)
                framevectors[numframes]
                    vector[3]
                        value (1f)
            
            quaterniontransforms
                numframes (1I)
                framepositions[numframes]
                    position (1f)
                framevectors[numframes]
                    vector[4]
                        value (1f)
            
            scaletransforms
                numframes (1I)
                framepositions[numframes]
                    position (1f)
                framevectors[numframes]
                    vector[3]
                        value (1f)
        
        markernames[nummarkers]
            namelength (1B)
            namechars[namelength]
                char (1B)
        markerpositions[nummarkers]
            position (1f)
        
        tracknames[numvectors]
            namelength (1B)
            namechars[namelength]
                char (1B)
"""

'# =========================================================================================================================='
'# CONSTANTS'
'# =========================================================================================================================='

if 1: # Folding
    VBMVERSION = 3
    FCODE = 'f'
    
    EXPORTLISTHEADER = "|"
    USE_ATTRIBUTES = bpy.app.version >= (3,2,2)
    
    VBF_000 = '0'
    VBF_POS = 'POSITION'
    VBF_UVS = 'UV'
    VBF_UVB = 'UVBYTES'
    VBF_NOR = 'NORMAL'
    VBF_TAN = 'TANGENT'
    VBF_BTN = 'BITANGENT'
    VBF_COL = 'COLOR'
    VBF_RGB = 'COLORBYTES'
    VBF_BON = 'BONE'
    VBF_BOB = 'BONEBYTES'
    VBF_WEI = 'WEIGHT'
    VBF_WEB = 'WEIGHTBYTES'
    VBF_GRO = 'VERTEXGROUP'
    VBF_PAD = 'PAD'
    VBF_PAB = 'PADBYTES'
    
    VBFUseBytes = [VBF_UVB, VBF_RGB, VBF_BOB, VBF_WEB, VBF_PAB]
    VBFUseSizeControl = [VBF_POS, VBF_NOR, VBF_TAN, VBF_BTN, VBF_COL, VBF_RGB, VBF_BON, VBF_BOB, VBF_WEI, VBF_WEB, VBF_PAD, VBF_PAB]
    VBFUseVCLayer = [VBF_COL, VBF_RGB]
    VBFUseUVLayer = [VBF_UVS, VBF_UVB]
    VBFUsePadding = [VBF_PAD, VBF_PAB]
    
    LYR_RENDER = '<RENDER>'
    LYR_SELECT = '<SELECT>'
    
    MTY_VIEW = 'VIEWPORT'
    MTY_RENDER = 'RENDER'
    MTY_OR = 'OR'
    MTY_AND = 'AND'
    MTY_ALL = 'ALL'
    
    VERTEXGROUPNULL = '---'

    VBFSize = {
        VBF_000: 0,
        VBF_POS: 3,
        VBF_UVS: 2, 
        VBF_UVB: 2, 
        VBF_NOR: 3, 
        VBF_TAN: 3,
        VBF_BTN: 3,
        VBF_COL: 4, 
        VBF_RGB: 4,
        VBF_BON: 4,
        VBF_BOB: 4,
        VBF_WEI: 4, 
        VBF_WEB: 4,
        VBF_GRO: 1,
        VBF_PAD: 4,
        VBF_PAB: 4,
        }
    
    VBFDefaults = {
        VBF_UVS: (0,0),
        VBF_UVB: (0,0),
        VBF_COL: (1,1,1,1),
        VBF_RGB: (255,255,255,255),
        VBF_BON: (0,0,0,0),
        VBF_BOB: (0,0,0,0),
        VBF_WEI: (0,0,0,0),
        VBF_WEB: (0,0,0,0),
        VBF_GRO: [0],
        VBF_PAD: (0,0,0,0),
        VBF_PAB: (0,0,0,0),
    }
    
    VBFTypes = list(VBFSize.keys())
    
    VBFVarname = {
        VBF_000: "in_???",
        VBF_POS: "in_Position",
        VBF_UVS: "in_TextureCoord", 
        VBF_UVB: "in_TextureCoord", 
        VBF_NOR: "in_Normal",
        VBF_TAN: "in_Tangent",
        VBF_BTN: "in_Bitangent",
        VBF_COL: "in_Color",
        VBF_RGB: "in_Color",
        VBF_BON: "in_Bone",
        VBF_BOB: "in_Bone",
        VBF_WEI: "in_Weight",
        VBF_WEB: "in_Weight",
        VBF_GRO: "in_Group",
        }

    Items_VBF = (
        (VBF_000, '---', 'No Data', 'BLANK1', 0),
        (VBF_POS, 'Position', '3* Floats', 'VERTEXSEL', 1),
        (VBF_UVS, 'UVs', '2 Floats', 'UV', 2),
        (VBF_UVB, 'UV Bytes', '2 Bytes = Half size of 1 float', 'UV', 3),
        (VBF_NOR, 'Normal', '3 Floats', 'NORMALS_VERTEX', 4),
        (VBF_TAN, 'Tangents', '3 Floats', 'NORMALS_VERTEX_FACE', 5),
        (VBF_BTN, 'Bitangents', '3 Floats', 'NORMALS_VERTEX_FACE', 6),
        (VBF_COL, 'Color (RGBA)', '4* Floats', 'COLOR', 7),
        (VBF_RGB, 'Color Bytes (RGBA)', '4 Bytes = Size of 1 Float in format 0xRRGGBBAA', 'RESTRICT_COLOR_OFF', 8),
        (VBF_BON, 'Bone Indices', '4* Floats (Use with Weights)', 'BONE_DATA', 9),
        (VBF_BOB, 'Bone Index Bytes', '4 Bytes = Size of 1 Float in format 0xWWZZYYXX', 'BONE_DATA', 10),
        (VBF_WEI, 'Weights', '4* Floats', 'MOD_VERTEX_WEIGHT', 11),
        (VBF_WEB, 'Weight Bytes', '4 Bytes = Size of 1 Float in format 0xWWZZYYXX', 'MOD_VERTEX_WEIGHT', 12),
        (VBF_GRO, 'Vertex Group', '1 Float', 'GROUP_VERTEX', 13),
        (VBF_PAD, 'Padding', 'X Floats', 'LINENUMBERS_ON', 98),
        (VBF_PAB, 'Padding Bytes', 'X Bytes', 'LINENUMBERS_ON', 99),
    )
    
    Items_VBF_NoName = [ tuple([x[0]]+[""]+list(x[2:])) for x in Items_VBF ]

    VBFName = {x[0]: x[1] for x in Items_VBF}
    VBFIcon = {x[0]: x[3] for x in Items_VBF}

    VBFTypeIndex = {x[1]: x[0] for x in enumerate(VBFTypes)}

    Items_LayerChoice = (
        ('render', 'Render Layer', 'Use the layer that will be rendered (camera icon is on)', 'RESTRICT_RENDER_OFF', 0),
        ('active', 'Active Layer', 'Use the layer that is active (highlighted)', 'RESTRICT_SELECT_OFF', 1),
    )

    Items_ModChoice = (
        (MTY_VIEW, 'Viewport Only', 'Only export modifiers visible in viewports'), 
        (MTY_RENDER, 'Render Only', 'Only export modifiers visible in renders'), 
        (MTY_OR, 'Viewport or Render', 'Export modifiers if they are visible in viewport or renders'), 
        (MTY_AND, 'Viewport and Render', 'Export modifiers only if they are visible in viewport and renders'), 
        (MTY_ALL, 'All', 'Export all supported modifiers')
    )

    Items_UpAxis = (
        ('+x', '+X Up', 'Export model(s) with +X Up axis'),
        ('+y', '+Y Up', 'Export model(s) with +Y Up axis'),
        ('+z', '+Z Up', 'Export model(s) with +Z Up axis'),
        ('-x', '-X Up', 'Export model(s) with -X Up axis'),
        ('-y', '-Y Up', 'Export model(s) with -Y Up axis'),
        ('-z', '-Z Up', 'Export model(s) with -Z Up axis'),
    )

    Items_ForwardAxis = (
        ('+x', '+X Forward', 'Export model(s) with +X Forward axis'),
        ('+y', '+Y Forward', 'Export model(s) with +Y Forward axis'),
        ('+z', '+Z Forward', 'Export model(s) with +Z Forward axis'),
        ('-x', '-X Forward', 'Export model(s) with -X Forward axis'),
        ('-y', '-Y Forward', 'Export model(s) with -Y Forward axis'),
        ('-z', '-Z Forward', 'Export model(s) with -Z Forward axis'),
    )

    Items_FloatChoice = (
        ('f', 'Float (32bit) *GMS*', 'Write floating point data using floats (32 bits)\n***Use for Game Maker Studio***'),
        ('d', 'Double (64bit)', 'Write floating point data using doubles (64 bits)'),
        ('e', 'Binary16 (16bit)', 'Write floating point data using binary16 (16 bits)'),
    )

    Items_VBMSort = (
        ('NONE', 'No Batching', 'All objects will be written to a single file'),
        ('OBJECT', 'By Object Name', 'Objects will be written to "<filename><object_name>.vbm" by object'),
        ('MESH', 'By Mesh Name', 'Objects will be written to "<filename><mesh_name>.vbm" by mesh'),
        ('MATERIAL', 'By Material', 'Objects will be written to "<filename><material_name>.vbm" by material'),
        ('ARMATURE', 'By Parent Armature', 'Objects will be written to "<filename><armature_name>.vbm" by parent armature'),
        #('EMPTY', 'By Parent Empty', 'Objects will be written to "<filename><emptyname>.vbm" by parent empty'),
    )

    VALIDOBJTYPES = ['MESH', 'CURVE', 'META', 'FONT', 'SURFACE']

'# =========================================================================================================================='
'# PROPERTY GROUPS'
'# =========================================================================================================================='

# -------------------------------------------------------------------------------------------------------------------------------
class VBM_PG_Name(bpy.types.PropertyGroup):
    pass
classlist.append(VBM_PG_Name)

# -------------------------------------------------------------------------------------------------------------------------------
class VBM_PG_Format_Attribute(bpy.types.PropertyGroup):
    def UpdateFormatString(self, context):
        if self.format_code_mutex == False:
            self.format_code_mutex = True
            if self.type == VBF_PAB:
                self.default_normalize = True
            if self.type == VBF_PAD:
                self.default_normalize = False
            
            for format in context.scene.vbm.formats:
                if sum([att.format_code_mutex for att in format.attributes]) > 0:
                    format.UpdateFormatString(context)
            
            self.size = min(self.size, VBFSize[self.type])
        
        for format in context.scene.vbm.formats:
            for att in format.attributes:
                att.format_code_mutex = False
    
    format_code_mutex : bpy.props.BoolProperty()
    
    type : bpy.props.EnumProperty(
        name="Attribute Type", items=Items_VBF, default=VBF_000, update=UpdateFormatString,
        description='Data to write for each vertex')
    
    size : bpy.props.IntProperty(
        name="Attribute Size", min=1, max=4, default=4, update=UpdateFormatString,
        description='Number of floats to write for this attribute.\n\nFor Position: 3 = XYZ, 2 = XY\nFor Colors, 4 = RGBA, 3 = RGB, 2 = RG, 1 = R')
    
    layer : bpy.props.StringProperty(
        name="Attribute Layer", default=LYR_RENDER, update=UpdateFormatString,
        description='Specific Color or UV layer to reference. ')
    
    convert_to_srgb : bpy.props.BoolProperty(
        name="Is SRGB", default=True, update=UpdateFormatString,
        description='Convert color values from linear to SRGB')
    
    padding_floats : bpy.props.FloatVectorProperty(
        name="Padding", size=4, default=(1.0,1.0,1.0,1.0), update=UpdateFormatString,
        description="Constant values for this attribute")
    
    padding_bytes : bpy.props.IntVectorProperty(
        name="Padding Bytes", size=4, default=(255,255,255,255), update=UpdateFormatString,
        description="Constant values for this attribute",)
    
    default_normalize : bpy.props.BoolProperty(
        name="Normalized Bytes", default=False, update=UpdateFormatString,
        description="Use normalized bytes for default value. This means the value will be divided by 255 on export",
        )
classlist.append(VBM_PG_Format_Attribute)

# -------------------------------------------------------------------------------------------------------------------------------
class VBM_PG_Format(bpy.types.PropertyGroup):
    def UpdateFormatString(self, context=None):
        if not self.format_code_mutex:
            self.format_code_mutex = True
            attributes = self.attributes
            fstring = ""
            
            for att in attributes:
                s = str(att.type)
                s += str(att.size)
                
                if att.layer == LYR_SELECT:
                    s += "-select"
                elif att.layer != LYR_RENDER:
                    s += '@"' + att.layer + '"'
                if not att.convert_to_srgb:
                    s += "-linear"
                if att.type == VBF_PAD:
                    s += "=("+("%.2f,"*att.size)[:-1] % att.padding_floats[:att.size]+")"
                elif att.type == VBF_PAB:
                    s += "=("+("%d,"*att.size)[:-1] % att.padding_bytes[:att.size]+")"
                    s += "-units"
                
                fstring += s + " "
            self.format_code = fstring
        self.format_code_mutex = False
    
    def SetFormatCode(self, context=None):
        if not self.format_code_mutex:
            self.format_code_mutex = True
            
            attraw = bpy.context.scene.vbm.ParseFormatString(self.format_code) # [ ( type, size, default ) ]
            if len(attraw) > 0:
                self.attributes.clear()
                for att in attraw:
                    item = self.attributes.add()
                    item.type, item.size, item.layer, item.convert_to_srgb, item.default_value = att
        
        self.format_code_mutex = False
    
    def DrawPanel(self, layout, show_operators=False):
        format = self
        c = layout.column(align=True)
        
        r = c.row(align=True)
        cc = r.column(align=True)
        cc.template_list("VBM_UL_Format_Attribute", "", format, "attributes", format, "attributes_index", rows=5)
        c.prop(format, 'format_code', text="")
        
        if show_operators:
            r.separator()
            
            c = r.column(align=True)
            c.operator('vbm.attribute_add', text="", icon='ADD')
            c.operator('vbm.attribute_remove', text="", icon='REMOVE').index = format.attributes_index
            c.separator()
            op = c.operator('vbm.attribute_move', text="", icon='TRIA_UP')
            op.move_down = False
            op = c.operator('vbm.attribute_move', text="", icon='TRIA_DOWN')
            op.move_down = True
    
    name : bpy.props.StringProperty(name="Name", default="Format")
    attributes : bpy.props.CollectionProperty(name="Attribute", type=VBM_PG_Format_Attribute)
    attributes_index : bpy.props.IntProperty(name="Attributes Index")
    
    format_code : bpy.props.StringProperty(
        name="Format String", default="", update=SetFormatCode,
        description="The string equivalent of the vertex format")
    format_code_mutex : bpy.props.BoolProperty()
classlist.append(VBM_PG_Format)

# ========================================================================================================
class VBM_PG_ExportList_Object(bpy.types.PropertyGroup):
    object : bpy.props.PointerProperty(type=bpy.types.Object)
classlist.append(VBM_PG_ExportList_Object)

# ---------------------------------------------------------------------------------------------
class VBM_PG_ExportList(bpy.types.PropertyGroup):
    name : bpy.props.StringProperty(name="Name", default="List")
    objects : bpy.props.CollectionProperty(type=VBM_PG_ExportList_Object)
classlist.append(VBM_PG_ExportList)

# ========================================================================================================
class VBM_PG_Action(bpy.types.PropertyGroup):
    action : bpy.props.PointerProperty(type=bpy.types.Action)
classlist.append(VBM_PG_Action)

# ========================================================================================================

class VBM_PG_BoneDissolveTree(bpy.types.PropertyGroup):
    name : bpy.props.StringProperty(name="Name", default="")
    depth : bpy.props.IntProperty()
    parent : bpy.props.StringProperty()
    children : bpy.props.CollectionProperty(name="Children", type=VBM_PG_Name)
    all_parents : bpy.props.CollectionProperty(name="Children", type=VBM_PG_Name)
    dissolve : bpy.props.BoolProperty()
classlist.append(VBM_PG_BoneDissolveTree)

# ------------------------------------------------------------------------------
class VBM_PG_BoneDissolveList(bpy.types.PropertyGroup):
    dissolves : bpy.props.CollectionProperty(name="Dissolves", type=VBM_PG_BoneDissolveTree)
    index : bpy.props.IntProperty(name="Index", default=0)
classlist.append(VBM_PG_BoneDissolveList)

'# =========================================================================================================================='
'# OPERATORS'
'# =========================================================================================================================='

# -------------------------------------------------------------------------------------------
class VBM_OT_ClearCache(bpy.types.Operator):
    """Clear stored data used in re-exports"""
    bl_label = "Clear Cache"
    bl_idname = 'vbm.clear_cache'
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        for obj in bpy.data.objects:
            if obj.type == 'MESH':
                for k in list(obj.keys())[::-1]:
                    if k[:6] in ('VBDAT_', 'VBNUM_', 'VBSUM_') or k in 'VBM_LASTCOUNT VBM_LASTDATA'.split():
                        del obj[k]
        return {'FINISHED'}
classlist.append(VBM_OT_ClearCache)

'========================================================================================================'

# -------------------------------------------------------------------------------------------
class VBM_OT_Format_Add(bpy.types.Operator):
    """Add vertex format to scene"""
    bl_label = "Add Format"
    bl_idname = 'vbm.format_add'
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        format = context.scene.vbm.formats.add()
        format.name = format.name
        format.format_code = "POSITION3 COLORBYTES4 UV4"
        return {'FINISHED'}
classlist.append(VBM_OT_Format_Add)

# -------------------------------------------------------------------------------------------
class VBM_OT_Format_Remove(bpy.types.Operator):
    """Remove vertex format by index"""
    bl_label = "Remove Format"
    bl_idname = 'vbm.format_remove'
    bl_options = {'REGISTER', 'UNDO'}
    index : bpy.props.IntProperty(name="Index")
    
    def execute(self, context):
        context.scene.vbm.formats.remove(self.index)
        return {'FINISHED'}
classlist.append(VBM_OT_Format_Remove)

# -------------------------------------------------------------------------------------------
class VBM_OT_Format_Move(bpy.types.Operator):
    """Moves format in list"""
    bl_label = "Move Format"
    bl_idname = 'vbm.format_move'
    bl_options = {'REGISTER', 'UNDO'}
    move_down : bpy.props.BoolProperty(name="Move Down", default=True)
    
    def execute(self, context):
        vbm = context.scene.vbm
        formats = context.scene.vbm.formats
        formats.move(vbm.formats_index, vbm.formats_index + (1 if self.move_down else -1))
        vbm.formats_index = max(0, min(vbm.formats_index + (1 if self.move_down else -1), len(formats)-1))
        return {'FINISHED'}
classlist.append(VBM_OT_Format_Move)

# -------------------------------------------------------------------------------------------
class VBM_OT_Attribute_Add(bpy.types.Operator):
    """Add attribute to format"""
    bl_label = "Add Attribute"
    bl_idname = 'vbm.attribute_add'
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        vbm = context.scene.vbm
        format = vbm.formats[vbm.formats_index]
        format.attributes.add()
        format.attributes.move(len(format.attributes)-1, format.attributes_index+1)
        format.UpdateFormatString()
        return {'FINISHED'}
classlist.append(VBM_OT_Attribute_Add)

# -------------------------------------------------------------------------------------------
class VBM_OT_Attribute_Remove(bpy.types.Operator):
    """Remove attribute from format"""
    bl_label = "Remove Attribute"
    bl_idname = 'vbm.attribute_remove'
    bl_options = {'REGISTER', 'UNDO'}
    index : bpy.props.IntProperty(name="Index")
    
    def execute(self, context):
        vbm = context.scene.vbm
        format = vbm.formats[vbm.formats_index]
        format.attributes.remove(self.index)
        format.attributes_index = max(0, min(format.attributes_index, len(format.attributes)-1))
        format.UpdateFormatString()
        return {'FINISHED'}
classlist.append(VBM_OT_Attribute_Remove)

# -------------------------------------------------------------------------------------------
class VBM_OT_Attribute_Move(bpy.types.Operator):
    """Move attribute up or down in list"""
    bl_label = "Move Attribute"
    bl_idname = 'vbm.attribute_move'
    bl_options = {'REGISTER', 'UNDO'}
    move_down : bpy.props.BoolProperty(name="Move Down", default=True)
    
    def execute(self, context):
        vbm = context.scene.vbm
        format = vbm.formats[vbm.formats_index]
        format.attributes.move(format.attributes_index, format.attributes_index + (1 if self.move_down else -1))
        format.attributes_index = max(0, min(format.attributes_index + (1 if self.move_down else -1), len(format.attributes)-1))
        format.UpdateFormatString()
        return {'FINISHED'}
classlist.append(VBM_OT_Attribute_Move)

# -------------------------------------------------------------------------------------------
class VBM_OT_Attribute_SetLayer(bpy.types.Operator):
    """Sets layer for attribute"""
    bl_label = "Set Attribute Layer"
    bl_idname = 'vbm.format_attribute_set_layer'
    bl_options = {'REGISTER', 'UNDO'}
    index : bpy.props.IntProperty(name="Index")
    attribute_index : bpy.props.IntProperty(name="Attribute Index")
    layer : bpy.props.StringProperty(name="Layer")
    
    def execute(self, context):
        vbm = context.scene.vbm
        vbm.formats[self.index].attributes[self.attribute_index].layer = self.layer
        return {'FINISHED'}
classlist.append(VBM_OT_Attribute_SetLayer)

'========================================================================================================'

class VBM_OT_ActionList_FromPattern(bpy.types.Operator):
    """Adds actions to NLA using pattern"""
    bl_label = "Populate with Pattern"
    bl_idname = 'vbm.actionlist_from_pattern'
    bl_options = {'REGISTER', 'UNDO'}
    
    pattern : bpy.props.StringProperty(name="Pattern")
    dialog : bpy.props.BoolProperty()
    
    @classmethod
    def poll(self, context):
        obj = context.active_object
        rig = (obj if obj.type == 'ARMATURE' else obj.find_armature()) if obj else None
        return rig
    
    def draw(self, context):
        layout = self.layout
        layout.prop(self, 'pattern')
    
    def invoke(self, context, event):
        if self.dialog:
            return context.window_manager.invoke_props_dialog(self)
        
        pattern = context.active_object.name
        for c in '-.`_':
            if c in pattern:
                pattern = pattern[:pattern.find(c)]
        
        self.pattern = pattern
        
        return self.execute(context)
    
    def execute(self, context):
        obj = context.active_object
        rig = (obj if obj.type == 'ARMATURE' else obj.find_armature()) if obj else None
        actionlist = rig.data.vbm_action_list
        actions = [a for a in bpy.data.actions if a.name[:len(self.pattern)] == self.pattern]
        actions = [a for a in actions if '_BAKED' not in a.name.upper()]
        
        for a in actions:
            if a not in [x.action for x in actionlist]:
                actionlist.add().action = a
            
        return {'FINISHED'}
classlist.append(VBM_OT_ActionList_FromPattern)

# -------------------------------------------------------------------------------------------
class VBM_OT_ActionList_Add(bpy.types.Operator):
    """Add action to action list"""
    bl_label = "Add Action"
    bl_idname = 'vbm.actionlist_add'
    bl_options = {'REGISTER', 'UNDO'}
    
    action : bpy.props.StringProperty(name="Action", default="")
    
    def execute(self, context):
        obj = context.active_object
        rig = (obj if obj.type == 'ARMATURE' else obj.find_armature())
        armature = rig.data
        actionlist = armature.vbm_action_list
        action = bpy.data.actions[self.action]
        
        actionlist.add().action = action
        actionlist.move(len(actionlist)-1, armature.vbm_action_list_index+1)
        armature.vbm_action_list_index += 1
        return {'FINISHED'}
classlist.append(VBM_OT_ActionList_Add)

# -------------------------------------------------------------------------------------------
class VBM_OT_ActionList_Duplicate(bpy.types.Operator):
    """Duplicates action to action list"""
    bl_label = "Duplicate Action"
    bl_idname = 'vbm.actionlist_duplicate'
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        obj = context.active_object
        rig = (obj if obj.type == 'ARMATURE' else obj.find_armature())
        armature = rig.data
        actionlist = armature.vbm_action_list
        action = bpy.data.actions[actionlist[armature.vbm_action_list_index].action.name].copy()
        
        actionlist.add().action = action
        actionlist.move(len(actionlist)-1, armature.vbm_action_list_index+1)
        armature.vbm_action_list_index += 1
        return {'FINISHED'}
classlist.append(VBM_OT_ActionList_Duplicate)

# -------------------------------------------------------------------------------------------
class VBM_OT_ActionList_Remove(bpy.types.Operator):
    """Remove action from list"""
    bl_label = "Remove Action"
    bl_idname = 'vbm.actionlist_remove'
    bl_options = {'REGISTER', 'UNDO'}
    index : bpy.props.IntProperty(name="Index")
    
    def execute(self, context):
        obj = context.active_object
        rig = (obj if obj.type == 'ARMATURE' else obj.find_armature())
        armature = rig.data
        actionlist = armature.vbm_action_list
        actionlist.remove(self.index)
        armature.vbm_action_list_index = max(0, min(armature.vbm_action_list_index, len(actionlist)-1))
        return {'FINISHED'}
classlist.append(VBM_OT_ActionList_Remove)

# -------------------------------------------------------------------------------------------
class VBM_OT_ActionList_Clear(bpy.types.Operator):
    """Remove all actions from list"""
    bl_label = "Clear Actions"
    bl_idname = 'vbm.actionlist_clear'
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        obj = context.active_object
        rig = (obj if obj.type == 'ARMATURE' else obj.find_armature())
        armature = rig.data
        actionlist = armature.vbm_action_list
        actionlist.clear()
        armature.vbm_action_list_index = 0
        return {'FINISHED'}
classlist.append(VBM_OT_ActionList_Clear)

# -------------------------------------------------------------------------------------------
class VBM_OT_ActionList_Move(bpy.types.Operator):
    """Move action up or down"""
    bl_label = "Move Action"
    bl_idname = 'vbm.actionlist_move'
    bl_options = {'REGISTER', 'UNDO'}
    
    move_down : bpy.props.BoolProperty(name="Move Down", default=True)
    
    def execute(self, context):
        obj = context.active_object
        rig = (obj if obj.type == 'ARMATURE' else obj.find_armature())
        armature = rig.data
        actionlist = armature.vbm_action_list
        actionlist.move(armature.vbm_action_list_index, armature.vbm_action_list_index + (1 if self.move_down else -1))
        armature.vbm_action_list_index = max(0, min(armature.vbm_action_list_index + (1 if self.move_down else -1), len(actionlist)-1))
        return {'FINISHED'}
classlist.append(VBM_OT_ActionList_Move)

# -------------------------------------------------------------------------------------------
class VBM_OT_ActionList_Play(bpy.types.Operator):
    """Plays action"""
    bl_label = "Play Action"
    bl_idname = 'vbm.actionlist_play'
    bl_options = {'REGISTER', 'UNDO'}
    
    action : bpy.props.StringProperty(name="Action", default="")
    
    def execute(self, context):
        action = bpy.data.actions.get(self.action)
        if action:
            obj = context.active_object
            rig = (obj if obj.type == 'ARMATURE' else obj.find_armature())
            
            rig.animation_data.action = action
            sc = context.scene
            sc.frame_start = int(action.frame_start)
            sc.frame_end = int(action.frame_end)
        
        return {'FINISHED'}
classlist.append(VBM_OT_ActionList_Play)

'========================================================================================================'

# -------------------------------------------------------------------------------------------
class VBM_OT_BoneDissolve_Init(bpy.types.Operator):
    """Create dissolve tree"""
    bl_label = "Build Tree"
    bl_idname = 'vbm.bonedissolve_initialize'
    bl_options = {'REGISTER', 'UNDO'}
    
    preserve : bpy.props.BoolProperty(name="Keep Last Values", default=True)
    
    @classmethod
    def poll(self, context):
        return context.object and context.object.type == 'ARMATURE'
    
    def execute(self, context):
        vbm = context.scene.vbm
        rig = context.object
        dissolves = rig.data.vbm_dissolve_list.dissolves
        lastdissolves = [x.name for x in dissolves if x.dissolve]
        dissolves.clear()
        
        deformmap = vbm.DeformArmatureMap(rig) # {bname: pname}
        tree = {}
        leaf = {}
        
        for b,p in deformmap.items():
            children = {}
            # Root
            if p not in leaf.keys():
                tree[b] = children
            # Leaf
            else:
                leaf[p][b] = children
            leaf[b] = children
        
        def Iterate(t, item, depth=0, parentnames=[]):
            item.depth = depth
            parentnames.append(item.name)
            
            for cname,ctree in t.items():
                ditem = dissolves.add()
                ditem.name = cname
                ditem.parent = item.name
                for g in parentnames:
                    ditem.all_parents.add().name = g
                item.children.add().name = cname
                Iterate(ctree, ditem, depth+1)
        
        item = dissolves.add()
        item.name="<Root>"
        Iterate(tree, item)
        
        if self.preserve:
            for name in lastdissolves:
                if name in dissolves:
                    dissolves[name].dissolve = True
        
        return {'FINISHED'}
classlist.append(VBM_OT_BoneDissolve_Init)

# -------------------------------------------------------------------------------------------
class VBM_OT_ExportList_Remove(bpy.types.Operator):
    """Remove vertex format by index"""
    bl_label = "Remove Format"
    bl_idname = 'vbm.exportlist_remove'
    bl_options = {'REGISTER', 'UNDO'}
    index : bpy.props.IntProperty(name="Index")
    
    def execute(self, context):
        context.scene.vbm.export_lists.remove(self.index)
        return {'FINISHED'}
classlist.append(VBM_OT_ExportList_Remove)

'========================================================================================================'

# -------------------------------------------------------------------------------------------
class VBM_OT_ExportVBM(ExportHelper, bpy.types.Operator):
    """Add vertex format to scene"""
    bl_label = "Export VBM"
    bl_idname = 'vbm.export_vbm'
    bl_options = {'REGISTER', 'UNDO'}
    
    dialog: bpy.props.BoolProperty(default=True)
    
    filter_glob: bpy.props.StringProperty(default="*", options={'HIDDEN'}, maxlen=255)
    filename_ext: bpy.props.StringProperty(default=".vb", options={'HIDDEN'})
    file_type: bpy.props.EnumProperty(name="File Type", items=(
        ('VB', "Vertex Buffer", "Export as single vertex buffer"),
        ('VBM', "VBM File", "Export as a collection of vertex buffers with optional bone data"),
    ))
    
    export_meshes : bpy.props.BoolProperty(
        name="Export Meshes", default=True,
        description="Include meshes in export"
    )
    
    export_skeleton : bpy.props.BoolProperty(
        name="Export Skeleton", default=True,
        description="Include skeleton data in export"
    )
    
    export_animations : bpy.props.BoolProperty(
        name="Export Animations", default=True,
        description="Include animations in export"
    )
    
    items_collections : bpy.props.CollectionProperty(type=VBM_PG_Name)
    collection : bpy.props.StringProperty(
        name="Collection", default="",
        description="Collection to export. If empty, all scene objects are used"
    )
    
    items_armatures : bpy.props.CollectionProperty(type=VBM_PG_Name)
    armature : bpy.props.StringProperty(
        name="Armature", default="",
        description="Armature to export. If set, 'collection' parameter is ignored"
    )
    
    # VBuffer ===================================================
    batching : bpy.props.EnumProperty(
        name="Batching", default='NONE', items=(
            ('NONE', 'No Batching', 'All objects will be written to a single file'),
            ('OBJECT', 'By Object Name', 'Objects will be written to "<filename><object_name>.ext" by object'),
            ('MESH', 'By Mesh Name', 'Objects will be written to "<filename><mesh_name>.ext" by mesh'),
            ('MATERIAL', 'By Material', 'Objects will be written to "<filename><material_name>.ext" by material'),
            ('ARMATURE', 'By Parent Armature', 'Objects will be written to "<filename><armature_name>.ext" by parent armature'),
            #('EMPTY', 'By Parent Empty', 'Objects will be written to "<filename><emptyname>.ext" by parent empty'),
        ),
        description="Method to write files. Can be set to single file or write multiple based on criteria"
    )
    
    grouping : bpy.props.EnumProperty(
        name="Grouping", default='OBJECT', items=(
            ('OBJECT', "By Object", "Objects -> VBs"),
            ('MATERIAL', "By Material", "Materials -> VBs"),
            ('ACTION', "By Frame", "Object at frame -> VBs"),
        ),
        description="Method to split vertex buffers."
    )
    
    format_code : bpy.props.StringProperty(
        name="Format Code", default="POSITION COLORBYTES UV",
        description="String alternative to setting vertex format"
    )
    
    format : bpy.props.StringProperty(
        name="Format", default="",
        description="Name of defined scene format. If valid, overrides format code."
    )
    
    fast_vb : bpy.props.BoolProperty(
        name="Fast VB Building", default=False,
        description="Create vbs using the final evaluated mesh. This uses actively visual modifiers only. Unused if bone indices or weights are in format."
    )
    
    cache_vb : bpy.props.BoolProperty(
        name="Use Cache", default=True,
        description="Write and use cached vertex buffers if meshes are not changed between exports. Takes into account format as well as mesh data"
    )
    
    alphanumeric_modifiers : bpy.props.BoolProperty(
        name="Alphanumeric Modifiers", default=True,
        description="Modifiers with names starting with a non-alphanumeric character are omitted from export"
    )
    
    # Skeleton ===================================================
    
    deform_only : bpy.props.BoolProperty(
        name="Deform Only", default=True,
        description="Only export deform bones for skeleton and bone-related attributes"
    )
    
    add_root_bone : bpy.props.BoolProperty(
        name="Add Zero Bone", default=True,
        description="Adds a root bone to the origin of the armature."
    )
    
    # Checkout ===================================================
    visible_only : bpy.props.BoolProperty(
        name="Visible Only", default=True,
        description="Export meshes that are visible"
    )
    
    selected_only : bpy.props.BoolProperty(
        name="Selected Only", default=True,
        description="Export meshes that are selected"
    )
    
    alphanumeric_only : bpy.props.BoolProperty(
        name="Alphanumeric Only", default=True,
        description="Objects with names starting with a non-alphanumeric character are omitted from export"
    )
    
    compression : bpy.props.IntProperty(
        name="Compression", default=-1, min=-1, max=9,
        description="Amount to compress file"
    )
    
    mesh_delimiter_start : bpy.props.StringProperty(
        name="Mesh Delimiter Start", default="-",
        description="Remove beginning of mesh name up to and including this character"
    )
    
    mesh_delimiter_end : bpy.props.StringProperty(
        name="Mesh Delimiter End", default="",
        description="Remove end of mesh name including this character"
    )
    
    mesh_delimiter_show : bpy.props.BoolProperty(
        name="Show Corrected Names", default=True,
        description="Show corrected action names"
    )
    
    action_delimiter_start : bpy.props.StringProperty(
        name="Action Delimiter Start", default="-",
        description="Remove beginning of action name up to and including this character"
    )
    
    action_delimiter_end : bpy.props.StringProperty(
        name="Action Delimiter End", default="",
        description="Remove end of action name including this character"
    )
    
    action_delimiter_show : bpy.props.BoolProperty(
        name="Action Corrected Names", default=True,
        description="Show corrected action names"
    )
    
    menu_vbuffer : bpy.props.BoolProperty(name="Vertex Buffer Options", default=True)
    menu_skeleton : bpy.props.BoolProperty(name="Skeleton Options", default=True)
    menu_animation : bpy.props.BoolProperty(name="Animation Options", default=True)
    menu_checkout : bpy.props.BoolProperty(name="Checkout Options", default=True)
    
    pre_script : bpy.props.StringProperty(
        name="Pre Script", default="",
        description="Script to run on objects before applying modifiers."
    )
    
    post_script : bpy.props.StringProperty(
        name="Post Script", default="",
        description="Script to run on objects after applying modifiers."
    )
    
    active : bpy.props.BoolProperty()
    use_last_props : bpy.props.BoolProperty()
    
    savepropnames = ('''
        filepath filename_ext file_type compression collection armature 
        alphanumeric_modifiers mesh_delimiter_start mesh_delimiter_end
        add_root_bone deform_only
        action_delimiter_start action_delimiter_end
        visible_only selected_only alphanumeric_only format_code format grouping batching fast_vb cache_vb
        pre_script post_script export_meshes export_skeleton export_animations''').split()
    
    def GetCheckout(self):
        # Can't have this in a prop update, otherwise it lags Blender
        self.filename_ext = "." + self.file_type.lower()
        self.filter_glob = "*." + self.file_type.lower()
        
        fpath = os.path.abspath(bpy.path.abspath(self.filepath))
        if self.filename_ext in fpath:
            fdir = os.path.dirname(fpath)
            fname = os.path.basename(fpath)
            fbasename, fext = os.path.splitext(fname)
        else:
            fdir = fpath
            fname = ""
            fbasename, fext = ("", self.filename_ext)
        
        objects = []
        files = [] # [ (filename, objects, armature, actions) ]
        
        if self.armature:
            armature = bpy.data.objects.get(self.armature)
            if armature:
                objects = list(armature.children)
        elif self.collection != "":
            collection = bpy.data.collections.get(self.collection)
            if collection:
                objects = list(collection.objects)
        else:
            objects = list(bpy.context.selected_objects)
        
        objects = [obj for obj in objects]
        
        armatures = []
        for obj in objects:
            if obj not in armatures and obj.type == 'ARMATURE':
                armatures.append(obj)
            elif obj.find_armature() and obj.find_armature() not in armatures:
                armatures.append(obj.find_armature())
        
        if self.batching == 'ARMATURE':
            files = [ [fbasename + f[2].name + fext, armature.children, armature, [x.action for x in armature.data.vbm_action_list if x.action]] for armature in armatures ]
        else:
            objects = [obj for obj in objects if obj.type in VALIDOBJTYPES]
            if armatures:
                armature = armatures[0]
                files = [ [fname, list(objects), armature, [x.action for x in armature.data.vbm_action_list if x.action] ] ]
            else:
                files = [ [fname, list(objects), None, [] ] ]
        
        if not self.export_meshes:
            files = [f[:1] + [[]] + f[2:] for f in files]
        if not self.export_skeleton:
            files = [f[:2] + [None] + f[3:] for f in files]
        if not self.export_animations:
            files = [f[:3] + [[]] + f[4:] for f in files]
        
        return files
    
    def invoke(self, context, event):
        [data.remove(x) for data in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures, bpy.data.actions) for x in data if x.get('__temp', False)]
        
        self.filename_ext = "." + self.file_type.lower()
        self.filter_glob = "*." + self.file_type.lower()
        
        if self.format == "":
            if context.scene.vbm.formats:
                self.format = context.scene.vbm.formats[0].name
        
        # Use Last Props
        obj = context.selected_objects[0] if context.selected_objects else context.active_object
        rig = bpy.data.objects.get(self.armature)
        collection = bpy.data.collections.get(self.collection)
        
        if collection:
            [setattr(self, k,v) for k,v in collection.get('VBM_LASTEXPORT', {}).items()]
            self.collection = collection.name
        elif rig:
            [setattr(self, k,v) for k,v in rig.get('VBM_LASTEXPORT', {}).items()]
            self.armature = rig.name
        elif obj:
            [setattr(self, k,v) for k,v in obj.get('VBM_LASTEXPORT', {}).items()]
        
        # Call Browser Dialog
        if self.dialog:
            self.items_collections.clear()
            def ParseCollections(c):
                for x in c.children:
                    self.items_collections.add().name = x.name
                    ParseCollections(x)
            
            ParseCollections(context.scene.collection)
            
            self.items_armatures.clear()
            for obj in bpy.context.scene.collection.all_objects:
                if obj.type == 'ARMATURE':
                    self.items_armatures.add().name = obj.name
            return super().invoke(context, event)
        else:
            return self.execute(context)
    
    def draw(self, context):
        vbm = context.scene.vbm
        layout = self.layout
        r = layout.row()
        r.prop(self, 'file_type', expand=True)
        
        # Data
        b = layout.box().column(align=True)
        r = b.row(align=True)
        r.enabled = self.file_type == 'VBM'
        r.label(text="VBM:")
        r = r.row(align=True)
        r.scale_x = 2
        r.prop(self, 'export_meshes', text="Meshes", toggle=True)
        r.prop(self, 'export_skeleton', text="Skeleton", toggle=True)
        r.prop(self, 'export_animations', text="Animations", toggle=True)
        
        b.separator()
        b.prop(self, 'compression')
        
        c = layout.column(align=True)
        r = c.row(align=True)
        r.enabled = self.armature == ""
        r.prop_search(self, 'collection', self, 'items_collections', icon='OUTLINER_COLLECTION')
        c.prop_search(self, 'armature', self, 'items_armatures', icon='ARMATURE_DATA')
        
        c = layout.column(align=True)
        c.prop(self, 'batching')
        c.prop(self, 'grouping')
        
        bc = layout.column(align=True)
        
        # Meshes
        b = bc.box()
        r = b.row(align=True)
        r.prop(self, 'menu_vbuffer', icon='MESH_DATA')
        
        if self.menu_vbuffer:
            c = b.column(align=True)
            c.prop_search(self, "format", vbm, 'formats')
            
            format = vbm.formats.get(self.format)
            if format:
                format.DrawPanel(c, False)
            c = b.column(align=True)
            cc = c.column(align=True)
            cc.use_property_split = True
            cc.prop_search(self, "pre_script", bpy.data, 'texts')
            cc.prop_search(self, "post_script", bpy.data, 'texts')
            rr = c.row()
            rr.prop(self, "fast_vb")
            rr.prop(self, "cache_vb")
            rr = c.row()
            rr.prop(self, "alphanumeric_modifiers")
        else:
            r.prop_search(self, "format", vbm, 'formats', text="")
        
        # Skeleton
        b = bc.box()
        r = b.row()
        r.prop(self, 'menu_skeleton', icon='ARMATURE_DATA')
        
        if self.menu_skeleton:
            c = b.column(align=True)
            r = c.row()
            r.enabled = self.armature != ""
            r.prop(self, 'deform_only')
            r.prop(self, 'add_root_bone')
        
        # Checkout
        b = layout.box().column(align=True)
        
        if self.menu_checkout:
            b.prop(self, 'menu_checkout', icon='CURRENT_FILE')
            b.separator()
            
            bb = b.box().column(align=True)
            bb.scale_y = 0.8
            bb.label(text="Delimiters:")
            
            r = bb.row(align=True)
            r.label(text="", icon='OUTLINER_OB_MESH')
            rr = r.row(align=True)
            rr.scale_x = 1.1
            rr.prop(self, 'mesh_delimiter_start', text="", icon='TRACKING_CLEAR_BACKWARDS')
            rr.prop(self, 'mesh_delimiter_end', text="", icon='TRACKING_CLEAR_FORWARDS')
            r.prop(self, 'mesh_delimiter_show', text="", icon='HIDE_OFF' if self.mesh_delimiter_show else 'HIDE_ON')
            
            r = bb.row(align=True)
            r.label(text="", icon='ACTION')
            rr = r.row(align=True)
            rr.scale_x = 1.1
            rr.prop(self, 'action_delimiter_start', text="", icon='TRACKING_CLEAR_BACKWARDS')
            rr.prop(self, 'action_delimiter_end', text="", icon='TRACKING_CLEAR_FORWARDS')
            r.prop(self, 'action_delimiter_show', text="", icon='HIDE_OFF' if self.action_delimiter_show else 'HIDE_ON')
            
            r = b.row(align=True)
            r.prop(self, 'visible_only', icon='HIDE_OFF', toggle=True)
            r.prop(self, 'selected_only', icon='RESTRICT_SELECT_OFF', toggle=True)
            r.prop(self, 'alphanumeric_only', text="", icon='SORTALPHA', toggle=True)
            
            c = b.column(align=True)
            c.scale_y = 0.75
            
            # Draw Checkout
            def FixName(name, delimstart, delimend):
                if delimstart and delimstart in name:
                    name = name[name.find(delimstart)+len(delimstart):]
                if delimend and delimend in name:
                    name = name[:name.find(delimend)]
                return name
                
            for fname, fobjects, farmature, factions in self.GetCheckout():
                c.label(text=fname)
                r = c.row(align=True)
                r.label(text="", icon='BLANK1')
                cc = r.column(align=True)
                
                # Armature
                if farmature:
                    cc.label(text=farmature.name, icon='ARMATURE_DATA')
                
                # Meshes
                for obj in fobjects:
                    rr = cc.row(align=True)
                    rr.enabled = (
                        (not self.visible_only or obj.visible_get()) and
                        (not self.selected_only or obj.select_get()) and
                        (not self.alphanumeric_only or obj.name[0] in 'qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890')
                    )
                    
                    name = obj.name
                    if self.mesh_delimiter_show:
                        name = FixName(name, self.mesh_delimiter_start, self.mesh_delimiter_end)
                    
                    rr.label(text=name, icon=obj.type+'_DATA')
                    rr.label(text="", icon='HIDE_OFF' if obj.visible_get() else 'HIDE_ON')
                    rr.label(text="", icon='RESTRICT_SELECT_OFF' if obj.select_get() else 'RESTRICT_SELECT_ON')
                
                # Actions
                for action in factions:
                    name = action.name
                    if self.action_delimiter_show:
                        name = FixName(name, self.action_delimiter_start, self.action_delimiter_end)
                    cc.label(text=name, icon='ACTION')
        else:
            r = b.row(align=True)
            r.prop(self, 'menu_checkout', icon='CURRENT_FILE')
            r.separator()
            r.prop(self, 'visible_only', text="", icon='HIDE_OFF', toggle=True)
            r.prop(self, 'selected_only', text="", icon='RESTRICT_SELECT_OFF', toggle=True)
    
    def execute(self, context):
        vbm = context.scene.vbm
        
        self.filename_ext = "." + self.file_type.lower()
        fpath = os.path.abspath(bpy.path.abspath(self.filepath))
        fpath = bpy.path.ensure_ext(fpath, self.filename_ext)
        if self.filename_ext in fpath:
            fdir = os.path.dirname(fpath) + "/"
            fname = os.path.basename(fpath)
            fbasename, fext = os.path.splitext(fname)
        else:
            fdir = fpath + "/"
            fname = ""
            fbasename, fext = ("", self.filename_ext)
        files = self.GetCheckout()
        
        active = context.active_object
        format = vbm.formats.get(self.format)
        
        deformonly = self.deform_only
        usezerobone = self.add_root_bone
        boneorder = []
        
        delims = [self.mesh_delimiter_start, self.mesh_delimiter_end]
        
        sc = context.scene
        
        # Save Last Props
        obj = context.selected_objects[0] if context.selected_objects else context.active_object
        rig = bpy.data.objects.get(self.armature)
        collection = bpy.data.collections.get(self.collection)
        
        saveprops = {k: getattr(self, k) for k in self.savepropnames}
        if format:
            saveprops['format_code'] = format.format_code
        
        if collection:
            collection['VBM_LASTEXPORT'] = saveprops
        elif rig:
            rig['VBM_LASTEXPORT'] = saveprops
        else:
            for obj in context.selected_objects:
                obj['VBM_LASTEXPORT'] = saveprops
        
        def FixName(name, delimstart, delimend):
            if delimstart and delimstart in name:
                name = name[name.find(delimstart)+len(delimstart):]
            if delimend and delimend in name:
                name = name[:name.find(delimend)]
            return name
        
        # Vertex Buffer
        if self.file_type == 'VB':
            for fname, objects, armature, actions in files:
                filepath = fdir + fname
                objects = [obj for obj in objects if (
                    (not self.visible_only or obj.visible_get()) and
                    (not self.selected_only or obj.select_get()) and
                    (not self.alphanumeric_only or obj.name[0] in 'qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890')
                )]
                
                vbdata = context.scene.vbm.MeshToVB(
                    objects, 
                    format if format else self.format_code,
                    pre_script=self.pre_script,
                    post_script=self.post_script,
                    use_cache=self.cache_vb,
                    fast=self.fast_vb,
                    alphanumeric_modifiers=self.alphanumeric_modifiers,
                    apply_armature=True,
                    )
                
                outbytes = b''.join([vbmeta[0] for name, vbmeta in vbdata.items()])
                
                rawlen = len(outbytes)
                
                if filepath != "":
                    if self.compression != 0:
                        outbytes = zlib.compress(outbytes, self.compression)
                    
                    print("> Writing to:", filepath)
                    f = open(filepath, 'wb')
                    f.write(outbytes)
                    f.close()
                
                outlen = [rawlen, len(outbytes)]
                print("Objects:", len(objects))
                print(
                    "Data of size %.2fKB (%.2f%% of original size) written to \"%s\"" % 
                    (outlen[1] / 1000, 100.0 * outlen[1] / outlen[0], filepath) 
                    )
                
            self.report({'INFO'}, "> Vertex Buffer Export Complete")
        # VBM
        elif self.file_type == 'VBM':
            Pack = struct.pack
            PackString = lambda s: Pack('B', len(s)) + b''.join([Pack('B', ord(c)) for c in s] )
            PackMatrix = lambda m: b''.join([Pack('f', x) for v in m.copy().transposed() for x in v])
            
            for fname, objects, armature, actions in files:
                filepath = fdir + fname
                objects = [obj for obj in objects if (
                    (not self.visible_only or obj.visible_get()) and
                    (not self.selected_only or obj.select_get()) and
                    (not self.alphanumeric_only or obj.name[0] in 'qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890')
                )]
                
                bonedata = {}
                
                # Data order: Header, VBs, Skeleton, Animations
                # Skeleton is read first here to get bone order
                
                # Skeleton --------------------------------------------------------
                outskeleton = b''
                
                parentmap = {}
                if armature:
                    parentmap = vbm.DeformArmatureMap(armature) if deformonly else {b.name: b.parent.name if b.parent else "" for b in armature.data.bones}
                    boneorder = list(parentmap.keys())
                
                if armature and self.export_skeleton:
                    print("> Creating Skeleton Data")
                    matidentity = armature.matrix_world.copy()
                    matidentity.identity()
                    
                    bones = [armature.data.bones[bname] for bname in parentmap.keys()]
                    bonemat = {b.name: b.matrix_local.copy() for b in bones}
                    bonematinv = {b: m.copy().inverted() for b,m in bonemat.items()}
                    parentmatinv = {b: bonematinv[parentmap[b]].copy() if parentmap.get(b) else matidentity for b in bonematinv.keys()}
                    
                    numbones = len(boneorder)
                    outskeleton += Pack('I', numbones + usezerobone)
                    
                    # Bone Names
                    if usezerobone:
                        outskeleton += PackString("")
                    for bname in boneorder:
                        outskeleton += PackString(bname)
                    # Parent Indices
                    if usezerobone:
                        outskeleton += Pack('I', 0)
                    for b in boneorder:
                        outskeleton += Pack('I', (boneorder.index(parentmap[b]) + usezerobone) if parentmap.get(b) != None else 0)
                    # Local Matrices
                    if usezerobone:
                        outskeleton += PackMatrix(matidentity)
                    for b in boneorder:
                        outskeleton += PackMatrix((parentmatinv[b] @ bonemat[b]))
                    # Inverse Transforms
                    if usezerobone:
                        outskeleton += PackMatrix(matidentity)
                    for b in boneorder: 
                        outskeleton += PackMatrix(bonematinv[b])
                else:
                    outskeleton += Pack('I', 0)
                
                # VBs -------------------------------------------------------------
                outvbs = b''
                
                vbmap = {}
                
                workingobjects = []
                apply_armature = (armature is not None) and not self.export_skeleton
                grouping = self.grouping
                
                if grouping == 'ACTION':
                    apply_armature = True
                
                for obj in objects:
                    workingobjects.append(obj)
                
                if self.export_meshes:
                    if usezerobone:
                        boneorder = [""] + boneorder
                    
                    print("> Creating VB Data")
                    if grouping == 'OBJECT':
                        for obj in objects:
                            for name,vbmeta in context.scene.vbm.MeshToVB(
                                [obj], 
                                format if format else self.format_code,
                                boneorder=boneorder,
                                apply_armature=apply_armature,
                                pre_script=self.pre_script,
                                post_script=self.post_script,
                                use_cache=self.cache_vb,
                                fast=self.fast_vb,
                                alphanumeric_modifiers=self.alphanumeric_modifiers,
                            ).items():
                                name = FixName(name, self.mesh_delimiter_start, self.mesh_delimiter_end)
                                
                                vbmap[name] = vbmap.get(name, [b'', 0])
                                vbmap[name][0] += vbmeta[0]
                                vbmap[name][1] += vbmeta[1]
                    elif grouping == 'MATERIAL':
                        print("> MATERIAL grouping not implemented")
                    elif grouping == 'ACTION':
                        frame_range = (sc.frame_start, sc.frame_end)
                        
                        # For each frame...
                        for f in range(frame_range[0], frame_range[1]+1):
                            print("> Frame:", f)
                            sc.frame_set(f)
                            
                            vb = b''
                            numelements = 0
                            
                            # For each object...
                            for k,vbmeta in vbm.MeshToVB(
                                objects, 
                                format if format else self.format_code,
                                boneorder=boneorder,
                                apply_armature=apply_armature,
                                pre_script=self.pre_script,
                                post_script=self.post_script,
                                use_cache=False,
                                fast=self.fast_vb,
                            ).items():
                                vb += vbmeta[0]
                                numelements += vbmeta[1]
                            
                            vbmap[str(f)] = (vb, numelements)
                
                outvbs += Pack('I', len(vbmap))
                
                formatserialized = vbm.ParseFormatString(format if format else self.format_code) if self.export_meshes else []
                
                outvbs += Pack('B', len(formatserialized))
                for k, size, layer, srgb, defaultvalue in formatserialized:
                    outvbs += Pack('B', VBFTypeIndex[k])
                    outvbs += Pack('B', size)
                
                for name, vbmeta in vbmap.items():
                    outvbs += PackString(name)
                
                for name, vbmeta in vbmap.items():
                    vb, numvertices = vbmeta
                    outvbs += Pack('I', len(vb))
                    outvbs += Pack('I', numvertices)
                    outvbs += vb
                
                # Animation --------------------------------------------------------
                outanimations = b''
                
                if armature and self.export_animations:
                    print("> Creating Animation Data")
                    matidentity = armature.matrix_world.copy()
                    matidentity.identity()
                    lastaction = armature.animation_data.action if armature.animation_data else None
                    
                    numactions = len(actions)
                    fps = context.scene.render.fps
                    
                    outanimations += Pack('I', numactions) # numactions
                    
                    workingrig = vbm.CreateDeformArmature(armature)
                    workingrig['__temp'] = True
                    workingrig.data['__temp'] = True
                    context.view_layer.objects.active = workingrig
                    
                    if not workingrig.animation_data:
                        workingrig.animation_data_create()
                    
                    armature.data.pose_position = 'POSE'
                    workingrig.data.pose_position = 'POSE'
                    
                    for action in actions:
                        actionchecksum = int(sum((
                            [ord(x) for fc in action.fcurves for dp in fc.data_path for x in dp] + 
                            [x for fc in action.fcurves for k in fc.keyframe_points for x in k.co] + 
                            [action.frame_start, action.frame_end]
                        )))
                        
                        if actionchecksum != action.get('VBM_CHECKSUM', 0) or action.get('VBM_BAKED', "") not in bpy.data.actions.keys():
                            baked = bpy.data.actions.get(action.get('VBM_BAKED', ""))
                            if baked:
                                bpy.data.actions.remove(baked)
                            
                            action['VBM_CHECKSUM'] = actionchecksum
                            
                            workingaction = action.copy()
                            workingrig.select_set(True)
                            workingrig.animation_data.action = workingaction
                            workingaction['__temp'] = True
                            
                            armature.animation_data.action = workingaction
                            
                            [pb.matrix_basis.identity() for pb in workingrig.pose.bones]
                            [pb.matrix_basis.identity() for pb in armature.pose.bones]
                            
                            context.view_layer.update()
                            
                            print("> Baking action:", workingaction.name)
                            bpy.ops.nla.bake(
                                frame_start=int(action.frame_start),
                                frame_end=int(action.frame_end), 
                                step=1, 
                                only_selected=False, 
                                visual_keying=True, 
                                clear_constraints=False, 
                                clear_parents=False, 
                                use_current_action=True, 
                                clean_curves=True,
                                bake_types={'POSE'} 
                                )
                            print("> Bake complete")
                            
                            workingaction = workingrig.animation_data.action
                            workingaction['__temp'] = False
                            workingaction.name = "~" + action.name + "__VBM_BAKED"
                            action['VBM_BAKED'] = workingaction.name
                        else:
                            workingaction = bpy.data.actions.get(action['VBM_BAKED'])
                        
                        framerange = (action.frame_start, action.frame_end)
                        duration = framerange[1]-framerange[0]+1
                        
                        boneorder = tuple(parentmap.keys())
                        basebonenames = [x.replace('DEF-', "") for x in boneorder]
                        
                        fcurves = workingaction.fcurves
                        bundles = {}
                        bundlesbone = {}
                        bundlesnonbone = {}
                        
                        # Build Curves
                        for fc in fcurves:
                            dp = fc.data_path
                            curvename = dp
                            bonename = dp[dp.find('"')+1:dp.rfind('"')]
                            
                            if bonename and bonename in boneorder:
                                curvename = bonename
                                if '.location' in dp:
                                    curvename += '.location'
                                elif '.scale' in dp:
                                    curvename += '.scale'
                                elif '.rotation_quaternion' in dp:
                                    curvename += '.rotation_quaternion'
                                elif '.' in dp[dp.find(bonename)+len(bonename):]:
                                    curvename += dp[dp.rfind('.'):]
                            elif curvename[:2] == '["':
                                curvename = curvename[2:-2]
                            
                            if 'pose.bones' not in curvename:
                                kpoints = fc.keyframe_points
                                
                                if curvename not in bundles.keys():
                                    bundles[curvename] = []
                                while len(bundles[curvename]) < fc.array_index+1:
                                    bundles[curvename].append([])
                                
                                bundles[curvename][fc.array_index] = [k.co for k in kpoints]
                        
                        
                        bundlelist = list(bundles.items())
                        bundlelist.sort(key=lambda b: (
                                boneorder.index(b[0][:b[0].rfind('.')]) * 10 +
                                ( ('location' in b[0])*1 + ('rotation_quaternion' in b[0])*2 + ('scale' in b[0])*3 )
                            )
                            if b[0][:b[0].rfind('.')] in boneorder else 1000000)
                        
                        # Write Curves
                        outanimations += PackString(FixName(action.name, self.action_delimiter_start, self.action_delimiter_end)) # Actionname
                        outanimations += Pack('f', context.scene.render.fps) # FPS
                        outanimations += Pack('f', duration) # Duration
                        outanimations += Pack('I', len(bundles)) # Number of curves
                        outanimations += Pack('I', 0) # Number of markers
                        
                        for curvename, channels in bundlelist:
                            outanimations += PackString(curvename) # Curve Name
                            outanimations += Pack('1I', len(channels)) # numchannels
                            
                            for channelindex, channel in enumerate(channels):
                                outanimations += Pack('1I', len(channel)) # numkeyframes
                                
                                positions = numpy.array([x[0] for x in channel])
                                positions /= duration
                                
                                outanimations += b''.join([Pack('f', x) for x in positions]) # positions[]
                                outanimations += b''.join([Pack('f', x[1]) for x in channel]) # values[]
                                outanimations += b''.join([Pack('B', 1) for x in channel]) # interpolations[]
                    
                    [pb.matrix_basis.identity() for pb in armature.pose.bones]
                    if armature.animation_data:
                        armature.animation_data.action = lastaction
                        
                else:
                    outanimations += Pack('I', 0)
                
                # Output -----------------------------------------------------
                outbytes = b''
                
                outbytes += b'VBM' + Pack('B', VBMVERSION)
                outbytes += Pack('B', 0)
                
                outbytes += Pack('I', len(outvbs) + len(Pack('I', 0)) * 3)
                outbytes += Pack('I', len(outskeleton) + len(Pack('I', 0)) * 2)
                outbytes += Pack('I', len(outanimations) + len(Pack('I', 0)) * 1)
                
                outbytes += outvbs
                outbytes += outskeleton
                outbytes += outanimations
                
                rawlen = len(outbytes)
                
                if filepath != "":
                    if self.compression != 0:
                        outbytes = zlib.compress(outbytes, self.compression)
                    
                    print("> Writing to:", filepath)
                    f = open(filepath, 'wb')
                    f.write(outbytes)
                    f.close()
                
                outlen = [rawlen, len(outbytes)]
                print("Objects:", len(objects), "-> Meshes:", len(vbmap.items()), "| Bones:", len(boneorder), "| Actions:", len(actions))
                print(
                    "Data of size %.2fKB (%.2f%% of original size) written to \"%s\"" % 
                    (outlen[1] / 1000, 100.0 * outlen[1] / outlen[0], filepath) 
                    )
            
            self.report({'INFO'}, "> VBM Export Complete")
        
        context.view_layer.objects.active = active
        active.select_set(True)
        [data.remove(x) for data in [bpy.data.meshes, bpy.data.armatures] for x in data if x.get('__temp', False)]
        return {'FINISHED'}
classlist.append(VBM_OT_ExportVBM)

'# =========================================================================================================================='
'# UI LIST'
'# =========================================================================================================================='

class VBM_UL_Format(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=True)
        r.prop(item, 'name', text="", emboss=False)
        
        for att in item.attributes:
            r.label(text="", icon=VBFIcon[att.type])
        for i in range(0, 8-len(item.attributes)):
            r.label(text="", icon='BLANK1')
classlist.append(VBM_UL_Format)

# ------------------------------------------------------------------------------------------
class VBM_UL_Format_Attribute(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=True)
        
        r.prop_menu_enum(item, 'type', text="", icon=VBFIcon[item.type])
        r.separator()
        r.label(text=VBFName[item.type])
        
        # Padding
        if item.type == VBF_PAD:
            for i in range(0, 4):
                r.prop(item, 'padding_floats', index=i, text="", emboss=i<item.size)
        elif item.type == VBF_PAB:
            for i in range(0, 4):
                r.prop(item, 'padding_bytes', index=i, text="", emboss=i<item.size)
        elif item.type == VBF_GRO:
            obj = context.view_layer.objects.active
            if obj and obj.type == 'MESH':
                if USE_ATTRIBUTES:
                    r.prop_search(item, 'layer', obj, 'vertex_groups', results_are_suggestions=True, text="")
                else:
                    r.prop_search(item, 'layer', obj, 'vertex_groups', text="")
            else:
                r.prop(item, 'layer', text="")
        # Layer
        elif item.type in VBFUseVCLayer+VBFUseUVLayer:
            obj = context.view_layer.objects.active
            if obj and obj.type == 'MESH':
                colorpropname = 'color_attributes' if USE_ATTRIBUTES else 'vertex_colors'
                r.prop_search(item, 'layer', obj.data, colorpropname if item.type in VBFUseVCLayer else 'uv_layers', results_are_suggestions=True, text="") if USE_ATTRIBUTES \
                else r.prop_search(item, 'layer', obj.data, colorpropname if item.type in VBFUseVCLayer else 'uv_layers', text="")
            else:
                r.prop(item, 'layer', text="")
            
            op = r.operator('vbm.format_attribute_set_layer', text="", icon="RESTRICT_RENDER_OFF")
            op.index = context.scene.vbm.formats_index
            op.attribute_index = index
            op.layer = LYR_RENDER
            op = r.operator('vbm.format_attribute_set_layer', text="", icon="RESTRICT_SELECT_OFF")
            op.index = context.scene.vbm.formats_index
            op.attribute_index = index
            op.layer = LYR_SELECT
            
            if item.type in VBFUseVCLayer:
                r.separator()
                r.prop(item, 'convert_to_srgb', text='', toggle=False, icon='BRUSHES_ALL' if item.convert_to_srgb else 'IPO_SINE')
        
        if 1 or item.type in VBFUseSizeControl:
            rr = r.row()
            rr.scale_x = 0.4
            rr.prop(item, 'size', text="")
classlist.append(VBM_UL_Format_Attribute)

# ------------------------------------------------------------------------------------------
class VBM_UL_BoneDissolve(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=True)
        if item.depth > 0:
            rr = r.row(align=True)
            [rr.label(text="", icon='THREE_DOTS') for i in range(0, item.depth)]
        r.prop(item, 'dissolve', text=item.name, emboss=True)
classlist.append(VBM_UL_BoneDissolve)

# ------------------------------------------------------------------------------------------
class VBM_UL_ActionList(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row()
        if item.action:
            r.prop(item.action, 'name', text="", icon='ACTION', emboss=False)
            
            rr = r.row(align=True)
            rr.scale_x = 0.6
            rr.prop(item.action, 'frame_start', text="S:")
            rr.prop(item.action, 'frame_end', text="E:")
            r.operator('vbm.actionlist_play', text="", icon='PLAY').action = item.action.name
        else:
            r.label(text="(Missing Action)", icon='QUESTION')
            r.prop(item, 'action')
classlist.append(VBM_UL_ActionList)

'# =========================================================================================================================='
'# PANEL'
'# =========================================================================================================================='

class VBM_PT_Master(bpy.types.Panel):
    bl_label = "VBM Exporter"
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "scene"
    
    def draw(self, context):
        vbm = context.scene.vbm
        
        layout = self.layout
        
        r = layout.row()
        r.prop(vbm, 'write_to_cache')
        r.operator('vbm.clear_cache')
        
        b = layout.box().column(align=True)
        
        r = b.row(align=False)
        r.label(text="Export Selected: ")
        obj = context.selected_objects[0] if context.selected_objects else context.active_object
        
        lastpath = obj.get('VBM_LASTPATH', None) if obj else None
        
        op = r.operator('vbm.export_vbm', text="VB", icon='OUTLINER_DATA_MESH')
        op.file_type = 'VB'
        if lastpath:
            op.filepath = lastpath
        op.dialog = True
        op.format_code = ""
        
        op = r.operator('vbm.export_vbm', text="VBM", icon='MOD_ARRAY')
        op.file_type = 'VBM'
        if lastpath:
            op.filepath = lastpath
        op.dialog = True
        op.format_code = ""
        
        # Last Export
        def OpFromProps(idstruct, r, icon, collection, rig):
            r.label(text=idstruct.name if idstruct else " ", icon=icon)
            
            # Last Props
            lastprops = idstruct.get('VBM_LASTEXPORT', None) if idstruct else None
            if lastprops:
                path = lastprops['filepath']
                path = "..." + path[-24:]
                rr = r.row()
                rr.scale_x = 1.3
                op = rr.operator('vbm.export_vbm', text=path)
                op.dialog = True
                op.format = ""
                op.file_type = lastprops['file_type']
                op.collection, op.armature = (collection, rig)
                
                r.separator()
                
                op = r.operator('vbm.export_vbm', text="", icon='SOLO_ON')
                op.dialog = False
                op.format = ""
                op.file_type = lastprops['file_type']
                op.collection, op.armature = (collection, rig)
            else:
                rr = r.row(align=True)
                rr.scale_x = 0.7
                op = rr.operator('vbm.export_vbm', text="VB", icon='OUTLINER_DATA_MESH')
                op.dialog, op.format_code, op.file_type = (True, '', 'VB')
                op.collection, op.armature = (collection, rig)
                rr.separator()
                op = rr.operator('vbm.export_vbm', text="VBM", icon='MOD_ARRAY')
                op.dialog, op.format_code, op.file_type = (True, '', 'VBM')
                op.collection, op.armature = (collection, rig)
            
            
            return op
        
        obj = context.active_object
        rig = (obj if obj.type == 'ARMATURE' else obj.find_armature()) if obj else None
        
        b.separator()
        c = b.column(align=True)
        op = OpFromProps(obj, b.row(align=True), 'RESTRICT_SELECT_OFF', '', '')
        op = OpFromProps(rig, b.row(align=True), 'ARMATURE_DATA', "", rig.name if rig else '')
        op = OpFromProps(context.collection, b.row(align=True), 'OUTLINER_COLLECTION', context.collection.name, "")
classlist.append(VBM_PT_Master)

# ------------------------------------------------------------------------------------------
class VBM_PT_Format(bpy.types.Panel):
    bl_label = "Vertex Formats"
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "scene"
    bl_parent_id = 'VBM_PT_Master'
    
    def draw(self, context):
        vbm = context.scene.vbm
        
        layout = self.layout
        
        r = layout.row(align=True)
        c = r.column(align=True)
        c.template_list("VBM_UL_Format", "", vbm, "formats", vbm, "formats_index", rows=3)
        r.separator()
        
        c = r.column(align=True)
        c.operator('vbm.format_add', text="", icon='ADD')
        c.operator('vbm.format_remove', text="", icon='REMOVE').index = vbm.formats_index
        c.separator()
        c.operator('vbm.format_move', text="", icon='TRIA_UP').move_down = False
        c.operator('vbm.format_move', text="", icon='TRIA_DOWN').move_down = True
classlist.append(VBM_PT_Format)

# ------------------------------------------------------------------------------------------
class VBM_PT_Format_Attributes(bpy.types.Panel):
    bl_label = "Active Format"
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "scene"
    bl_parent_id = 'VBM_PT_Master'
    
    def draw(self, context):
        layout = self.layout
        vbm = context.scene.vbm
        
        r = layout.row(align=True)
        
        
        if len(vbm.formats) > 0:
            format = vbm.formats[vbm.formats_index]
            format.DrawPanel(layout, True)
        else:
            layout.label(text="(No Active Format)")
classlist.append(VBM_PT_Format_Attributes)

# ------------------------------------------------------------------------------------------
class VBM_PT_BoneDissolve(bpy.types.Panel):
    bl_label = "Bone Dissolves"
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "data"
    
    def draw(self, context):
        vbm = context.scene.vbm
        layout = self.layout
        obj = context.object
        if obj and obj.type == 'ARMATURE':
            c = layout.column()
            c.operator('vbm.bonedissolve_initialize')
            
            dissolvelist = obj.data.vbm_dissolve_list
            cc = c.column(align=True)
            cc.scale_y = 0.75
            cc.template_list("VBM_UL_BoneDissolve", "", dissolvelist, "dissolves", dissolvelist, "index", rows=3)
            
            cc = c.column()
            if dissolvelist:
                n = len(dissolvelist.dissolves)
                cc.label(text="Used Bones: %d / %d" % (n-sum([d.dissolve for d in dissolvelist.dissolves]), n))
classlist.append(VBM_PT_BoneDissolve)

# ------------------------------------------------------------------------------------------
class VBM_PT_ActionList(bpy.types.Panel):
    bl_label = "Action List"
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "scene"
    bl_parent_id = 'VBM_PT_Master'
    
    def draw(self, context):
        layout = self.layout
        vbm = context.scene.vbm
        c = layout.column(align=True)
        
        obj = context.active_object
        rig = (obj if obj.type == 'ARMATURE' else obj.find_armature()) if obj else None
        if rig and rig.type == 'ARMATURE':
            armature = rig.data
            actionlist = armature.vbm_action_list
            index = armature.vbm_action_list_index
            
            r = c.row(align=True)
            r.label(text=rig.name, icon='ARMATURE_DATA')
            r.operator('vbm.actionlist_from_pattern').dialog = True
            r.operator('vbm.actionlist_from_pattern', text="", icon='SOLO_ON').dialog = False
            
            r = c.row()
            cc = r.column(align=True)
            cc.scale_y = 0.75
            cc.template_list("VBM_UL_ActionList", "", armature, "vbm_action_list", armature, "vbm_action_list_index", rows=6)
            
            cc = r.column(align=True)
            cc.scale_y = 0.9
            cc.operator('vbm.actionlist_add', text="", icon='NLA_PUSHDOWN').action = rig.animation_data.action.name if rig.animation_data and rig.animation_data.action else ""
            cc.operator('vbm.actionlist_duplicate', text="", icon='ADD')
            cc.operator('vbm.actionlist_remove', text="", icon='REMOVE').index = index
            cc.separator()
            cc.operator('vbm.actionlist_move', text="", icon='TRIA_UP').move_down = False
            cc.operator('vbm.actionlist_move', text="", icon='TRIA_DOWN').move_down = True
            cc.separator()
            cc.operator('vbm.actionlist_clear', text="", icon='X')
classlist.append(VBM_PT_ActionList)

'# =========================================================================================================================='
'# MASTER'
'# =========================================================================================================================='

'-----------------------------------------------------------------------------------------------------------'
class VBM_PG_Master(bpy.types.PropertyGroup):
    formats : bpy.props.CollectionProperty(name="Formats", type=VBM_PG_Format)
    formats_index : bpy.props.IntProperty(name="Formats Index")
    
    export_lists : bpy.props.CollectionProperty(name="Export Lists", type=VBM_PG_ExportList)
    export_lists_index : bpy.props.IntProperty(name="Export Lists Index")
    
    write_to_cache : bpy.props.BoolProperty(
        name="Write To Cache", default=True,
        description="Save export data on object to speed up repeat exports")
    
    def ToFormatCode(self, formatserialized):
        fstring = ""
        for att in formatserialized: # [key, size, layer, srgb, default_value]
            k, size, layer, srgb, default_value = att
            s = k
            s += str(size)
            
            if layer == LYR_SELECT:
                s += "-select"
            elif layer != LYR_RENDER:
                s += '@"' + layer + '"'
            if not srgb:
                s += "-linear"
            s += "=("+("%.2f,"*size)[:-1] % default_value[:size]+")"
            
            fstring += s + " "
        return fstring
    
    def ParseFormatString(self, format):
        attribparams = []
        # Parse Format
        if isinstance(format, str):
            attribstrings = []
            i = 0
            istart = 0
            format += " "
            n = len(format)
            while i < n:
                if format[i] == " ":
                    s = format[istart:i]
                    if sum([x != " " for x in s]) > 0:
                        attribstrings.append(s)
                    istart = i + 1
                elif format[i] == "(":
                    while i < n:
                        if format[i] == ")":
                            break
                        i += 1
                i += 1
            
            for att in attribstrings:
                n = len(att)
                i = 0
                
                k = ""
                while i < n:
                    if att[i].lower() in "qwertyuiopasdfghjklzxcvbnm":
                        k += att[i]
                        i += 1
                    else:
                        break
                if k.upper() not in VBFTypes:
                    print('> Unknown format type "%s"' % k)
                    continue
                
                k = k.upper()
                size = VBFSize[k]
                layer = LYR_RENDER
                srgb = True
                defaultvalue = [0,0,0,0]
                
                # Parse flags
                while i < n:
                    if att[i] in '0123456789': # Size
                        size = int(att[i])
                    elif att[i] == '=': # Default Value
                        i += 1
                        line = ""
                        defaultindex = 0
                        while i < n:
                            if att[i] in '0123456789.-':
                                line += att[i]
                            elif att[i] == ',' or att[i] == ")":
                                defaultvalue[defaultindex] = float(line)
                                defaultindex += 1
                                line = ""
                            if att[i] == ")":
                                break
                            i += 1
                    elif att[i] == "@": # Layer Name
                        i += 1
                        if att[i] in "\"'":
                            stopchar = att[i]
                            line = ""
                            i += 1
                            while i < n:
                                if att[i] == stopchar:
                                    break
                                else:
                                    line += att[i]
                                    i += 1
                            layer = line
                    elif att[i] == "-": # Flags
                        line = ""
                        i += 1
                        while i < n:
                            if att[i] == '-' or att[i] == " ":
                                i -= 1
                                break
                            else:
                                line += att[i]
                                i += 1
                        
                        line = line.lower()
                        if line == "srgb":
                            srgb = True
                        elif line == "linear":
                            srgb = False
                        elif line == "render":
                            layer = LYR_RENDER
                        elif line == "select":
                            layer = LYR_SELECT
                        elif line == "units":
                            defaultvalue = [x/255.0 for x in defaultvalue]
                        
                    i += 1
                
                attribparams.append((k, size, layer, srgb, list(defaultvalue)))
        else:
            attribparams = [(
                a.type, 
                a.size, 
                a.layer, 
                a.convert_to_srgb,
                a.padding_bytes if a.type in VBFUseBytes else a.padding_floats) 
            for a in format.attributes]
        return attribparams
    
    def DeformArmatureMap(self, armatureobj):
        deformmap = {}
        bones = armatureobj.data.bones
        deformbones = [b for b in bones if b.use_deform]
        
        for b in deformbones:
            #print(b.name, "-"*50)
            p = b.parent
            usedparents = []
            if p:
                if not p.use_deform:
                    p1 = p
                    while p and not p.use_deform:
                        usedparents.append(p)
                        d = bones.get(p.name.replace('ORG-', 'DEF-'))
                        #print(" linear:", p.name, d)
                        if d and d != b and (d.use_deform or d not in usedparents):
                            p = d
                        else:
                            p = p.parent
            
            #print(" ", p.name if p else None)
            deformmap[b.name] = p.name if p else None
        
        def CountParents(name, num=0):
            if name in deformmap.keys():
                return CountParents(deformmap[name], num+1)
            return num
        
        deformlist = [x for x in list(deformmap.items())]
        deformlist.sort(key=lambda x: CountParents(x[0]))
        deformmap = {k:v for k,v in deformlist}
        
        return deformmap

    def CreateDeformArmature(self, sourceobj, targetrig=None, collection=None, constraints=True):
        context = bpy.context
        workingarmature = bpy.data.armatures.new(name=sourceobj.data.name + '__deform')
        
        if targetrig:
            workingobj = targetrig
            targetrig.data = workingarmature
        else:
            workingobj = bpy.data.objects.new(sourceobj.name + '__deform', workingarmature)
            targetrig = workingobj
        
        workingobj['deform_source'] = sourceobj.name
        
        if collection == None:
            collection = context.scene.collection
        if workingobj not in list(collection.objects):
            collection.objects.link(workingobj)
        
        if not workingobj.animation_data:
            workingobj.animation_data_create()
        
        # Create armature that copy source's transforms -------------------------------------------------
        context.view_layer.objects.active = workingobj
        bpy.ops.object.mode_set(mode='OBJECT')
        
        # Get bone transforms
        rigbonemeta = { # { name: (head, tail, roll, connect, matrix_local) }
            b.name: (b.head_local.copy(), b.tail_local.copy(), b.AxisRollFromMatrix(b.matrix_local.to_3x3())[1], b.use_connect, b.matrix_local)
            for b in sourceobj.data.bones if (b.use_deform)
        }
        
        boneparents = self.DeformArmatureMap(sourceobj)
        
        bpy.ops.object.select_all(action='DESELECT')
        workingobj.select_set(True)
        context.view_layer.objects.active = workingobj
        bpy.ops.object.mode_set(mode='EDIT')
        
        editbones = workingobj.data.edit_bones
        
        # Create bones in working armature
        for bonename, meta in rigbonemeta.items():
            if bonename not in editbones.keys():
                editbones.new(name=bonename)
            b = editbones[bonename]
            b.head, b.tail, b.roll, b.use_connect = meta[:4]
            
        for b in editbones:
            if boneparents[b.name]:
                b.parent = editbones[boneparents[b.name]]
        
        # Make constraints to copy transforms
        bpy.ops.object.mode_set(mode='POSE')
        
        [b.constraints.remove(c) for b in workingobj.pose.bones for c in list(b.constraints)[::-1]]
        if constraints:
            for b in workingobj.pose.bones:
                [b.constraints.remove(c) for c in list(b.constraints)[::-1]]
                c = b.constraints.new(type='COPY_TRANSFORMS')
                c.target = sourceobj
                c.subtarget = b.name
        
        bpy.ops.object.mode_set(mode='OBJECT')
        
        return workingobj
    
    # Returns map {meshname: (vbdata, numvertices)}
    def MeshToVB(
        self, 
        objects, 
        format, 
        boneorder=[], 
        flip_uvs=True, 
        apply_armature=False, 
        pre_script=None, 
        post_script=None,
        use_cache=True,
        fast=False,
        alphanumeric_modifiers=True,
        ):
        outmap = {} # {mtl_name: data}
        mtlkey = {}
        
        context = bpy.context
        
        pre_script = bpy.data.texts.get(pre_script, None) if pre_script else None
        post_script = bpy.data.texts.get(post_script, None) if post_script else None
        
        attribparams = bpy.context.scene.vbm.ParseFormatString(format)
        vbmap = {}
        process_bones = sum([att[0] in (VBF_BON, VBF_BOB) for att in attribparams]) > 0
        process_tangents = sum([att[0] in (VBF_TAN, VBF_BTN) for att in attribparams]) > 0
        apply_armature = apply_armature and not process_bones
        fast = fast and not process_bones
        
        for mtl in [slot.material for obj in objects for slot in obj.material_slots if slot.material]:
            outmap[mtl.name] = []
        outmap[""] = []
        
        bonetoindex = {bname: i for i,bname in enumerate(boneorder)}
        
        def ManualDuplicate(src):
            obj = bpy.data.objects.new(name=src.name.replace("-", "_"), object_data=src.data.copy())
            obj['__temp'] = True
            obj.data['__temp'] = True
            bpy.context.scene.collection.objects.link(obj)
            
            obj.matrix_world = src.matrix_world.copy()
            
            for m1 in src.modifiers:
                if not alphanumeric_modifiers or m1.name[0] in 'qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890':
                    print(m1.name)
                    m2 = obj.modifiers.new(name=m1.name, type=m1.type)
                    for prop in [p.identifier for p in m1.bl_rna.properties if not p.is_readonly]:
                        setattr(m2, prop, getattr(m1, prop))
            return obj
        
        def ObjChecksum(obj):
            return int(sum(
                [alphanumeric_modifiers] + 
                [x for v in obj.data.vertices for x in ([xx for xx in v.co]+[xx for vge in v.groups for xx in (vge.group, vge.weight)])] +
                (
                    [x for lyr in obj.data.color_attributes for e in lyr.data for x in e.color] if USE_ATTRIBUTES else
                    [x for lyr in obj.data.vertex_colors for e in lyr.data for x in e.color]
                ) +
                [x for lyr in obj.data.uv_layers for e in lyr.data for x in e.uv] + 
                [x for v in obj.matrix_basis for x in v] + 
                ([
                    x 
                    for m in obj.modifiers 
                    for propname in [p.identifier for p in m.bl_rna.properties if not p.is_readonly] 
                    for x in [getattr(m, propname)] if isinstance(getattr(m, propname), (float, int))
                ]) + 
                ([x for b in armature.data.bones for v in b.matrix_local for x in v] if armature else []) +
                ([ord(x) for b in boneorder for x in b]) + 
                ([ObjChecksum(c) for c in obj.children] if obj.instance_type in ('VERTICES', 'FACES') else [])
            ))
        
        # Cache Key
        attribstr = ""
        
        for att in attribparams: # [key, size, layer, srgb, default_value]
            k, size, layer, srgb, default_value = att
            s = k[:3]
            s += str(size)
            if layer != LYR_RENDER:
                s += layer[:4]
            if srgb:
                s += "c"
            attribstr += s
        
        # Object Loop -------------------------------------------------------------------
        for sourceobj in objects:
            vbmesh = b''
            armature = sourceobj.find_armature()
            
            checksum = ObjChecksum(sourceobj)
            
            checksumkey = attribstr
            
            # Use Cached Data
            if use_cache and (sourceobj.get('VBSUM_'+checksumkey, 0) == checksum):
                vbmap[sourceobj.name] = (zlib.decompress(sourceobj['VBDAT_'+checksumkey]), sourceobj['VBNUM_'+checksumkey])
            else:
                instobjects = [sourceobj]
                
                if len(sourceobj.children) > 0:
                    if sourceobj.instance_type in ('VERTICES', 'FACES'):
                        insttype = sourceobj.instance_type
                        
                        bpy.ops.object.select_all(action='DESELECT')
                        sourceobj.select_set(True)
                        bpy.context.view_layer.objects.active = sourceobj
                        bpy.ops.object.duplicates_make_real(use_base_parent=True, use_hierarchy=True)
                        instobjects = [x for x in context.selected_objects if x not in objects]
                        for obj in instobjects:
                            obj['__temp'] = True
                            obj.data = obj.data.copy()
                            obj.data['__temp'] = True
                        sourceobj.instance_type = insttype
                
                # Matrix Loop ----------------------------------------------------------------
                vbinstances = []
                netnumelements = 0
                depsgraph = context.evaluated_depsgraph_get()
                
                for matrixindex, instobj in enumerate(instobjects):
                    # Fast = Use final evaluated mesh. No Pre Script or armature support
                    if fast:
                        obj = instobj.evaluated_get(depsgraph)
                        mesh = obj.to_mesh()
                        
                        bm = bmesh.new()
                        bm.from_mesh(mesh)
                        bmesh.ops.transform(bm, matrix=instobj.matrix_world)
                        bm.to_mesh(mesh)
                        bm.free()
                        
                    # Non-Fast = Modifiers, Pre Script, and armature support
                    else:
                        obj = ManualDuplicate(instobj)
                        obj.name = instobj.name + " "
                        bpy.ops.object.select_all(action='DESELECT')
                        obj.select_set(True)
                        bpy.context.view_layer.objects.active = obj
                        
                        if pre_script:
                            context.scene['VBMEXPORTACTIVE'] = True
                            exec(pre_script.as_string())
                            context.scene['VBMEXPORTACTIVE'] = False
                        
                        if not apply_armature:
                            armaturemodifiers = [m for m in obj.modifiers if m.type == 'ARMATURE' and m.show_viewport]
                            for m in armaturemodifiers:
                                m.use_vertex_groups = False
                        
                        obj.modifiers.new(name="Triangulate", type='TRIANGULATE').keep_custom_normals=True
                        bpy.ops.object.convert(target='MESH')
                        obj = bpy.context.active_object
                        obj.data['__temp'] = True
                        
                        outslots = [ [] for slot in obj.material_slots ]+[ [] ]
                        
                        bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
                        mesh = obj.data
                    
                    if post_script:
                        context.scene['VBMEXPORTACTIVE'] = True
                        exec(post_script.as_string())
                        context.scene['VBMEXPORTACTIVE'] = False
                    
                    # Collect data
                    mesh.calc_loop_triangles()
                    mesh.calc_normals_split()
                    
                    if mesh.uv_layers and process_tangents:
                        mesh.calc_tangents()
                    
                    numverts = len(mesh.vertices)
                    numpolys = len(mesh.loop_triangles)
                    numloops = len(mesh.loops)
                    numelements = numpolys * 3
                    nummaterialslots = len(obj.material_slots)
                    
                    # Data Prep
                    facevertindices = numpy.empty(numelements, dtype=numpy.int32)
                    faceloopindices = numpy.empty(numelements, dtype=numpy.int32)
                    
                    mesh.loop_triangles.foreach_get('vertices', facevertindices)
                    mesh.loop_triangles.foreach_get('loops', faceloopindices)
                    
                    vbones = [[0,0,0,0] for x in range(0, numverts)]
                    vweights = [[1,1,1,1] for x in range(0, numverts)]
                    vnumbones = numpy.empty(numverts)
                    vnumbones.fill(0)
                    
                    if process_bones:
                        vertices = tuple(mesh.vertices)
                        grouptoboneindex = {vg.index: bonetoindex[vg.name] for vg in obj.vertex_groups if vg.name in boneorder}
                        usedgroupindices = tuple(grouptoboneindex.keys())
                        
                        for vi, v in enumerate(vertices):
                            bbones = []
                            wweights = []
                            n = 0
                            for vge in v.groups:
                                if vge.group in usedgroupindices:
                                    bbones.append( grouptoboneindex[vge.group] )
                                    wweights.append( vge.weight )
                                    n += 1
                            
                            wpairs = [(bbones[i], wweights[i]) for i in range(0, n)]
                            wpairs.sort(key=lambda x: -x[1])
                            excessb = [0] * (4-n)
                            excessw = [0] * (4-n)
                            
                            vbones[vi] = tuple([x[0] for x in wpairs]+excessb)
                            vweights[vi] = numpy.array([x[1] for x in wpairs]+excessw)
                            vnumbones[vi] = n
                    
                    # Buffer Data ------------------------------------------------------------------------------------------
                    bcontiguous = []
                    
                    NumpyFloatToBytes = lambda nparray : numpy.frombuffer( nparray.astype(numpy.float32).tobytes(), dtype=numpy.uint8 )
                    NumpyByteToBytes = lambda nparray : numpy.frombuffer( (nparray * 255.0).astype(numpy.uint8).tobytes(), dtype=numpy.uint8 )
                    
                    def NumpyCreatePattern(vector, size):
                        vector = numpy.array(vector)
                        nparray = numpy.empty([size,vector.shape[0]])
                        nparray[:] = vector
                        return nparray
                    
                    for k, size, layer, isSrgb, default_value in attribparams:
                        # Position
                        if k == VBF_POS:
                            uniquedata = numpy.empty((numverts * 3), dtype=numpy.float32)
                            mesh.vertices.foreach_get('co', uniquedata)
                            attdata = numpy.array([ uniquedata[i*3:i*3+size] for i in facevertindices], dtype=numpy.float32)
                            bcontiguous.append( NumpyFloatToBytes(attdata) )
                        # Normals
                        elif k == VBF_NOR:
                            attdata = numpy.empty(numelements * 3, dtype=numpy.float32)
                            mesh.loops.foreach_get('normal', attdata)
                            attdata = numpy.array([ attdata[i*3:i*3+size] for i in faceloopindices], dtype=numpy.float32)
                            bcontiguous.append( NumpyFloatToBytes(attdata) )
                        # Tangents
                        elif k == VBF_TAN:
                            attdata = numpy.empty(numelements * 3, dtype=numpy.float32)
                            mesh.loops.foreach_get('tangent', attdata)
                            attdata = numpy.array([ attdata[i*3:i*3+size] for i in faceloopindices], dtype=numpy.float32)
                            bcontiguous.append( NumpyFloatToBytes(attdata) )
                        # Bitangents
                        elif k == VBF_BTN:
                            normals = numpy.empty(numelements * 3, dtype=numpy.float32)
                            tangents = numpy.empty(numelements * 3, dtype=numpy.float32)
                            mesh.loops.foreach_get('normal', normals)
                            mesh.loops.foreach_get('tangent', tangents)
                            
                            normals = numpy.array( numpy.split(normals, numelements), dtype=numpy.float32 )
                            tangents = numpy.array( numpy.split(tangents, numelements), dtype=numpy.float32 )
                            attdata = numpy.cross(normals, tangents).flatten()
                            
                            attdata = numpy.array([ attdata[i*3:i*3+size] for i in faceloopindices], dtype=numpy.float32)
                            bcontiguous.append( NumpyFloatToBytes(attdata) )
                        # UVs
                        elif k == VBF_UVS or k == VBF_UVB:
                            lyr = mesh.uv_layers.get(layer) if layer in mesh.uv_layers.keys() else mesh.uv_layers.active
                            if lyr:
                                uniquedata = numpy.empty(numloops * 2, dtype=numpy.float32)
                                
                                if USE_ATTRIBUTES:
                                    lyr.data.foreach_get('uv', uniquedata)
                                else:
                                    lyr.data.foreach_get('uv', uniquedata)
                                attdata = numpy.array([ x for i in faceloopindices for v in [uniquedata[i*2:i*2+size]] for x in (v[0], 1.0-v[1])], dtype=numpy.float32)
                            else:
                                attdata = NumpyCreatePattern(default_value, numelements)
                            if k == VBF_UVS:
                                bcontiguous.append( NumpyFloatToBytes(attdata) )
                            else:
                                bcontiguous.append( NumpyByteToBytes(attdata) )
                        # Color
                        elif k == VBF_COL or k == VBF_RGB:
                            if USE_ATTRIBUTES:
                                lyr = mesh.color_attributes.get(layer) if layer in mesh.color_attributes.keys() else mesh.color_attributes.active_color
                            else:
                                lyr = mesh.vertex_colors.get(layer) if layer in mesh.vertex_colors.keys() else mesh.vertex_colors.active
                            if lyr:
                                uniquedata = numpy.empty(numloops * 4, dtype=numpy.float32)
                                lyr.data.foreach_get('color', uniquedata)
                                
                                if (USE_ATTRIBUTES and not isSrgb):
                                    numpy.power(uniquedata, NumpyCreatePattern((.4545, .4545, .4545, 1.0), numloops), uniquedata)
                                elif (not USE_ATTRIBUTES) and (not isSrgb):
                                    numpy.power(uniquedata, NumpyCreatePattern((2.2, 2.2, 2.2, 1.0), numloops), uniquedata)
                                attdata = numpy.array([ uniquedata[i*4:i*4+size] for i in faceloopindices], dtype=numpy.float32)
                            else:
                                attdata = NumpyCreatePattern(default_value, numelements)
                            if k == VBF_COL:
                                bcontiguous.append( NumpyFloatToBytes(attdata) )
                            else:
                                bcontiguous.append( NumpyByteToBytes(attdata) )
                        # Bones
                        elif k == VBF_BON or k == VBF_BOB:
                            uniquedata = numpy.empty((numverts * size), dtype=numpy.float32 if k == VBF_BON else numpy.int8)
                            for vi in range(0, numverts):
                                uniquedata[vi*size:vi*size+size] = vbones[vi][:size]
                            
                            attdata = numpy.array([ uniquedata[i*size:i*size+size] for i in facevertindices], dtype=numpy.float32)
                            if k == VBF_BON:
                                bcontiguous.append( NumpyFloatToBytes(attdata) )
                            else:
                                bcontiguous.append( NumpyByteToBytes(attdata/255.0) )
                        # Weights
                        elif k == VBF_WEI or k == VBF_WEB:
                            uniquedata = numpy.empty((numverts * size), dtype=numpy.float32)
                            for vi in range(0, numverts):
                                uniquedata[vi*size:vi*size+size] = vweights[vi][:size] / sum(vweights[vi][:size])
                            attdata = numpy.array([ uniquedata[i*size:i*size+size] for i in facevertindices], dtype=numpy.float32)
                            if k == VBF_WEI:
                                bcontiguous.append( NumpyFloatToBytes(attdata) )
                            else:
                                bcontiguous.append( NumpyByteToBytes(attdata) )
                        # Padding
                        elif k == VBF_PAD or k == VBF_PAB:
                            attdata = NumpyCreatePattern(default_value, numelements)
                            if k == VBF_PAD:
                                bcontiguous.append( NumpyFloatToBytes(attdata) )
                            else:
                                bcontiguous.append( NumpyByteToBytes(attdata) )
                    
                    attributevectors = [ numpy.split(buffer, numelements) for buffer in bcontiguous ]
                    
                    vbinstances.append(
                        numpy.array([ 
                            x 
                            for vindex in range(0, numelements) 
                            for vectors in attributevectors 
                            for x in vectors[vindex]  
                        ]).tobytes()
                    )
                    netnumelements += numelements
                
                vbmesh = b''.join(vbinstances)
                vbmap[sourceobj.name] = (vbmesh, netnumelements)
                
                if use_cache:
                    sourceobj['VBDAT_'+checksumkey] = zlib.compress(vbmesh, 9)
                    sourceobj['VBNUM_'+checksumkey] = numelements
                    sourceobj['VBSUM_'+checksumkey] = checksum
        
        return vbmap
classlist.append(VBM_PG_Master)

'# =========================================================================================================================='
'# REGISTER'
'# =========================================================================================================================='

def register():
    for c in classlist:
        bpy.utils.register_class(c)
    
    bpy.types.Scene.vbm = bpy.props.PointerProperty(type=VBM_PG_Master)
    bpy.types.Armature.vbm_dissolve_list = bpy.props.PointerProperty(type=VBM_PG_BoneDissolveList)
    bpy.types.Armature.vbm_action_list = bpy.props.CollectionProperty(type=VBM_PG_Action)
    bpy.types.Armature.vbm_action_list_index = bpy.props.IntProperty(name="Index")

def unregister():
    for c in classlist[::-1]:
        bpy.utils.unregister_class(c)

if __name__ == "__main__":
    register()

