import bpy
import os
import sys
import time

import json
import struct
import zlib
import mathutils

import bmesh
import numpy

from bpy_extras.io_utils import ExportHelper, ImportHelper
from struct import pack as Pack

classlist = []

'# =========================================================================================================================='
'# CONSTANTS'
'# =========================================================================================================================='

VBMVERSION = 2
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
VBF_BOI = 'BONEBYTES'
VBF_WEI = 'WEIGHT'
VBF_WEB = 'WEIGHTBYTES'
VBF_GRO = 'VERTEXGROUP'
VBF_PAD = 'PAD'
VBF_PAB = 'PADBYTES'

VBFByteType = [VBF_UVB, VBF_RGB, VBF_BOI, VBF_WEB, VBF_PAB]
VBFSizeControl = [VBF_POS, VBF_NOR, VBF_TAN, VBF_BTN, VBF_COL, VBF_RGB, VBF_BON, VBF_BOI, VBF_WEI, VBF_WEB, VBF_PAD, VBF_PAB]
VBFUseVCLayer = [VBF_COL, VBF_RGB]
VBFUseUVLayer = [VBF_UVS, VBF_UVB]
VBFUsePadding = [VBF_PAD, VBF_PAB]

LYR_GLOBAL = '<GLOBAL>'
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
    VBF_BOI: 4,
    VBF_WEI: 4, 
    VBF_WEB: 4,
    VBF_GRO: 1,
    VBF_PAD: 4,
    VBF_PAB: 4,
    }

VBFVarname = {
    VBF_000: "in_???",
    VBF_POS: "in_Position",
    VBF_UVS: "in_TextureCoord", 
    VBF_UVB: "in_TextureCoord", 
    VBF_NOR: "in_Normal",
    VBF_TAN: "in_Tangent",
    VBF_BTN: "in_Bitangent",
    VBF_COL: "in_Colour",
    VBF_RGB: "in_Colour",
    VBF_BON: "in_Bone",
    VBF_BOI: "in_Bone",
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
    (VBF_BOI, 'Bone Index Bytes', '4 Bytes = Size of 1 Float in format 0xWWZZYYXX', 'BONE_DATA', 10),
    (VBF_WEI, 'Weights', '4* Floats', 'MOD_VERTEX_WEIGHT', 11),
    (VBF_WEB, 'Weight Bytes', '4 Bytes = Size of 1 Float in format 0xWWZZYYXX', 'MOD_VERTEX_WEIGHT', 12),
    (VBF_GRO, 'Vertex Group', '1 Float', 'GROUP_VERTEX', 13),
    (VBF_PAD, 'Padding', 'X Floats', 'LINENUMBERS_ON', 98),
    (VBF_PAB, 'Padding Bytes', 'X Bytes', 'LINENUMBERS_ON', 99),
)

VBFIcon = {x[0]: x[3] for x in Items_VBF}

VBFTypeIndex = {x[1]: x[0] for x in enumerate([
    VBF_000,
    VBF_POS,
    VBF_UVS,
    VBF_NOR,
    VBF_COL,
    VBF_RGB,
    VBF_WEI,
    VBF_WEB,
    VBF_BON,
    VBF_BOI,
    VBF_TAN,
    VBF_BTN,
    VBF_GRO,
    VBF_UVB,
    VBF_PAD,
    VBF_PAB,
    ])}

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
'# FUNCTIONS'
'# =========================================================================================================================='

PackString = lambda x: b'%c%s' % (len(x), str.encode(x))
PackVector = lambda f, v: struct.pack(f*len(v), *(v[:]))
PackMatrix = lambda f, m: b''.join( [struct.pack(f*4, *x) for x in m.copy().transposed()] )
QuatValid = lambda q: q if q.magnitude != 0.0 else [1.0, 0.0, 0.0, 0.00001]

def RemoveTempObjects():
    [
        data.remove(x, do_unlink=True) 
        for data in [bpy.data.objects, bpy.data.meshes, bpy.data.armatures] 
        for x in list(data)[::-1] if '__temp' in x.name
    ]

# ---------------------------------------------------------------------------------------

