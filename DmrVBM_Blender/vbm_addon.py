import bpy
import numpy
import struct
import bmesh
import os
import zlib
import mathutils
import json

from bpy_extras.io_utils import ExportHelper, ImportHelper
from bl_ui.utils import PresetPanel

classlist = []

# VBM spec:
"""
    'VBM' (3B)
    VBM file version = 3 (1B)
    
    flags (1B)
    
    jumpvbuffer (1I)
    jumpskeleton (1I)
    jumpanimations (1I)
    
    -- Vertex Buffers ----------------------------------------------
    meshflags (1I)
    
    numvbuffers (1I)
    
    vbnames[vbcount]
        namelength (1B)
        namechars[namelength]
            char (1B)
    
    vbdata[vbcount]
        formatlength (1B)
        formatentry[formatlength]
            attributetype (1B)
            attributefloatsize (1B)
        vbnumbytes (1L)
        vbnumvertices (1L)
        vbdata (vbnumbytes B)
    
    vbmaterials[vbcount]
        namelength (1B)
        namechars[namelength]
            char (1B)
    
    -- Skeleton ---------------------------------------------------
    skeletonflags (1I)
    
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
    animationflags (1I)
    
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
    VBM_PROJECTPATHKEY = '<DATAFILES>'
    
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
    VBF_GRO = 'GROUP'
    VBF_GRB = 'GROUPBYTES'
    VBF_PAD = 'PAD'
    VBF_PAB = 'PADBYTES'
    
    VBFUseBytes = [VBF_UVB, VBF_RGB, VBF_BOB, VBF_WEB, VBF_PAB, VBF_GRB]
    VBFUseSizeControl = [VBF_POS, VBF_NOR, VBF_TAN, VBF_BTN, VBF_COL, VBF_RGB, VBF_BON, VBF_BOB, VBF_WEI, VBF_WEB, VBF_PAD, VBF_PAB]
    VBFUseVCLayer = [VBF_COL, VBF_RGB]
    VBFUseUVLayer = [VBF_UVS, VBF_UVB]
    VBFUsePadding = [VBF_PAD, VBF_PAB]
    VBFUseDefault = [VBF_COL, VBF_UVS, VBF_WEI, VBF_GRO]
    VBFUseDefaultBytes = [VBF_RGB, VBF_UVB, VBF_WEB, VBF_GRB, VBF_PAD, VBF_PAB]
    
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
        VBF_GRB: 1,
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
        VBF_GRB: [0],
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
        VBF_GRB: "in_Group",
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
        (VBF_GRO, 'Group Value', '1 Float', 'GROUP_VERTEX', 13),
        (VBF_GRB, 'Group Byte', '1 Byte', 'GROUP_VERTEX', 14),
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
    
    VALIDOBJTYPES = ['MESH', 'CURVE', 'META', 'FONT', 'SURFACE']
    
    VBM_QUEUEGROUPICON = ['DECORATE_KEYFRAME']+['SEQUENCE_COLOR_0'+str(i) for i in range(1, 10)]+['SEQ_CHROMA_SCOPE']*24

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
        if not self.format_code_mutex:
            for format in list(context.scene.vbm.formats):
                if self in list(format.attributes) and format.format_code_mutex:
                    return
            
            self.format_code_mutex = True
            if self.type == VBF_PAB:
                self.default_normalize = True
            if self.type == VBF_PAD:
                self.default_normalize = False
            
            self.size = min(self.size, VBFSize[self.type])
            
            for format in list(context.scene.vbm.formats):
                if self in list(format.attributes):
                    format.UpdateFormatString(context)
                    break
            
            self.format_code_mutex = False
    
    format_code_mutex : bpy.props.BoolProperty()
    
    type : bpy.props.EnumProperty(
        name="Attribute Type", items=Items_VBF, default=VBF_000, update=UpdateFormatString,
        description='Type of attribute to write for each vertex')
    
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
        name="Padding Bytes", size=4, default=(255,255,255,255), min=0, max=255, update=UpdateFormatString,
        description="Constant values for this attribute")
    
    default_normalize : bpy.props.BoolProperty(
        name="Normalized Bytes", default=False, update=UpdateFormatString,
        description="Use normalized bytes for default value. This means the value will be divided by 255 on export")
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
                
                if att.type in (VBF_COL, VBF_RGB, VBF_UVS, VBF_UVS):
                    if att.layer == LYR_SELECT:
                        s += "-select"
                    elif att.layer != LYR_RENDER:
                        s += '@"' + att.layer + '"'
                    if not att.convert_to_srgb:
                        s += "-linear"
                if att.type in (VBF_PAD, VBF_GRO):
                    s += "=("+("%.2f,"*att.size)[:-1] % att.padding_floats[:att.size]+")"
                elif att.type in (VBF_PAB, VBF_GRB):
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
        
        if self.attributes:
            att = self.attributes[self.attributes_index]
            if att.type in VBFUseDefault:
                rr = c.row(align=False)
                rr.label(text="Default Value:", icon=VBFIcon[att.type])
                rr.prop(att, 'size', text="Size")
                rrr = rr.row(align=True)
                rrr.scale_x = 0.7
                [rrr.prop(att, 'padding_floats', index=i, text="", emboss=i<att.size) for i in (0,1,2,3)]
            elif att.type in VBFUseDefaultBytes:
                rr = c.row(align=False)
                rr.label(text="Default Value:", icon=VBFIcon[att.type])
                rr.prop(att, 'size', text="Size")
                rrr = rr.row(align=True)
                rrr.scale_x = 0.7
                [rrr.prop(att, 'padding_bytes', index=i, text="", emboss=i<att.size) for i in (0,1,2,3)]
            else:
                c.label(text=VBFName[att.type], icon=VBFIcon[att.type])
        
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
    all_curves : bpy.props.BoolProperty(
        name="All Bone Curves", default=True,
        description="Write curves for all bones. If false, non-transformed curves will be omitted"
    )
classlist.append(VBM_PG_Action)

class VBM_PG_Action_Settings(bpy.types.PropertyGroup):
    all_curves : bpy.props.BoolProperty(
        name="All Bone Curves", default=True,
        description="Write curves for all bones. If false, non-transformed curves will be omitted"
    )
classlist.append(VBM_PG_Action_Settings)

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

# ========================================================================================================

class VBM_PG_ExportQueue_Entry(bpy.types.PropertyGroup):
    def UpdateName(self, context):
        allqueuenames = [q.name for q in context.scene.vbm.queues if q != self]
        if self.name in allqueuenames:
            basename = self.name
            i = 1
            while (basename+str(i) in allqueuenames):
                i += 1
            self.name = basename+str(i)
            return
    
    name : bpy.props.StringProperty(name="Name", default="VBM", update=UpdateName)
    group : bpy.props.IntProperty(name="Group", default=0, min=0, max=31)
    id_armature : bpy.props.PointerProperty(name="Rig", type=bpy.types.Object, poll=lambda self,obj: obj.type=='ARMATURE')
    id_collection : bpy.props.PointerProperty(name="Collection", type=bpy.types.Collection)
    id_pose : bpy.props.PointerProperty(name="Pose", type=bpy.types.Action)
    id_pre_script : bpy.props.PointerProperty(name="Pre Script", type=bpy.types.Text)
    id_post_script : bpy.props.PointerProperty(name="Post Script", type=bpy.types.Text)
    
    format : bpy.props.StringProperty(name="Format", default="")
    copy_textures : bpy.props.BoolProperty(name="Copy Textures", default=False)
    export_meshes : bpy.props.BoolProperty(name="Export Meshes", default=True)
    export_skeleton : bpy.props.BoolProperty(name="Export Skeleton", default=True)
    export_animations : bpy.props.BoolProperty(name="Export Animations", default=True)
    
    enabled : bpy.props.BoolProperty(name="Enabled", default=True)
    # saveprops = {}
classlist.append(VBM_PG_ExportQueue_Entry)

# ------------------------------------------------------------------------------
class VBM_PG_ExportQueue_Queue(bpy.types.PropertyGroup):
    def GetFiles(self):
        vbm = context.scene.vbm
        filekeys = [int(x) for x in self.files]
        return [q for q in vbm.queues if str(q.key) in filekeys]
    
    def FindFile(self, index):
        key = int(self.files[index].name)
        return [q for q in vbm.queues if q.key == key][0]
    
    files : bpy.props.CollectionProperty(name="Queues", type=VBM_PG_Name)
    active_index : bpy.props.IntProperty(name="Index", default=0)
    enabled : bpy.props.BoolProperty(name="Enabled", default=True)
classlist.append(VBM_PG_ExportQueue_Queue)

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
        hits = 0
        for obj in bpy.data.objects:
            if obj.type == 'MESH':
                hit = 0
                for k in list(obj.keys())[::-1]:
                    if k[:6] in ('VBDAT_', 'VBNUM_', 'VBSUM_') or k in 'VBM_LASTCOUNT VBM_LASTDATA'.split():
                        del obj[k]
                        hit = 1
                hits += hit
        self.report({'INFO'}, '> VBM Cache cleared for %d object(s)' % hits)
        return {'FINISHED'}
classlist.append(VBM_OT_ClearCache)

# -------------------------------------------------------------------------------------------
class VBM_OT_ClearRecent(bpy.types.Operator):
    """Clear stored export parameters"""
    bl_label = "Clear Recents"
    bl_idname = 'vbm.clear_recents'
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        hits = 0
        for obj in bpy.data.objects:
            if obj.type == 'MESH':
                hit = 0
                for k in list(obj.keys())[::-1]:
                    if k == 'VBM_LASTEXPORT':
                        del obj[k]
                        hit = 1
                hits += hit
        self.report({'INFO'}, '> VBM Recent cleared for %d object(s)' % hits)
        return {'FINISHED'}
classlist.append(VBM_OT_ClearRecent)

'========================================================================================================'

# -------------------------------------------------------------------------------------------
class VBM_OT_Format_Add(bpy.types.Operator):
    """Add vertex format to scene"""
    bl_label = "Add Format"
    bl_idname = 'vbm.format_add'
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        vbm = context.scene.vbm
        formats = vbm.formats
        format = formats.add()
        format.name = format.name
        if len(formats) > 1:
            format.format_code = formats[vbm.formats_index].format_code
        else:
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
        vbm = context.scene.vbm
        vbm.formats.remove(self.index)
        vbm.formats_index = max(min(vbm.formats_index, len(vbm.formats)-1), 0)
        return {'FINISHED'}
classlist.append(VBM_OT_Format_Remove)

# -------------------------------------------------------------------------------------------
class VBM_OT_Format_Clear(bpy.types.Operator):
    """Removes all vertex formats from scene"""
    bl_label = "Clear Format"
    bl_idname = 'vbm.format_clear'
    bl_options = {'REGISTER', 'UNDO'}
    index : bpy.props.IntProperty(name="Index")
    
    def execute(self, context):
        vbm = context.scene.vbm
        vbm.formats.clear()
        vbm.formats_index = max(min(vbm.formats_index, len(vbm.formats)-1), 0)
        return {'FINISHED'}
classlist.append(VBM_OT_Format_Clear)

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
class VBM_OT_Format_Export(ExportHelper, bpy.types.Operator):
    """Exports format to json"""
    bl_label = "Export Format"
    bl_idname = 'vbm.format_export'
    bl_options = {'REGISTER', 'UNDO'}
    
    format : bpy.props.StringProperty(
        name="Format", default="",
        description="Format to export. If empty, exports all formats"
        )
    
    filename_ext = ".json"
    filter_glob: bpy.props.StringProperty(default="*"+filename_ext, options={'HIDDEN'}, maxlen=255)
    
    def draw(self, context):
        vbm = context.scene.vbm
        formats = context.scene.vbm.formats
        
        layout = self.layout
        layout.prop_search(self, 'format', vbm, 'formats')
        
        format = formats.get(self.format)
        if format:
            format.DrawPanel(layout)
        elif self.format != "":
            b = layout.box()
            b.label(text="(Format name not found)")
        else:
            b = layout.box().row()
            c1 = b.column(align=True)
            c2 = b.column(align=True)
            c1.scale_x = 4.0
            for format in formats:
                c1.prop(format, 'name', text="", emboss=False)
                rr = c2.row(align=True)
                for att in format.attributes:
                    rr.label(text="", icon=VBFIcon[att.type])
    
    def execute(self, context):
        vbm = context.scene.vbm
        formats = context.scene.vbm.formats
        outjson = {}
        
        if self.format:
            format = formats.get(self.format)
            if format:
                formats = [formats[self.format]]
            else:
                self.report({'WARNING'}, 'Format "%s" not found' % self.format)
                return {'FINISHED'}
        
        for f in formats:
            outjson[f.name] = f.format_code
        
        f = open(self.filepath, 'w')
        f.write(json.dumps(outjson, indent=4))
        f.close()
        
        self.report({'INFO'}, 'Format(s) written to json file')
        return {'FINISHED'}
classlist.append(VBM_OT_Format_Export)

# -------------------------------------------------------------------------------------------
class VBM_OT_Format_Import(ImportHelper, bpy.types.Operator):
    """Imports format from json"""
    bl_label = "Import Format"
    bl_idname = 'vbm.format_import'
    bl_options = {'REGISTER', 'UNDO'}
    
    filename_ext = ".json"
    filter_glob: bpy.props.StringProperty(default="*"+filename_ext, options={'HIDDEN'}, maxlen=255)
    
    overwrite : bpy.props.BoolProperty(
        name="Overwrite Existing", default=True,
        description="Overwrites existing formats if name already exists in file."
        )
    
    def execute(self, context):
        vbm = context.scene.vbm
        formats = context.scene.vbm.formats
        
        f = open(bpy.path.abspath(self.filepath), 'r')
        injson = json.loads("".join([x for x in f]))
        f.close()
        
        for k,v in injson.items():
            if formats.get(k):
                if self.overwrite:
                    formats.get(k).format_code = v
            else:
                item = formats.add()
                item.name = k
                item.format_code = v
        
        self.report({'INFO'}, 'Imported format(s) from json file')
        return {'FINISHED'}
classlist.append(VBM_OT_Format_Import)

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

'========================================================================================================'

class VBM_OT_ExportQueue_AddEntry(bpy.types.Operator):
    """Add export queue to scene"""
    bl_label = "Add Queue"
    bl_idname = 'vbm.queue_entry_add'
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        vbm = context.scene.vbm
        active = vbm.queues[vbm.queues_index] if vbm.queues else None
        item = vbm.queues.add()
        item['filepath'] = "//model.vbm"
        item['selected_only'] = True
        item['visible_only'] = True
        
        if active:
            for k in active.keys():
                item[k] = active[k]
        
        item.name = item.name
        
        vbm.queues.move(len(vbm.queues)-1, vbm.queues_index+1)
        
        return {'FINISHED'}
classlist.append(VBM_OT_ExportQueue_AddEntry)

# -------------------------------------------------------------------------------------------
class VBM_OT_ExportQueue_RemoveEntry(bpy.types.Operator):
    """Remove export queue by index"""
    bl_label = "Remove Queue"
    bl_idname = 'vbm.queue_entry_remove'
    bl_options = {'REGISTER', 'UNDO'}
    index : bpy.props.IntProperty(name="Index")
    
    def execute(self, context):
        vbm = context.scene.vbm
        vbm.queues.remove(self.index)
        vbm.queues_index = min(max(vbm.queues_index, 0), len(vbm.queues)-1)
        return {'FINISHED'}
classlist.append(VBM_OT_ExportQueue_RemoveEntry)

# -------------------------------------------------------------------------------------------
class VBM_OT_ExportQueue_MoveEntry(bpy.types.Operator):
    """Move queue up or down in list"""
    bl_label = "Queue Move"
    bl_idname = 'vbm.queue_entry_move'
    bl_options = {'REGISTER', 'UNDO'}
    move_down : bpy.props.BoolProperty(name="Move Down", default=True)
    
    def execute(self, context):
        vbm = context.scene.vbm
        items = vbm.queues
        items.move(vbm.queues_index, vbm.queues_index + (1 if self.move_down else -1))
        vbm.queues_index = max(0, min(vbm.queues_index + (1 if self.move_down else -1), len(items)-1))
        return {'FINISHED'}
classlist.append(VBM_OT_ExportQueue_MoveEntry)

# -------------------------------------------------------------------------------------------
class VBM_OT_ExportQueue_SetGroup(bpy.types.Operator):
    """Sets group for queue"""
    bl_label = "Queue Set Group"
    bl_idname = 'vbm.queue_entry_group'
    bl_options = {'REGISTER', 'UNDO'}
    queue : bpy.props.StringProperty(name="Queue", default="")
    group : bpy.props.IntProperty(name="Group", default=0, min=0, max=31)
    
    def execute(self, context):
        vbm = context.scene.vbm
        queue = vbm.queues.get(self.queue)
        if queue:
            queue.group = self.group
        return {'FINISHED'}
classlist.append(VBM_OT_ExportQueue_SetGroup)

# -------------------------------------------------------------------------------------------
class VBM_OT_ExportQueue_ToggleGroup(bpy.types.Operator):
    """Toggle groups for queues"""
    bl_label = "Queue Toggle Group"
    bl_idname = 'vbm.queue_group_toggle'
    bl_options = {'REGISTER', 'UNDO'}
    group : bpy.props.IntProperty(name="Group", default=0, min=-1, max=31)
    
    def execute(self, context):
        vbm = context.scene.vbm
        if self.group == -1:
            queues = list(vbm.queues)
        else:
            queues = [q for q in vbm.queues if q.group == self.group]
        
        enabled = sum([q.enabled == False for q in queues]) == len(queues)
        for q in queues:
            q.enabled = enabled
        
        return {'FINISHED'}
classlist.append(VBM_OT_ExportQueue_ToggleGroup)

# -------------------------------------------------------------------------------------------
class VBM_OT_ExportQueue_MakePathsRelative(bpy.types.Operator):
    """Toggle relative paths for queues"""
    bl_label = "Make Queue Paths Relative/Absolute"
    bl_idname = 'vbm.queue_relative_path'
    bl_options = {'REGISTER', 'UNDO'}
    
    relative : bpy.props.BoolProperty(
        name="Make Relative", default=True, 
        description="Converts path to relative, otherwise absolute"
        )
    
    def execute(self, context):
        vbm = context.scene.vbm
        relative = self.relative
        driveerror = ""
        for queue in vbm.queues:
            queueabspath = bpy.path.abspath(queue['filepath'])
            if relative:
                # Make relative if Blender file and target filepath are on same drive 
                if vbm.datafiles_path != "":
                    queue['filepath'] = vbm.ToProjectPath(queue['filepath'])
                elif queueabspath[:3] == bpy.path.abspath("//")[:3]:
                    queue['filepath'] = bpy.path.relpath(queue['filepath'])
                else:
                    driveerror = "> Queue \"%s\" filepath does not target same drive as Blender file (%s != %s)" % (
                        queue.name, queueabspath[:3], bpy.path.abspath("//")[:3])
                    print(driveerror)
            else:
                queue['filepath'] = bpy.path.abspath( vbm.FromProjectPath(queue['filepath']) )
        
        if driveerror:
            self.report({'WARNING'}, driveerror)
        return {'FINISHED'}
classlist.append(VBM_OT_ExportQueue_MakePathsRelative)

# -------------------------------------------------------------------------------------------
class VBM_OT_ExportQueue_Export(bpy.types.Operator):
    """Export all VBMs in queue"""
    bl_label = "Export Queue"
    bl_idname = 'vbm.queue_export'
    bl_options = {'REGISTER', 'UNDO'}
    
    queue : bpy.props.StringProperty(name="Queue", default="")
    group : bpy.props.IntProperty(name="Group", default=-1, min=-1, max=31) # Ignored if 'queue' is set
    
    def execute(self, context):
        vbm = context.scene.vbm
        if self.queue:
            queues = [ vbm.queues.get(self.queue) ]
        elif self.group > -1:
            queues = [ q for q in vbm.queues if q.group == self.group ]
        else:
            queues = list(vbm.queues)
        
        hits = 0
        
        for q in queues:
            if q.enabled:
                print("> Exporting Queue: " + q.name)
                bpy.ops.vbm.export_vbm(queue=q.name, dialog=False)
                hits += 1
        
        if hits == 0:
            self.report({'WARNING'}, "No Queues Exported.")
        else:
            self.report({'INFO'}, "%d Queue(s) Exported." % hits)
        
        return {'FINISHED'}
classlist.append(VBM_OT_ExportQueue_Export)

'========================================================================================================'

# -------------------------------------------------------------------------------------------
class VBM_PT_ExportVBM_Presets(PresetPanel, bpy.types.Panel):
    bl_label = "My Presets"
    preset_subdir = "dmrvbm/vbm_export_vbm"
    preset_operator = 'vbm.export_vbm'
    preset_add_operator = 'vbm.export_vbm_preset_add'
classlist.append(VBM_PT_ExportVBM_Presets)

# -------------------------------------------------------------------------------------------
class VBM_OT_ExportVBM(ExportHelper, bpy.types.Operator):
    """Export model to vbm file"""
    bl_label = "Export VBM"
    bl_idname = 'vbm.export_vbm'
    bl_options = {'REGISTER', 'UNDO', 'PRESET'}
    
    def draw_header_preset(self, context):
        VBM_PT_ExportVBM_Presets.draw_panel_header(self.layout)
    
    savepropnames = ('''
        filepath filename_ext file_type compression collection armature use_collection_nested batching_filename
        alphanumeric_modifiers mesh_delimiter_start mesh_delimiter_end flip_uvs
        add_root_bone deform_only pose armature_delimiter_start armature_delimiter_end
        action_delimiter_start action_delimiter_end
        visible_only selected_only alphanumeric_only format_code format grouping batching fast_vb cache_vb
        pre_script post_script export_meshes export_skeleton export_animations copy_textures''').split()
    
    dialog: bpy.props.BoolProperty(default=True, options={'SKIP_SAVE', 'HIDDEN'})
    queue : bpy.props.StringProperty(
        name="Export Queue", default="",
        description="Export Queue to read parameters from"
        )
    
    queue_dialog : bpy.props.StringProperty(
        name="Export Queue", default="", options={'SKIP_SAVE', 'HIDDEN'},
        description="Queue to save dialog settings to."
    )
    
    def SaveQueue(self, context=None):
        if self.queue_save or context==None:
            self.queue_save = False
            
            context = context if context else bpy.context
            vbm = context.scene.vbm
            
            if not self.queue_dialog:
                self.queue_dialog = (
                    self.collection.name if self.armature else 
                    self.armature.name if self.armature else 
                    context.object.name
                )
            
            vbmqueues = vbm.queues
            queue = vbmqueues.get(self.queue_dialog)
            if not queue:
                queue = vbmqueues.add()
                queue.name = self.queue_dialog
            if queue:
                queue.id_armature = bpy.data.objects.get(self.armature)
                queue.id_collection = bpy.data.collections.get(self.collection)
                queue.id_pose = bpy.data.actions.get(self.pose)
                queue.id_pre_script = bpy.data.texts.get(self.pre_script)
                queue.id_post_script = bpy.data.texts.get(self.post_script)
                queue.id_pose = bpy.data.actions.get(self.pose)
                
                for k in VBM_OT_ExportVBM.savepropnames:
                    queue[k] = getattr(self, k)
                
                # Make relative if Blender file and target filepath are on same drive
                if self.filepath[:3] == bpy.path.abspath("//")[:3]:
                    queue['filepath'] = vbm.ToProjectPath(bpy.path.relpath(self.filepath))
                else:
                    queue['filepath'] = vbm.ToProjectPath(bpy.path.abspath(self.filepath))
                
                print("> Saved props to Queue: " + queue.name)
                
    
    def ReadQueue(self, queuename):
        vbm = bpy.context.scene.vbm
        queue = vbm.queues.get(queuename)
        if queue:
            for k in self.savepropnames:
                setattr(self, k, getattr(queue, k, queue.get(k, getattr(self, k))))
            
            self.filepath = vbm.FromProjectPath(self.filepath)
            self.armature = queue.id_armature.name if queue.id_armature else self.armature
            self.collection = queue.id_collection.name if queue.id_collection else self.collection
            self.pose = queue.id_pose.name if queue.id_pose else self.pose
            self.pose = queue.id_pose.name if queue.id_pose else self.pose
            self.pre_script = queue.id_pre_script.name if queue.id_pre_script else self.pre_script
            self.post_script = queue.id_post_script.name if queue.id_post_script else self.post_script
        return queue
    
    queue_save : bpy.props.BoolProperty(
        name="Save Queue", default=False, update=SaveQueue, options={'SKIP_SAVE', 'HIDDEN'},
        description="Save Settings to Queue"
    )
    
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
    
    items_collections : bpy.props.CollectionProperty(type=VBM_PG_Name, options={'SKIP_SAVE', 'HIDDEN'})
    collection : bpy.props.StringProperty(
        name="Collection", default="",
        description="Collection to export. If empty, all scene objects are used"
    )
    
    items_armatures : bpy.props.CollectionProperty(type=VBM_PG_Name, options={'SKIP_SAVE', 'HIDDEN'})
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
            #('MATERIAL', 'By Material', 'Objects will be written to "<filename><material_name>.ext" by material'),
            ('ARMATURE', 'By Parent Armature', 'Objects will be written to "<filename><armature_name>.ext" by parent armature'),
            #('EMPTY', 'By Parent Empty', 'Objects will be written to "<filename><emptyname>.ext" by parent empty'),
        ),
        description="Method to write files. Can be set to single file or write multiple based on criteria"
    )
    
    grouping : bpy.props.EnumProperty(
        name="Grouping", default='OBJECT', items=(
            ('OBJECT', "By Object", "Objects -> VBs"),
            #('MATERIAL', "By Material", "Materials -> VBs"),
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
    
    use_object_formats : bpy.props.BoolProperty(
        name="Use Object Formats", default=True,
        description="If set, use the format defined for the object, instead of dialog's format. Dialog format is used if not set/found"
    )
    
    flip_uvs : bpy.props.BoolProperty(
        name="Flip UVs", default=True,
        description="Invert the Y coordinate of exported UV values (1-y)"
    )
    
    # Skeleton ===================================================
    
    armature_delimiter_start : bpy.props.StringProperty(
        name="Armature Delimiter Start", default="-",
        description="Remove beginning of mesh name up to and including this character"
    )
    
    armature_delimiter_end : bpy.props.StringProperty(
        name="Armature Delimiter End", default="",
        description="Remove end of mesh name including this character"
    )
    
    armature_delimiter_show : bpy.props.BoolProperty(
        name="Armature Corrected Names", default=True,
        description="Show corrected armature names"
    )
    
    pose : bpy.props.StringProperty(
        name="Pose", default="",
        description="Action to set armature to for export. Ignored if armature is exported"
    )
    
    deform_only : bpy.props.BoolProperty(
        name="Deform Only", default=True,
        description="Only export deform bones for skeleton and bone-related attributes"
    )
    
    add_root_bone : bpy.props.BoolProperty(
        name="Add Zero Bone", default=True,
        description="Adds a root bone to the origin of the armature."
    )
    
    # Action ===================================================
    
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
    
    # Checkout ===================================================
    visible_only : bpy.props.BoolProperty(
        name="Visible Only", default=False,
        description="Export meshes that are visible"
    )
    
    selected_only : bpy.props.BoolProperty(
        name="Selected Only", default=False,
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
    
    copy_textures : bpy.props.BoolProperty(
        name="Copy Textures", default=False,
        description="Copy relevant textures from objects' materials to destination. Filename uses not label if set, else image name"
    )
    
    menu_vbuffer : bpy.props.BoolProperty(name="Vertex Buffer Options", default=False, options={'SKIP_SAVE', 'HIDDEN'})
    menu_skeleton : bpy.props.BoolProperty(name="Skeleton Options", default=False, options={'SKIP_SAVE', 'HIDDEN'})
    menu_animation : bpy.props.BoolProperty(name="Animation Options", default=False, options={'SKIP_SAVE', 'HIDDEN'})
    menu_checkout : bpy.props.BoolProperty(name="Checkout Options", default=False, options={'SKIP_SAVE', 'HIDDEN'})
    
    pre_script : bpy.props.StringProperty(
        name="Pre Script", default="",
        description="Script to run on objects before applying modifiers."
    )
    
    post_script : bpy.props.StringProperty(
        name="Post Script", default="",
        description="Script to run on objects after applying modifiers."
    )
    
    active : bpy.props.BoolProperty()
    use_last_props : bpy.props.BoolProperty(options={'SKIP_SAVE', 'HIDDEN'})
    
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
            files = [ 
                [
                    fbasename + armature.name + fext, 
                    armature.children, 
                    armature, 
                    [x.action for x in armature.data.vbm_action_list if x.action]
                ] 
                for armature in armatures
            ]
        elif self.batching == 'OBJECT':
            files = [
                [fbasename + obj.name + fext, [obj], None, []]
                for obj in objects if obj.type != 'ARMATURE' and (
                    (not self.alphanumeric_only or obj.name[0] in 'qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890')
                )
            ]
        elif self.batching == 'MESH':
            files = [
                [fbasename + obj.data.name + fext, [obj], None, []]
                for obj in objects if obj.type == 'MESH' and (
                    (not self.alphanumeric_only or obj.name[0] in 'qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890')
                )
            ]
        else:
            objects = [obj for obj in objects if obj.type in VALIDOBJTYPES]
            if armatures:
                armature = armatures[0]
                files = [ [fname, list(objects), armature, [x.action for x in armature.data.vbm_action_list if x.action] ] ]
            else:
                files = [ [fname, list(objects), None, [] ] ]
        
        if not self.export_meshes:
            files = [f[:1] + [[]] + f[2:] for f in files]
        if not self.export_animations:
            files = [f[:3] + [[]] + f[4:] for f in files]
        
        return files
    
    def invoke(self, context, event):
        [data.remove(x) for data in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures, bpy.data.actions) for x in data if x.get('__temp', False)]
        
        self.filename_ext = "." + self.file_type.lower()
        self.filter_glob = "*." + self.file_type.lower()
        
        vbm = context.scene.vbm
        
        if self.format == "":
            if len(vbm.formats) == 0:
                item = vbm.formats.add()
                item.name = "Native"
                item.format_code = "POSITION3 COLORBYTES4 UV2"
            self.format = context.scene.vbm.formats[0].name
        
        # Queue
        queue = self.ReadQueue(self.queue_dialog)
        # Use Last Props
        if not queue and self.use_last_props:
            obj = context.selected_objects[0] if context.selected_objects else context.active_object
            rig = bpy.data.objects.get(self.armature)
            collection = bpy.data.collections.get(self.collection)
            
            if collection:
                [setattr(self, k,v) for k,v in collection.get('VBM_LASTEXPORT', {}).items() if k in self.savepropnames]
                self.collection = collection.name
            elif rig:
                [setattr(self, k,v) for k,v in rig.get('VBM_LASTEXPORT', {}).items() if k in self.savepropnames]
                self.armature = rig.name
            elif obj:
                ftype = self.file_type
                [setattr(self, k,v) for k,v in obj.get('VBM_LASTEXPORT', {}).items() if k in self.savepropnames]
                self.file_type = ftype
        
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
        
        # Queue
        r = layout.row(align=True)
        
        rr = r.row(align=True)
        rr.scale_x = 0.55
        rr.label(text="Queue:")
        rr.prop_search(self, 'queue_dialog', vbm, 'queues', text="")
        
        queue = vbm.queues.get(self.queue_dialog)
        if queue:
            r.prop(queue, 'name', text="")
        else:
            r.prop(self, 'queue_dialog', text="")
        
        r.prop(self, 'queue_save', text="", icon='GREASEPENCIL')
        
        # File Type
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
        r = b.row()
        r.prop(self, 'compression')
        rr = r.row()
        rr.scale_x = 0.9
        rr.prop(self, 'copy_textures')
        
        c = layout.column(align=True)
        r = c.row(align=True)
        r.enabled = self.armature == ""
        r.prop_search(self, 'collection', self, 'items_collections', icon='OUTLINER_COLLECTION')
        c.prop_search(self, 'armature', self, 'items_armatures', icon='ARMATURE_DATA')
        
        c = layout.column(align=True)
        c.prop(self, 'batching')
        c.prop(self, 'grouping')
        
        c = layout.column(align=True)
        c.prop_search(self, 'pose', bpy.data, 'actions', icon='POSE_HLT')
        
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
            cc.prop(self, "flip_uvs")
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
            r.active = self.grouping == 'ARMATURE'
            r.label(text="", icon='ARMATURE_DATA')
            rr = r.row(align=True)
            rr.scale_x = 1.1
            rr.prop(self, 'armature_delimiter_start', text="", icon='TRACKING_CLEAR_BACKWARDS')
            rr.prop(self, 'armature_delimiter_end', text="", icon='TRACKING_CLEAR_FORWARDS')
            r.prop(self, 'armature_delimiter_show', text="", icon='HIDE_OFF' if self.armature_delimiter_show else 'HIDE_ON')
            
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
                
            checkout = self.GetCheckout()
            for fname, fobjects, farmature, factions in checkout:
                if self.batching == 'ARMATURE' and self.armature_delimiter_show:
                    fname = FixName(fname, self.armature_delimiter_start, self.armature_delimiter_end)
                
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
                    canexport = (
                        (not self.visible_only or obj.visible_get()) and
                        (not self.selected_only or obj.select_get()) and
                        (not self.alphanumeric_only or obj.name[0] in 'qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890')
                    )
                    
                    rr.enabled = canexport
                    
                    name = obj.name
                    if self.mesh_delimiter_show and canexport:
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
            # + Textures
            if self.copy_textures:
                outputimages = list(set([
                    (nd.label if nd.label else nd.image.name, nd.image)
                    for c in checkout
                    for obj in c[1]
                    for slot in obj.material_slots
                    for nd in slot.material.node_tree.nodes if (nd.type == 'TEX_IMAGE' and nd.image)
                ]))
                
                for name, image in outputimages:
                    cc.label(text=bpy.path.ensure_ext(name, ".png"), icon='IMAGE')
            
        else:
            r = b.row(align=True)
            r.prop(self, 'menu_checkout', icon='CURRENT_FILE')
            r.separator()
            r.prop(self, 'visible_only', text="", icon='HIDE_OFF', toggle=True)
            r.prop(self, 'selected_only', text="", icon='RESTRICT_SELECT_OFF', toggle=True)
    
    def execute(self, context):
        vbm = context.scene.vbm
        exporterror = 0
        
        # Queue
        queue = None
        if self.dialog:
            if self.queue_dialog:
                self.SaveQueue(context)
                queue = self.ReadQueue(self.queue_dialog)
        elif self.queue:
            queue = self.ReadQueue(self.queue)
        
        self.filename_ext = "." + self.file_type.lower()
        self.filepath = vbm.FromProjectPath(self.filepath)
        fpath = os.path.abspath(bpy.path.abspath( self.filepath ))
        if self.filename_ext in fpath:
            fpath = bpy.path.ensure_ext(fpath, self.filename_ext)
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
        delims = [self.mesh_delimiter_start, self.mesh_delimiter_end]
        
        sc = context.scene
        
        # Save Last Props
        if not queue and vbm.write_to_recent:
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
        
        if not os.path.isdir(fdir) or self.filepath == "":
            self.report({'WARNING'}, "Invalid path: \"%s\"" % self.filepath)
            return {'FINISHED'}
        
        pose_action = bpy.data.actions.get(self.pose)
        
        transformdefaults = (
            ('.location', (0,0,0)),
            ('.rotation_quaternion', (1,0,0,0)),
            ('.scale', (1,1,1))
        )
        
        outputimages = []
        
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
                
                lastaction = None
                if armature and pose_action:
                    if not armature.animation_data:
                        armature.animation_data_create()
                    lastaction = armature.animation_data.action
                    armature.animation_data.action = pose_action
                    context.scene.frame_set(context.scene.frame_current)
                
                vbdata = context.scene.vbm.MeshToVB(
                    objects, 
                    format if format else self.format_code,
                    pre_script=self.pre_script,
                    post_script=self.post_script,
                    use_cache=self.cache_vb,
                    fast=self.fast_vb,
                    alphanumeric_modifiers=self.alphanumeric_modifiers,
                    apply_armature=True,
                    flip_uvs=self.flip_uvs,
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
                    (outlen[1] / 1000, 100.0 * outlen[1] / max(outlen[0], 1), filepath) 
                    )
                
                if armature and pose_action:
                    armature.animation_data.action = lastaction
                
            self.report({'INFO'}, "> Vertex Buffer Export Complete")
        # VBM
        elif self.file_type == 'VBM':
            Pack = struct.pack
            PackString = lambda s: Pack('B', len(s)) + b''.join([Pack('B', ord(c)) for c in s] )
            PackMatrix = lambda m: b''.join([Pack('f', x) for v in m.copy().transposed() for x in v])
            
            for fname, objects, armature, actions in files:
                if self.batching == 'ARMATURE':
                    fname = FixName(fname, self.armature_delimiter_start, self.armature_delimiter_end)
                
                filepath = fdir + fname
                
                objects = [obj for obj in objects if (
                    (not self.visible_only or obj.visible_get()) and
                    (not self.selected_only or obj.select_get()) and
                    (not self.alphanumeric_only or obj.name[0] in 'qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM1234567890')
                )]
                
                if self.copy_textures:
                    outputimages += [
                        (nd.label if nd.label else nd.image.name, nd.image)
                        for obj in objects
                        for slot in obj.material_slots
                        for nd in slot.material.node_tree.nodes if (nd.type == 'TEX_IMAGE' and nd.image)
                    ]
                
                boneorder = []
                bonedata = {}
                
                # Data order: Header, VBs, Skeleton, Animations
                # Skeleton is read first here to get bone order
                
                # Skeleton --------------------------------------------------------
                outskeleton = b''
                outskeleton += Pack('I', 0) # Flags
                
                parentmap = {}
                if armature:
                    parentmap = vbm.DeformArmatureMap(armature) if deformonly else {b.name: b.parent.name if b.parent else "" for b in armature.data.bones}
                    boneorder = list(parentmap.keys())
                
                if self.export_skeleton:
                    matidentity = mathutils.Matrix.Identity(4)
                    
                    # Use armature bone data
                    if armature:
                        bones = [armature.data.bones[bname] for bname in parentmap.keys()]
                        bonemat = {b.name: b.matrix_local.copy() for b in bones}
                        bonematinv = {b: m.copy().inverted() for b,m in bonemat.items()}
                        parentmatinv = {b: bonematinv[parentmap[b]].copy() if parentmap.get(b) else matidentity for b in bonematinv.keys()}
                    else:
                        bones = []
                        bonemat = {}
                        bonematinv = {}
                        parentmatinv = {}
                    
                    numbones = len(boneorder)
                    
                    print("> Creating Skeleton Data")
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
                        outskeleton += Pack('I', (boneorder.index(parentmap[b]) + usezerobone) if parentmap.get(b) else 0)
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
                outvbs += Pack('I', 0) # Flags
                
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
                    
                    lastaction = None
                    if armature:
                        if not armature.animation_data and pose_action:
                            armature.animation_data_create()
                        if armature.animation_data:
                            lastaction = armature.animation_data.action
                    
                    if pose_action:
                        armature.animation_data.action = pose_action
                    
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
                                flip_uvs=self.flip_uvs,
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
                
                    if armature and armature.animation_data:
                        armature.animation_data.action = lastaction
                
                outvbs += Pack('I', len(vbmap))
                
                formatserialized = vbm.ParseFormatString(format if format else self.format_code) if self.export_meshes else []
                
                # VBs
                for name, vbmeta in vbmap.items():
                    # Name
                    outvbs += PackString(name)
                    # Format
                    outvbs += Pack('B', len(formatserialized))
                    for k, size, layer, srgb, defaultvalue in formatserialized:
                        # 8th bit is used to mark byte attributes
                        outvbs += Pack('B', VBFTypeIndex[k] | (128 if k in VBFUseBytes else 0))
                        outvbs += Pack('B', size)
                    # Buffer
                    vb, numvertices = vbmeta
                    outvbs += Pack('I', len(vb))
                    outvbs += Pack('I', numvertices)
                    outvbs += vb
                
                # Animation --------------------------------------------------------
                outanimations = b''
                outanimations = Pack('I', 0) # Flags
                
                if self.export_animations:
                    print("> Creating Animation Data")
                    
                    boneorder = tuple(parentmap.keys())
                    basebonenames = [x.replace('DEF-', "") for x in boneorder]
                    
                    outanimations += Pack('I', len(actions)) # numactions
                    
                    if armature:
                        matidentity = armature.matrix_world.copy()
                        matidentity.identity()
                        lastaction = armature.animation_data.action if armature.animation_data else None
                        
                        numactions = len(actions)
                        fps = context.scene.render.fps
                        
                        workingrig = vbm.CreateDeformArmature(armature)
                        workingrig['__temp'] = True
                        workingrig.data['__temp'] = True
                        context.view_layer.objects.active = workingrig
                        
                        if not workingrig.animation_data:
                            workingrig.animation_data_create()
                        
                        armature.data.pose_position = 'POSE'
                        workingrig.data.pose_position = 'POSE'
                    else:
                        workingrig = None
                    
                    for action in actions:
                        actionchecksum = int(sum((
                            [ord(x) for fc in action.fcurves for dp in fc.data_path for x in dp] + 
                            [x*10 for fc in action.fcurves for k in fc.keyframe_points for x in k.co] + 
                            [action.frame_start, action.frame_end]
                        )))
                        
                        if workingrig:
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
                                
                                print("> Baking copy of action:", action.name)
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
                                
                                workingaction = workingrig.animation_data.action
                                workingaction['__temp'] = False
                                workingaction.name = "~" + action.name + "__VBM_BAKED"
                                action['VBM_BAKED'] = workingaction.name
                            else:
                                workingaction = bpy.data.actions.get(action['VBM_BAKED'])
                        else:
                            workingaction = action
                        
                        framerange = (action.frame_start, action.frame_end)
                        duration = framerange[1]-framerange[0]+1
                        
                        fcurves = workingaction.fcurves
                        bundles = {}
                        bundlesbone = {}
                        bundlesnonbone = {}
                        
                        ValueCmp = lambda x1, x2: (x2-x1)*(x2-x1) <= 0.0001
                        
                        # Build Curves
                        for fc in fcurves:
                            dp = fc.data_path
                            curvename = dp
                            bonename = dp[dp.find('"')+1:dp.rfind('"')]
                            inert = False
                            
                            # Bone Curve
                            if bonename and bonename in boneorder:
                                if not action.vbm.all_curves:
                                    # Omit curves that don't change
                                    array_index = fc.array_index
                                    for ttype, vec in transformdefaults:
                                        if ttype in dp:
                                            kpoints = tuple(fc.keyframe_points)
                                            if sum([ValueCmp(k.co[1], vec[array_index]) for k in kpoints]) == len(kpoints):
                                                inert = True
                                            break
                                    
                                    if inert:
                                        continue
                                
                                # Fix Name
                                curvename = bonename
                                if '.location' in dp:
                                    curvename += '.location'
                                elif '.scale' in dp:
                                    curvename += '.scale'
                                elif '.rotation_quaternion' in dp:
                                    curvename += '.rotation_quaternion'
                                elif '.' in dp[dp.find(bonename)+len(bonename):]:
                                    curvename += dp[dp.rfind('.'):]
                            # Property Curve
                            elif curvename[:2] == '["':
                                curvename = curvename[2:-2]
                            
                            # Non-bone curve
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
                        outanimations += Pack('f', duration) # Duration in frames
                        outanimations += Pack('I', len(bundles)) # Number of curves
                        
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
                        
                        outanimations += Pack('I', len(action.pose_markers)) # Number of markers
                        outanimations += b''.join([PackString(m.name) + Pack('i', m.frame) for m in action.pose_markers])
                    
                    if armature:
                        [pb.matrix_basis.identity() for pb in armature.pose.bones]
                        if armature.animation_data:
                            armature.animation_data.action = lastaction
                        
                else:
                    outanimations += Pack('I', 0)
                
                # Output -----------------------------------------------------
                outbytes = b''
                
                outbytes += b'VBM' + Pack('B', VBMVERSION)
                outbytes += Pack('B', 0)
                
                outbytes += Pack('I', len(outbytes) + len(Pack('I', 0)) * 3)
                outbytes += Pack('I', len(outbytes) + len(outvbs) + len(Pack('I', 0)) * 2)
                outbytes += Pack('I', len(outbytes) + len(outvbs) + len(outskeleton) + len(Pack('I', 0)) * 1)
                
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
                print(
                    "Objects:", len(objects), 
                    "-> Meshes:", len(vbmap.items()) * self.export_meshes, 
                    "| Bones:", len(boneorder)  * self.export_skeleton, 
                    "| Actions:", len(actions) * self.export_animations
                    )
                print(
                    "Data of size %.2fKB (%.2f%% of original size) written to \"%s\"" % 
                    (outlen[1] / 1000, 100.0 * outlen[1] / outlen[0], filepath) 
                    )
                
            if exporterror == 0:
                self.report({'INFO'}, "> VBM Export Complete")
        
        # Copy Textures
        usedimages = []
        for name, image in outputimages:
            imagepath = fdir + bpy.path.ensure_ext(name, ".png")
            if imagepath in usedimages:
                continue
            usedimages.append(imagepath)
            
            if bpy.app.version >= (3,4,0):
                image.save(filepath=imagepath)
            else:
                imgpath = image.filepath
                image.filepath = imagepath
                image.save_render()
                image.filepath = imgpath
        
        context.view_layer.objects.active = active
        if active:
            active.select_set(True)
        [data.remove(x) for data in (bpy.data.objects, bpy.data.meshes, bpy.data.armatures, bpy.data.actions) for x in data if x.get('__temp', False)]
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
            r.label(text="Value: " + str(tuple(item.padding_floats[:item.size])))
        elif item.type == VBF_PAB:
            r.label(text="Value: " + str(tuple(item.padding_bytes[:item.size])))
        elif item.type == VBF_GRO or item.type == VBF_GRB:
            obj = context.view_layer.objects.active
            if obj and obj.type == 'MESH':
                if USE_ATTRIBUTES:
                    r.prop_search(item, 'layer', obj, 'vertex_groups', text="", results_are_suggestions=True)
                else:
                    r.prop_search(item, 'layer', obj, 'vertex_groups', text="")
            else:
                r.prop(item, 'layer', text="")
            if item.type == VBF_GRO:
                r.prop(item, 'padding_floats', index=0, text="")
            elif item.type == VBF_GRB:
                r.prop(item, 'padding_bytes', index=0, text="")
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
        
        # Size control
        if True or item.type in VBFUseSizeControl:
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
        r = layout.row(align=True)
        if item.action:
            r.prop(item.action, 'name', text="", icon='ACTION', emboss=False)
            r.prop(item.action.vbm, 'all_curves', text="", icon='WORLD')
            
            rr = r.row(align=True)
            rr.scale_x = 0.6
            rr.prop(item.action, 'frame_start', text="S:")
            rr.prop(item.action, 'frame_end', text="E:")
            r.operator('vbm.actionlist_play', text="", icon='PLAY').action = item.action.name
        else:
            r.label(text="(Missing Action)", icon='QUESTION')
            r.prop(item, 'action')
classlist.append(VBM_UL_ActionList)

# ------------------------------------------------------------------------------------------
class VBM_UL_ExportQueues_File(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        vbm = context.scene.vbm
        
        c = layout.column(align=True)
        
        cr = c.row(align=True)
        
        r = cr.row(align=True)
        r.prop(item, 'enabled', text="")
        
        r = r.row(align=True)
        r.active = item.enabled
        
        if vbm.display_queue_group_indices:
            rr = r.row()
            rr.scale_x = 0.3
            rr.label(text="["+str(item.group)+"]")
            r.prop(item, 'name', text="", emboss=False)
        else:
            r.prop(item, 'name', text="", emboss=False, icon=VBM_QUEUEGROUPICON[item.group])
        
        rr = r.row()
        rr.scale_x = 1 if item.id_armature else 0.5
        rr.prop(item, 'id_armature', text="", icon='ARMATURE_DATA')
        
        rr = r.row()
        rr.scale_x = 1 if item.id_collection else 0.5
        rr.prop(item, 'id_collection', text="", icon='OUTLINER_COLLECTION')
        
        # Export
        r = cr.row(align=True)
        op = r.operator('vbm.export_vbm', text="", icon='WINDOW')
        op.dialog = True
        op.queue_dialog = item.name
        op.file_type = item.get('file_type', 'VBM')
        
        op = r.operator('vbm.export_vbm', text="", icon='SOLO_ON')
        op.dialog = False
        op.queue = item.name
        op.file_type = item.get('file_type', 'VBM')
        
        if vbm.display_queue_group_paths:
            r = c.row(align=True)
            r.active = item.enabled
            r.label(text="", icon='BLANK1')
            r.prop(item, '["filepath"]', text="")
classlist.append(VBM_UL_ExportQueues_File)

'# =========================================================================================================================='
'# PANEL'
'# =========================================================================================================================='

class VBM_PT_Master(bpy.types.Panel):
    bl_label = "Dmr VBM"
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "scene"
    
    def draw(self, context):
        vbm = context.scene.vbm
        layout = self.layout.column()
        
        b = layout.box().column(align=True)
        
        r = b.row(align=False)
        r.label(text="Export Selected: ")
        obj = context.selected_objects[0] if context.selected_objects else context.active_object
        
        op = r.operator('vbm.export_vbm', text="VB", icon='OUTLINER_DATA_MESH')
        op.file_type = 'VB'
        op.collection, op.armature = ("", "")
        op.use_last_props = False
        op.queue = ""
        op.dialog = True
        op.format_code = ""
        op.selected_only = True
        
        op = r.operator('vbm.export_vbm', text="VBM", icon='MOD_ARRAY')
        op.file_type = 'VBM'
        op.collection, op.armature = ("", "")
        op.use_last_props = False
        op.queue = ""
        op.dialog = True
        op.format_code = ""
        op.selected_only = True
        
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
                op.use_last_props = True
                
                r.separator()
                
                op = r.operator('vbm.export_vbm', text="", icon='SOLO_ON')
                op.dialog = False
                op.format = ""
                op.file_type = lastprops['file_type']
                op.collection, op.armature = (collection, rig)
                op.use_last_props = True
                op.queue = ""
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
                op.use_last_props = True
                op.queue = ""
            return op
        
        # Export Recent
        obj = context.active_object
        rig = (obj if obj.type == 'ARMATURE' else obj.find_armature()) if obj else None
        
        b.separator()
        c = b.column(align=True)
        c.scale_y = 0.9
        op = OpFromProps(obj, c.row(align=True), 'RESTRICT_SELECT_OFF', '', '')
        op = OpFromProps(rig, c.row(align=True), 'ARMATURE_DATA', "", rig.name if rig else '')
        op = OpFromProps(context.collection, c.row(align=True), 'OUTLINER_COLLECTION', context.collection.name, "")
        
        # Settings
        c = layout.column(align=True)
        r = c.row(align=True)
        rr = r.box().row(align=True)
        rrr = rr.row()
        rrr.scale_x = 0.7
        rrr.label(text="Cache:")
        rr.prop(vbm, 'write_to_cache', text="Write: Enabled" if vbm.write_to_cache else "Write: Disabled", toggle=True)
        rr.operator('vbm.clear_cache', text="", icon='X')
        rr = r.box().row(align=True)
        rrr = rr.row()
        rrr.scale_x = 0.7
        rrr.label(text="Recent:")
        rr.prop(vbm, 'write_to_recent', text="Write: Enabled" if vbm.write_to_recent else "Write: Disabled", toggle=True)
        rr.operator('vbm.clear_recents', text="", icon='X')
        
        r = c.row(align=True)
        r.prop(vbm, 'datafiles_path')
classlist.append(VBM_PT_Master)

# ------------------------------------------------------------------------------------------
class VBM_PT_Queues(bpy.types.Panel):
    bl_label = "Export Queues"
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "scene"
    bl_parent_id = 'VBM_PT_Master'
    bl_options = {'DEFAULT_CLOSED'}
    
    def draw(self, context):
        vbm = context.scene.vbm
        altdisplay = vbm.display_queue_group_indices
        
        layout = self.layout.column()
        
        r = layout.row()
        r.prop(vbm, 'display_queue_group_paths', text="Show Paths")
        r.prop(vbm, 'display_queue_group_indices', text="Group Indices")
        
        r = r.row(align=True)
        r.operator('vbm.queue_relative_path', text="Relative Paths").relative = True
        r.operator('vbm.queue_relative_path', text="Absolute Paths").relative = False
        
        # Export
        r = layout.row(align=True)
        r.enabled = len(vbm.queues) > 0
        op = r.operator('vbm.queue_export', text="Export Queues", icon='SOLO_ON')
        op.queue = ""
        op.group = -1
        
        if altdisplay:
            r = r.row(align=True)
            r.scale_x = 0.35
        for i in range(0, 8):
            op = r.operator('vbm.queue_export', text=str(i) if altdisplay else "", icon='NONE' if altdisplay else VBM_QUEUEGROUPICON[i])
            op.queue = ""
            op.group = i
            
        # Toggle
        r = layout.row(align=True)
        r.operator('vbm.queue_group_toggle', text="Select/Deselect", icon='RESTRICT_SELECT_OFF').group=-1
        
        if altdisplay:
            r = r.row(align=True)
            r.scale_x = 0.35
        for i in range(0, 8):
            op = r.operator('vbm.queue_group_toggle', text=str(i) if altdisplay else "", icon='NONE' if altdisplay else VBM_QUEUEGROUPICON[i])
            op.group = i
        
        # List
        r = layout.row(align=True)
        c = r.column(align=True)
        c.template_list("VBM_UL_ExportQueues_File", "", vbm, "queues", vbm, "queues_index", rows=3)
        r.separator()
        
        # List Ops
        c = r.column(align=True)
        c.scale_y = 0.9
        c.operator('vbm.queue_entry_add', text="", icon='ADD')
        c.operator('vbm.queue_entry_remove', text="", icon='REMOVE').index = vbm.queues_index
        c.separator()
        c.operator('vbm.queue_entry_move', text="", icon='TRIA_UP').move_down = False
        c.operator('vbm.queue_entry_move', text="", icon='TRIA_DOWN').move_down = True
        
        # Active
        if len(vbm.queues) > 0:
            queue = vbm.queues[vbm.queues_index]
            bb = layout.box().column()
            
            r = bb.row()
            r.alignment = 'CENTER'
            
            r.prop(queue, 'name', text="Active Queue")
            r.prop(vbm, 'display_queue_active', text="Show Export Parameters", icon='HIDE_OFF' if vbm.display_queue_active else 'HIDE_ON')
            
            if vbm.display_queue_active:
                r = bb.row(align=True)
                r.prop(queue, 'export_meshes', text="Meshes", toggle=True)
                r.prop(queue, 'export_skeleton', text="Skeleton", toggle=True)
                r.prop(queue, 'export_animations', text="Animations", toggle=True)
                
                r.separator()
                
                # Draw Groups
                if altdisplay:
                    r = r.row(align=True)
                    r.scale_x = 0.35
                for i in range(0, 8):
                    op = r.operator('vbm.queue_entry_group', text=str(i) if altdisplay else "", icon='NONE' if altdisplay else VBM_QUEUEGROUPICON[i])
                    op.queue = queue.name
                    op.group = i
                
                # IDs
                r = bb.row()
                r.prop(queue, 'id_armature', text="", icon='ARMATURE_DATA')
                r.prop(queue, 'id_collection', text="", icon='OUTLINER_COLLECTION')
                r.prop(queue, 'id_pose')
                r = bb.row()
                r.prop_search(queue, 'format', vbm, 'formats')
                r.prop(queue, 'copy_textures')
                r = bb.row()
                r.prop(queue, '["filepath"]', text="", icon='FILEBROWSER')
classlist.append(VBM_PT_Queues)

# ------------------------------------------------------------------------------------------
class VBM_PT_Format(bpy.types.Panel):
    bl_label = "Vertex Formats"
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "scene"
    bl_parent_id = 'VBM_PT_Master'
    
    def draw(self, context):
        vbm = context.scene.vbm
        
        layout = self.layout.column()
        
        r = layout.row(align=False)
        rr = r.row(align=True)
        rr.operator('vbm.format_export', text="Export", icon='EXPORT').format = vbm.formats[vbm.formats_index].name if vbm.formats else ""
        rr.operator('vbm.format_export', text="All").format = ""
        rr = r.row(align=True)
        rr.operator('vbm.format_import', text="Import", icon='IMPORT')
        
        r = layout.row(align=True)
        c = r.column(align=True)
        c.template_list("VBM_UL_Format", "", vbm, "formats", vbm, "formats_index", rows=3)
        r.separator()
        
        c = r.column(align=True)
        c.scale_y = 0.9
        c.operator('vbm.format_add', text="", icon='ADD')
        c.operator('vbm.format_remove', text="", icon='REMOVE').index = vbm.formats_index
        c.separator()
        c.operator('vbm.format_move', text="", icon='TRIA_UP').move_down = False
        c.operator('vbm.format_move', text="", icon='TRIA_DOWN').move_down = True
        c.separator()
        c.operator('vbm.format_clear', text="", icon='X')
        
        # Attributes
        if len(vbm.formats) > 0:
            format = vbm.formats[vbm.formats_index]
            b = layout.box().column(align=False)
            b.prop(format, 'name', text="", emboss=False)
            format.DrawPanel(b, True)
        else:
            layout.label(text="(No Active Format)")
classlist.append(VBM_PT_Format)

# ==============================================================================================

# ------------------------------------------------------------------------------------------
class VBM_PT_BoneDissolve(bpy.types.Panel):
    bl_label = "Bone Dissolves"
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "data"
    bl_options = {'DEFAULT_CLOSED'}
    
    def draw(self, context):
        vbm = context.scene.vbm
        layout = self.layout
        obj = context.object
        
        if obj and obj.type == 'ARMATURE':
            c = layout.column()
            
            c.prop_search(obj, 'vbm_format', vbm, 'formats')
            
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
    bl_options = {'DEFAULT_CLOSED'}
    
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
    
    queues : bpy.props.CollectionProperty(name="Queues", type=VBM_PG_ExportQueue_Entry)
    queues_index : bpy.props.IntProperty(name="Queue Index", min=0)
    queue_group_enabled : bpy.props.BoolVectorProperty(name="Queue Groups", size=32, default=tuple([True for i in range(0,32)]))
    
    display_queue_group_indices : bpy.props.BoolProperty(name="Display Group Indices", default=False)
    display_queue_group_paths : bpy.props.BoolProperty(name="Display Group Paths", default=False)
    display_queue_active : bpy.props.BoolProperty(name="Display Active Queue Properties", default=True)
    
    write_to_cache : bpy.props.BoolProperty(
        name="Write To Cache", default=True,
        description="Save export data on object to speed up repeat exports")
    
    write_to_recent : bpy.props.BoolProperty(
        name="Write To Recent", default=True,
        description="Save export parameters on object for one-click re-exports")
    
    datafiles_path : bpy.props.StringProperty(
        name="Data Files Path", default="", subtype='DIR_PATH',
        description="Path to prepend to queue paths."
    )
    
    def ToProjectPath(self, path):
        datafilespath = os.path.abspath(bpy.path.abspath(self.datafiles_path))
        projectpath = os.path.abspath(bpy.path.abspath(path))
        if datafilespath in projectpath:
            return projectpath.replace(datafilespath, VBM_PROJECTPATHKEY)
        return path
    
    def FromProjectPath(self, path):
        return path.replace(VBM_PROJECTPATHKEY, self.datafiles_path).replace("\\/", "/").replace("/\\", "/")
    
    def RefreshQueues(self):
        queues = self.queues
        groups = self.queue_groups
        
        for q in queues:
            groups = groups[q.group]
            if q.name not in g.group.files:
                [g.remove(f) for g in groups for f in g.files if f.name == q.name]
                group.files.add().name = q
        
        queuenames = [x.name for x in queuenames]
        [g.files.remove(f) for g in groups for f in g.files if f.name not in queuenames]
    
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
            
            print(format)
            
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
                            print(k, "UNITS", defaultvalue)
                        
                    i += 1
                
                attribparams.append((k, size, layer, srgb, list(defaultvalue)))
        else:
            attribparams = [(
                a.type, 
                a.size, 
                a.layer, 
                a.convert_to_srgb,
                (
                    ([x/255.0 for x in a.padding_bytes] if a.type in (VBF_PAB, VBF_GRB) else a.padding_bytes)
                    if a.type in VBFUseBytes else a.padding_floats
                )
            )
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
    
    # Returns map {meshname: (vbdata, numvertices, material_name)}
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
        group_by_material=False,
        ):
        vbm = self
        outmap = {} # {mtl_name: data}
        mtlkey = {}
        
        context = bpy.context
        
        pre_script = bpy.data.texts.get(pre_script, None) if pre_script else None
        post_script = bpy.data.texts.get(post_script, None) if post_script else None
        
        attribparams = bpy.context.scene.vbm.ParseFormatString(format)
        vbmap = {}
        process_bones = sum([att[0] in (VBF_BON, VBF_BOB) for att in attribparams]) > 0
        process_tangents = sum([att[0] in (VBF_TAN, VBF_BTN) for att in attribparams]) > 0
        process_groups = sum([att[0] in (VBF_GRO, VBF_GRB) for att in attribparams]) > 0
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
                    m2 = obj.modifiers.new(name=m1.name, type=m1.type)
                    for prop in [p.identifier for p in m1.bl_rna.properties if not p.is_readonly]:
                        setattr(m2, prop, getattr(m1, prop))
            return obj
        
        def ObjChecksum(obj):
            return int(sum([z*13 for z in
                [
                    alphanumeric_modifiers, 
                    flip_uvs, 
                    sum([ord(x) for x in pre_script.as_string()]) if pre_script else 0,
                    sum([ord(x) for x in post_script.as_string()]) if post_script else 0,
                    context.scene.render.use_simplify * context.scene.render.simplify_subdivision
                ] + 
                ((
                    [x for v in obj.data.vertices for x in ([xx*10 for xx in v.co]+[xx for vge in v.groups for xx in (vge.group, vge.weight)])] +
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
                    ([
                        (sum([ord(x) for x in obj.data.uv_layers.active.name]) if obj.data.uv_layers else 0) +
                        (
                            (sum([ord(x) for x in obj.data.color_attributes.active_color.name]) if obj.data.color_attributes else 0) if USE_ATTRIBUTES else
                            (sum([ord(x) for x in obj.data.vertex_colors.active.name]) if obj.data.vertex_colors else 0)
                        )
                    ])
                ) if obj.type == 'MESH' else [] ) + 
                ([x for b in armature.data.bones for v in b.matrix_local for x in v] if armature else []) + 
                (
                    [x for fc in armature.animation_data.action.fcurves for k in fc.keyframe_points for x in k.co]
                    if (apply_armature and armature and armature.animation_data and armature.animation_data.action) else []
                ) + 
                ([ord(x) for b in boneorder for x in b]) + 
                ([ObjChecksum(c) for c in obj.children] if obj.instance_type in ('VERTICES', 'FACES') else [])
            ]))
        
        # Cache Key
        attribstr = ""
        
        for att in attribparams: # [key, size, layer, srgb, default_value]
            k, size, layer, srgb, default_value = att
            s = k[:3]
            s += str(size)
            if layer != LYR_RENDER:
                s += layer[:4]
            if k in VBFUseVCLayer and srgb:
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
                    if fast or instobj.type != 'MESH':
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
                        
                        # Pre-Calculation Script
                        if pre_script:
                            bpy.context.view_layer.update()
                            context.scene['VBM_EXPORTING'] = True
                            exec(pre_script.as_string())
                            context.scene['VBM_EXPORTING'] = False
                        
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
                    
                    # Post-Calculation Script
                    if post_script:
                        context.scene['VBM_EXPORTING'] = True
                        exec(post_script.as_string())
                        context.scene['VBM_EXPORTING'] = False
                    
                    # Collect data
                    if instobj.matrix_world.determinant() < 0:
                        # Blender corrects normals for negative scale on display, not in raw data
                        mesh.flip_normals()
                    mesh.calc_loop_triangles()
                    mesh.calc_normals_split()
                    
                    if mesh.uv_layers and process_tangents:
                        mesh.calc_tangents()
                    
                    meshverts = tuple(mesh.vertices)
                    
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
                    
                    looptovertex = tuple([meshverts[i] for i in facevertindices])
                    
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
                            
                            if n == 0:
                                vbones[vi] = (0,0,0,0)
                                vweights[vi] = numpy.array([1,1,1,1])
                                vnumbones[vi] = 4
                            else:
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
                    NumpyUnitsToBytes = lambda nparray : numpy.frombuffer( (nparray * 255.0).astype(numpy.uint8).tobytes(), dtype=numpy.uint8 )
                    NumpyByteToBytes = lambda nparray : numpy.frombuffer( (nparray).astype(numpy.uint8).tobytes(), dtype=numpy.uint8 )
                    
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
                                if flip_uvs:
                                    attdata = numpy.array([ x for i in faceloopindices for v in [uniquedata[i*2:i*2+size]] for x in (v[0], 1.0-v[1])], dtype=numpy.float32)
                            else:
                                attdata = NumpyCreatePattern(default_value[:size], numelements)
                            if k == VBF_UVS:
                                bcontiguous.append( NumpyFloatToBytes(attdata) )
                            else:
                                bcontiguous.append( NumpyUnitsToBytes(attdata) )
                        # Color
                        elif k == VBF_COL or k == VBF_RGB:
                            if USE_ATTRIBUTES:
                                lyr = mesh.color_attributes.get(layer) if layer in mesh.color_attributes.keys() else mesh.color_attributes.active_color
                            else:
                                lyr = mesh.vertex_colors.get(layer) if layer in mesh.vertex_colors.keys() else mesh.vertex_colors.active
                            if lyr:
                                uniquedata = numpy.empty(numloops * 4, dtype=numpy.float32)
                                lyr.data.foreach_get('color', uniquedata)
                                
                                if (USE_ATTRIBUTES and isSrgb):
                                    numpy.power(uniquedata, numpy.array([.4545, .4545, .4545, 1.0] * numloops), uniquedata)
                                elif (not USE_ATTRIBUTES) and (not isSrgb):
                                    numpy.power(uniquedata, numpy.array([2.2, 2.2, 2.2, 1.0] * numloops), uniquedata)
                                
                                attdata = numpy.array([ uniquedata[i*4:i*4+size] for i in faceloopindices], dtype=numpy.float32)
                            else:
                                attdata = NumpyCreatePattern(default_value[:size], numelements)
                            if k == VBF_COL:
                                bcontiguous.append( NumpyFloatToBytes(attdata) )
                            else:
                                bcontiguous.append( NumpyUnitsToBytes(attdata) )
                        # Bones
                        elif k == VBF_BON or k == VBF_BOB:
                            uniquedata = numpy.empty((numverts * size), dtype=numpy.float32 if k == VBF_BON else numpy.int8)
                            for vi in range(0, numverts):
                                uniquedata[vi*size:vi*size+size] = vbones[vi][:size]
                            
                            attdata = numpy.array([ uniquedata[i*size:i*size+size] for i in facevertindices], dtype=numpy.float32)
                            if k == VBF_BON:
                                bcontiguous.append( NumpyFloatToBytes(attdata) )
                            else:
                                bcontiguous.append( NumpyUnitsToBytes(attdata/255.0) )
                        # Weights
                        elif k == VBF_WEI or k == VBF_WEB:
                            uniquedata = numpy.empty((numverts * size), dtype=numpy.float32)
                            for vi in range(0, numverts):
                                uniquedata[vi*size:vi*size+size] = vweights[vi][:size] / sum(vweights[vi][:size])
                            attdata = numpy.array([ uniquedata[i*size:i*size+size] for i in facevertindices], dtype=numpy.float32)
                            if k == VBF_WEI:
                                bcontiguous.append( NumpyFloatToBytes(attdata) )
                            else:
                                bcontiguous.append( NumpyUnitsToBytes(attdata) )
                        # Groups
                        elif k == VBF_GRO or k == VBF_GRB:
                            vg = obj.vertex_groups.get(layer, None)
                            if vg != None:
                                vgindex = vg.index
                                uniquedata = numpy.array([
                                    vg.weight(i) if sum([vge.group == vgindex for vge in v.groups]) else 0.0
                                    for i,v in enumerate(meshverts) 
                                ], dtype=numpy.float32)
                                attdata = numpy.array([ uniquedata[i] for i in facevertindices], dtype=numpy.float32)
                            else:
                                attdata = NumpyCreatePattern(default_value[:1], numelements)
                            
                            if k == VBF_GRO:
                                bcontiguous.append( NumpyFloatToBytes(attdata) )
                            else:
                                bcontiguous.append( NumpyUnitsToBytes(attdata) )
                        # Padding
                        elif k == VBF_PAD or k == VBF_PAB:
                            attdata = NumpyCreatePattern(default_value[:size], numelements)
                            if k == VBF_PAD:
                                bcontiguous.append( NumpyFloatToBytes(attdata) )
                            else:
                                bcontiguous.append( NumpyUnitsToBytes(attdata) )
                    
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
                vbmap[sourceobj.name] = (
                    vbmesh, 
                    netnumelements, 
                    instobj.active_material.name if instobj.active_material else ""
                )
                
                if vbm.write_to_cache:
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
    bpy.types.Action.vbm = bpy.props.PointerProperty(name="VBM Settings", type=VBM_PG_Action_Settings)
    
    bpy.types.Armature.vbm_dissolve_list = bpy.props.PointerProperty(type=VBM_PG_BoneDissolveList)
    bpy.types.Armature.vbm_action_list = bpy.props.CollectionProperty(type=VBM_PG_Action)
    bpy.types.Armature.vbm_action_list_index = bpy.props.IntProperty(name="Index")
    bpy.types.Object.vbm_format = bpy.props.StringProperty(name="Format")

def unregister():
    for c in classlist[::-1]:
        bpy.utils.unregister_class(c)

if __name__ == "__main__":
    register()