def CompressAndWrite(out, compression_level, path):
    if os.path.basename(path) == '':
        path += bpy.path.basename(bpy.context.blend_data.filepath)
    
    if compression_level != 0:
        outcompressed = zlib.compress(out, level=compression_level)
    else:
        outcompressed = out
    
    outlen = (max(1, len(out)), len(outcompressed))
    
    file = open(path, 'wb')
    file.write(outcompressed)
    file.close()
    
    print(
        "Data of size %.2fKB (%.2f%% of original size) written to \"%s\"" % 
        (outlen[1] / 1000, 100.0 * outlen[1] / outlen[0], path) 
        )

# ---------------------------------------------------------------------------------------

def ParseAttribFormat(self, context):
    format = []
    vclayertarget = []
    uvlayertarget = []
    
    # For each attribute
    attributes = context.scene.vbm.formats.FindItem(self.format, self.attribute_list_dialog).GetItems()
    
    for item in attributes:
        type = item.type
        vctarget = item.layer
        uvtarget = item.layer
        
        # Only append if attribute type is set
        if type != VBF_000:
            if vctarget == LYR_GLOBAL:
                vctarget = LYR_RENDER if self.color_layer_target == 'render' else LYR_SELECT
            if uvtarget == LYR_GLOBAL:
                uvtarget = LYR_RENDER if self.uv_layer_target == 'render' else LYR_SELECT
            
            format.append(type)
            vclayertarget.append(vctarget)
            uvlayertarget.append(uvtarget)
    
    # Print format to console
    print('> Format:', [
        (f, attributes[i].size, attributes[i].layer) if format[i] in VBFUseVCLayer else # Print VC Attribute
        (f, attributes[i].size, attributes[i].layer) if format[i] in VBFUseUVLayer else # Print UV Attribute
        (f, attributes[i].size, attributes[i].layer) if format[i] == VBF_GRO else # Print Vertex Group
        (f, attributes[i].size) # Print Float Attribute
        for i,f in enumerate(format)
        ])
    return (format, vclayertarget, uvlayertarget)

# ---------------------------------------------------------------------------------------

def GetCorrectiveMatrix(self, context):
    mattran = mathutils.Matrix()
    u = self.up_axis
    f = self.forward_axis
    uvec = mathutils.Vector( ((u=='+x')-(u=='-x'), (u=='+y')-(u=='-y'), (u=='+z')-(u=='-z')) )
    fvec = mathutils.Vector( ((f=='+x')-(f=='-x'), (f=='+y')-(f=='-y'), (f=='+z')-(f=='-z')) )
    rvec = fvec.cross(uvec)
    
    # Create rotation
    mattran = mathutils.Matrix()
    mattran[0][0:3] = rvec
    mattran[1][0:3] = fvec
    mattran[2][0:3] = uvec
    
    # Create and apply scale
    mattran = mathutils.Matrix.LocRotScale(None, None, self.scale) @ mattran
    
    return mattran

# --------------------------------------------------------------------------------------------------

def GenerateSettings(self, context, format):
    attributelist = context.scene.vbm.formats.FindItem(self.format, self.attribute_list_dialog)
    attributeitems = attributelist.GetItems()
    
    return {
        'format' : format,
        'edges_only' : self.edges_only,
        'apply_armature' : self.apply_armature,
        'deform_only' : self.deform_only,
        'uvlayertarget': self.uv_layer_target == 'render',
        'colorlayertarget': self.color_layer_target == 'render',
        'matrix': GetCorrectiveMatrix(self, context),
        'max_subdivisions': self.max_subdivisions,
        'flip_normals': self.flip_normals,
        'reverse_winding': self.reverse_winding,
        'flip_uvs': self.flip_uvs,
        'floattype': self.float_type,
        'attributesizes': [att.size for att in attributeitems],
        'gammacorrect': [att.convert_to_srgb for att in attributeitems],
        'vgrouptargets': [att.layer for att in attributeitems],
        'weight_default': self.vertex_group_default_weight,
        
        'paddingfloats': [att.padding_floats for att in attributeitems],
        'paddingbytes': [att.padding_bytes for att in attributeitems],
    }

# --------------------------------------------------------------------------------------------------

def Items_Collections(self, context):
    out = [('<SELECTED>', '(Selected Objects)', 'Export selected objects', 'RESTRICT_SELECT_OFF', 0)]
    
    # Export Lists
    for i, x in enumerate(context.scene.vbm.export_lists.items):
        out += [(EXPORTLISTHEADER + x.name, x.name, 'Export from export list "%s"' % x.name, 'PRESET', len(out))]
    
    # Iterate through scene collections
    def ColLoop(c, out, depth=0):
        out += [(c.name, '. '*depth+c.name, 'Export all objects in collection "%s"' % c.name, 'OUTLINER_COLLECTION', len(out))]
        
        for cc in c.children:
            ColLoop(cc, out, depth+1)
    ColLoop(context.scene.collection, out)
    return out

# ---------------------------------------------------------------------------------------

def CollectionToObjectList(name, selected_on_miss=True):    
    outobjects = []
    alphasort = lambda x: x.name
    context = bpy.context
    
    # Scene Collection
    if name == context.scene.collection.name:
        outobjects = sorted([x for x in context.scene.collection.all_objects], key=alphasort)
    # Export List
    elif name[:len(EXPORTLISTHEADER)] == EXPORTLISTHEADER:
        exportlistname = name[len(EXPORTLISTHEADER):]
        exportlist = context.scene.vbm.export_lists.FindItem(exportlistname)
        if exportlist:
            return exportlist.GetObjects()
        else:
            return []
    
    # Collections
    if not outobjects:
        if name in [x.name for x in bpy.data.collections]:
            outobjects = sorted([x for x in bpy.data.collections[name].all_objects], key=alphasort)
        # Selected Objects
        elif selected_on_miss:
            outobjects = sorted([x for x in context.selected_objects], key=alphasort)
    
    if not self.export_hidden:
        outobjects = [x for x in outobjects if not x.hide_get()]
    
    return [x for x in outobjects if x.type in VALIDOBJTYPES]

# ---------------------------------------------------------------------------------------

def FixName(name, delimiter_start="", delimiter_end=""):
    if delimiter_start != "" and delimiter_start in name:
        name = name[name.find(delimiter_start)+1:]
    if delimiter_end != "" and delimiter_end in name:
        name = name[:name.find(delimiter_end)]
    return name

# ---------------------------------------------------------------------------------------

def ParseDeformParents(armatureobj):
    bonelist = armatureobj.data.bones
    deformbones = [b for b in bonelist if b.use_deform]
    
    outparents = {}
    
    def FindFirstDeform(bone, usedbones=[]):
        if not bone.parent:
            return None
        
        usedbones.append(bone)
        basename = bone.name[bone.name.find("-")+1:]
        
        nextdeforms = [x for x in deformbones 
            if (x not in usedbones and x.name[-len(basename):] == basename and x.use_deform)]
        
        #print("   ", b.name, [x.name for x in nextdeforms])
        
        if bone.use_deform:
            return bone
        if nextdeforms:
            return nextdeforms[0]
        return FindFirstDeform(bone.parent, usedbones)
    
    for b in deformbones:
        if not b.parent:
            outparents[b.name] = None
            continue
        
        # Find next deform parent
        if b.parent in deformbones:
            outparents[b.name] = b.parent.name
        else:
            #print(b.name)
            p = FindFirstDeform(b.parent, [b])
            outparents[b.name] = p.name if p else None
    
    bonenames =  [b.name for b in bonelist]
    sorted = list(outparents.items())
    sorted.sort(key=lambda x: bonenames.index(x[1]) if x[1] else 0)
    
    return outparents

# ---------------------------------------------------------------------------------------

'# =========================================================================================================================='
'# PROPERTY GROUPS'
'# =========================================================================================================================='

class DMR_ItemGroup_Super(bpy.types.PropertyGroup):
    def UpdateActive(self, context):
        self.active = self.items[self.item_index] if self.size > 0 else None
    
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
            item.name = name
        return item
    
    def RemoveAt(self, index):
        if len(self.items) > 0:
            self.items.remove(index)
            self.size -= 1
            
            self.item_index = max(min(self.item_index, self.size-1), 0)
    
    def Clear(self):
        self.items.clear()
        self.size = 0
        self.item_index = 0
    
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


