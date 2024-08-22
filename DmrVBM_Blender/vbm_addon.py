import bpy
import os
import mathutils
import zlib
import numpy
import struct
import timeit
import time
import json

import gpu
import math
from gpu_extras.batch import batch_for_shader
from math import sin, cos
from mathutils import Matrix, Vector
PI = math.pi

from bpy_extras.io_utils import ExportHelper, ImportHelper

classlist = []

Pack = struct.pack
PackVector = lambda t,v: b''.join([Pack(t, x) for x in v])
PackString = lambda s: Pack('B', len(s)) + b''.join([Pack('B', ord(x)) for x in s])

TEST_ITERATIONS = 1
VBM_FORMAT_KEY = 'PADDING POSITION COLOR UV NORMAL TANGENT BITANGENT BONE WEIGHT GROUP'.split()

VBM_BLENDER_4_0 = bpy.app.version < (4,2,0)

VBM_FORMAT_FL_ISBYTE = 1<<0
VBM_FORMAT_FL_SRGB = 1<<1
VBM_FORMAT_CODEDEFAULT = 'POSITION COLOR4B-SRGB UV'

VBM_MESH_FL_ISEDGE = 1<<0

ANIMATION_FL_CYCLIC = 1<<0

VBM_PANEL_TITLE = "DmrVBM v1.4-BETA"
VBM_PROJECTPATHKEY = "<PROJECTPATH>"

VBM_ATTRIBUTE_UI = ( # (name, size, isbyte, icon, varname, varparts)
    ('PADDING',     "Use default value parameter", 4, 0, 'LINENUMBERS_ON', 'in_Color', 'xyzw'),
    ('POSITION',    "Vertex position", 3, 0, 'VERTEXSEL', 'in_Position', 'xyzw'),
    ('COLOR',       "Color attribute from layer", 4, 1, 'COLOR', 'in_Color', 'rgba'),
    ('UV',          "", 2, 0, 'UV', 'in_TextureCoord', 'uv'),
    ('NORMAL',      "Loop normal", 3, 0, 'NORMALS_VERTEX', 'in_Normal', 'nx ny nz 0'.split()),
    ('TANGENT',     "Tangent calculated on export", 3, 0, 'NORMALS_VERTEX_FACE', 'in_Tangent', 'tx ty tz 0'.split()),
    ('BITANGENT',   "Bitangent calculated on export", 3, 0, 'NORMALS_VERTEX_FACE', 'in_Bitangent', 'tx ty tz 0'.split()),
    ('BONE',        "Bone index (requires armature)", 4, 1, 'BONE_DATA', 'in_Bone', 'b0 b1 b2 b3'.split()),
    ('WEIGHT',      "Bone weight (requires armature)", 4, 1, 'MOD_VERTEX_WEIGHT', 'in_Weight', 'w0 w1 w2 w3'.split()),
    ('GROUP',       "Vertex group weight", 4, 0, 'GROUP_VERTEX', 'in_Group', 'vvvv'),
)
VBM_ATTRIBUTE_NAME = [x[0] for x in VBM_ATTRIBUTE_UI]
VBM_ATTRIBUTE_DESC, VBM_ATTRIBUTE_SIZE, VBM_ATTRIBUTE_ISBYTE, VBM_ATTRIBUTE_ICON, VBM_ATTRIBUTE_VARNAME, VBM_ATTRIBUTE_VARPART = [
    {x[0]: x[i] for x in VBM_ATTRIBUTE_UI} for i in (1,2,3,4,5,6)]
VBM_ATTRIBUTE_ITEMS = [(VBM_ATTRIBUTE_NAME[i], VBM_ATTRIBUTE_NAME[i], VBM_ATTRIBUTE_DESC[k], VBM_ATTRIBUTE_ICON[k], i) for i,k in enumerate(VBM_ATTRIBUTE_NAME)]

VBM_QUEUE_GROUPICON = ['DECORATE_KEYFRAME']+['SEQUENCE_COLOR_%02d'%(i+1) for i in range(0, 8)]
VBM_QUEUE_GROUPICON2 = ['EVENT_'+x+"_KEY" for x in 'ZERO ONE TWO THREE FOUR FIVE SIX SEVEN EIGHT NINE'.split()]

VBM_BATCH_ITEMS = (
    ('NONE', "None", "No Batching"),
    ('OBJECT', "By Object", "Files will be written per object as \"<filename><object_name>\""),
    ('MESH', "By Mesh", "Files will be written per mesh as \"<filename><mesh_name>\""),
    ('ARMATURE', "By Armature", "Files will be written per armature as \"<filename><skeleton_name>\""),
    ('COLLECTION', "By Collection", "Files will be written per collection as \"<filename><collection_name>\""),
)

VBM_GROUPING_ITEMS = (
    ('OBJECT', "By Object", "Objects -> VBs"),
    ('MATERIAL', "By Material", "Material -> VBs"),
    ('FRAME', "By Frame", "Frame -> VBs"),
)

VBM_CHECKOUTGROUPING_ITEMS = (
    ('NONE', "(Settings)", "Use grouping method set during export"),
    ('OBJECT', "By Object", "Objects -> VBs"),
    ('MATERIAL', "By Material", "Material -> VBs"),
    ('FRAME', "By Frame", "Frame -> VBs"),
)

VBM_FILETYPE_ITEMS=(
    ('VB', "Vertex Buffer", "Export geometry data as raw vertex buffer"),
    ('VBM', "VBM", "Export organized data as vbm file")
)

VBM_DESCRIPTIONS = {
    'compression': "",
    'batching': "Method to split files",
    'collection': "Collection to export",
    'format_code': "String alternative to setting vertex format",
    'format': "Name of defined scene format. If valid, overrides format code.",
    'texture_export': "Write textures into file",
    'mesh_export': "Write mesh to file",
    'mesh_grouping': "Method to split vertex buffers.",
    'mesh_material_override': "Mesh material to set for all meshes",
    'mesh_script_pre': "Script to execute before applying modifiers and transforms",
    'mesh_script_post': "Script to execute after applying modifiers and transforms",
    'mesh_delimiter_start': "Remove beginning of mesh name up to and including this character",
    'mesh_delimiter_end': "Remove end of mesh name including this character",
    'mesh_flip_uvs': "Flip UVs such that top left of texture is y = 0",
    'mesh_alledges': "Export mesh as edges",
    'skeleton_export': "Write skeleton data to file",
    'skeleton_delimiter_start': "Remove beginning of bone name up to and including this character",
    'skeleton_delimiter_end': "Remove end of bone name including this character",
    'skeleton_swing': "Export swing bone information",
    'skeleton_colliders': "Export collider bone information",
    'action_export': "Write animation data to file",
    'action_delimiter_start': "Remove beginning of action name up to and including this character",
    'action_delimiter_end': "Remove end of action name including this character",
    'action_clean_threshold': "Clean keyframes of animation spaced within this threshold",
    'is_srgb': "Apply gamma correction to values. Enable for color values, disable for data values",
    'is_byte': "Export values as bytes",
}

VBM_CLEANUPKEYS = 'OBJECT ARMATURE ACTION IMAGE'.split()

VBM_ICON_SWING = 'CON_SPLINEIK'
VBM_ICON_COLLIDER = 'PHYSICS'

VBM_SWINGCIRCLEPRECISION = 16
VBM_SWINGLIMITN = 5
VBM_SWINGLIMITSEP = 0.25*PI / VBM_SWINGLIMITN

'# =========================================================================================================================='
'# STRUCTS'
'# =========================================================================================================================='

# ------------------------------------------------------------------------------
class VBM_PG_Label(bpy.types.PropertyGroup):
    pass
classlist.append(VBM_PG_Label)

# ================================================================================================
class VBM_PG_FormatAttribute(bpy.types.PropertyGroup):
    def UpdateValue(self, context):
        if not self.get('mutex', 0):
            self['mutex'] = 1
            if self.is_byte:
                self.value_float = [x/255.0 for x in self.value_byte]
            else:
                self.value_byte = [int(x*255.0) for x in self.value_float]
            [f.UpdateCode(context) for f in context.scene.vbm.formats if self in list(f.attributes)]
            self['mutex'] = 0
    def UpdateCode(self, context):
        if not self.get('mutex', 0):
            self['mutex'] = 1
            [f.UpdateCode(context) for f in context.scene.vbm.formats if self in list(f.attributes)]
            self['mutex'] = 0
    
    attribute: bpy.props.EnumProperty(default='PADDING', items=VBM_ATTRIBUTE_ITEMS, update=UpdateCode)
    size: bpy.props.IntProperty(name="Size", default=4, min=1, max=4, update=UpdateCode, options=set())
    layer: bpy.props.StringProperty(name="Layer", update=UpdateCode, options=set())
    value_float: bpy.props.FloatVectorProperty(size=4, default=(0,0,0,0), update=UpdateValue, options=set())
    value_byte: bpy.props.IntVectorProperty(size=4, min=0, max=255, default=(0,0,0,0), update=UpdateValue, options=set())
    is_byte: bpy.props.BoolProperty(name="Is Bytes", default=False, description=VBM_DESCRIPTIONS['is_byte'], update=UpdateCode, options=set())
    is_srgb: bpy.props.BoolProperty(name="Is SRGB", default=True, description=VBM_DESCRIPTIONS['is_srgb'], update=UpdateCode, options=set())
    use_material_color: bpy.props.BoolProperty(name="Use Material Color", default=True, update=UpdateCode, options=set())
classlist.append(VBM_PG_FormatAttribute)

# ------------------------------------------------------------------------------
class VBM_PG_Format(bpy.types.PropertyGroup):
    def SetCode(self, context):
        if not self.get('mutex', 0):
            self['mutex'] = 1
            fmt = context.scene.vbm.FormatStringDecode(self.code)
            self.attributes.clear()
            for att in fmt:
                item = self.attributes.add()
                k, size, flags, layer, value = att
                item.attribute, item.size, item.is_byte, item.is_srgb, item.layer = (
                    k, size, (flags & VBM_FORMAT_FL_ISBYTE) != 0, (flags & VBM_FORMAT_FL_SRGB) != 0, layer)
                if item.is_byte:
                    item.value_byte = [int(x) for x in value]
                else:
                    item.value_float = [float(x) for x in value]
            self['mutex'] = 0
        self.UpdateCode(context)
    
    def UpdateCode(self, context):
        if not self.get('mutex', 0):
            self['mutex'] = 1
            self.code = " ".join(["%s%d%s%s%s%s" % (
                att.attribute, att.size, "B"*att.is_byte, 
                "-SRGB"*(att.is_srgb and att.attribute=='COLOR'),
                ("{%s}" % att.layer) if att.layer else "",
                (("(%03d,%03d,%03d,%03d)"%tuple(att.value_byte)) if sum(att.value_byte) else "") if att.is_byte else
                (("(%.2f,%.2f,%.2f,%.2f)"%tuple(att.value_float)) if sum(att.value_float) else "")  
                ) for att in self.attributes])
            self.bytesum = sum([a.size*[4,1][a.is_byte] for a in self.attributes])
            self.attributes_index = min(self.attributes_index, len(self.attributes)-1)
            self['mutex'] = 0
    
    def UpdateName(self, context):
        name_last = self.get('name_last', "")
        for queue in context.scene.vbm.queues:
            if queue.format == name_last:
                queue.format = self.name
        self['name_last'] = self.name
    
    name: bpy.props.StringProperty(update=UpdateName)
    attributes: bpy.props.CollectionProperty(type=VBM_PG_FormatAttribute)
    attributes_index: bpy.props.IntProperty(min=0, options=set())
    bytesum: bpy.props.IntProperty(name="Byte Sum", default=0, options=set())
    code: bpy.props.StringProperty(name="", default=VBM_FORMAT_CODEDEFAULT, update=SetCode, options=set())
classlist.append(VBM_PG_Format)

# ===============================================================================================
class VBM_PG_QueueItem(bpy.types.PropertyGroup):
    collection: bpy.props.PointerProperty(type=bpy.types.Collection)
    armature: bpy.props.PointerProperty(type=bpy.types.Object, poll=lambda s,value: value.type=='ARMATURE')
    object: bpy.props.PointerProperty(type=bpy.types.Object)
    action: bpy.props.PointerProperty(type=bpy.types.Action)
    include_child_collections: bpy.props.BoolProperty(name="Include Child Collections", default=False)
    include_child_objects: bpy.props.BoolProperty(name="Include Child Objects", default=True)
    enabled: bpy.props.BoolProperty(name='Enabled', default=True)
    material_override: bpy.props.PointerProperty(name="Material Override", type=bpy.types.Material)
    mesh_grouping: bpy.props.EnumProperty(name="Mesh Grouping", items=VBM_CHECKOUTGROUPING_ITEMS)
classlist.append(VBM_PG_QueueItem)

# ----------------------------------------------------------------------------
class VBM_PG_Queue(bpy.types.PropertyGroup):
    checkout: bpy.props.CollectionProperty(type=VBM_PG_QueueItem)
    checkout_index: bpy.props.IntProperty(min=0)
    group: bpy.props.EnumProperty(name="Group", default=0, items=tuple([(str(i),str(i),str(i), VBM_QUEUE_GROUPICON[i], i) for i in range(0, 8)]))
    enabled: bpy.props.BoolProperty(name="Enabled", default=True)
    
    format: bpy.props.StringProperty(name="Format", options=set())
    format_code: bpy.props.StringProperty(name="Format Code") # Overwrites above
    texture_export: bpy.props.BoolProperty(name="Copy Textures", default=True, description=VBM_DESCRIPTIONS['texture_export'])
    
    mesh_export: bpy.props.BoolProperty(name="Export Meshes", default=True, description=VBM_DESCRIPTIONS['mesh_export'], options=set())
    mesh_grouping: bpy.props.EnumProperty(name="Grouping", default='OBJECT', items=VBM_GROUPING_ITEMS, description=VBM_DESCRIPTIONS['mesh_export'], options=set())
    mesh_alledges: bpy.props.BoolProperty(name="Mesh All Edges", default=False, description=VBM_DESCRIPTIONS['mesh_alledges'], options=set())
    mesh_material_override: bpy.props.PointerProperty(name="Material Override", type=bpy.types.Material, description=VBM_DESCRIPTIONS['mesh_material_override'], options=set())
    mesh_script_pre: bpy.props.PointerProperty(name="Mesh Script Pre", type=bpy.types.Text, description=VBM_DESCRIPTIONS['mesh_script_pre'], options=set())
    mesh_script_post: bpy.props.PointerProperty(name="Mesh Script Post", type=bpy.types.Text, description=VBM_DESCRIPTIONS['mesh_script_post'], options=set())
    
    mesh_delimiter_start: bpy.props.StringProperty(name="Mesh Delimiter Start", default="", description=VBM_DESCRIPTIONS['mesh_delimiter_start'], options=set())
    mesh_delimiter_end: bpy.props.StringProperty(name="Mesh Delimiter End", default="", description=VBM_DESCRIPTIONS['mesh_delimiter_end'], options=set())
    mesh_flip_uvs: bpy.props.BoolProperty(name="Mesh Flip UVs", default=True, description=VBM_DESCRIPTIONS['mesh_flip_uvs'], options=set())
    
    skeleton_export: bpy.props.BoolProperty(name="Export Armature", default=True, description=VBM_DESCRIPTIONS['skeleton_export'], options=set())
    skeleton_swing: bpy.props.BoolProperty(name="Write Swing Data", default=True, description=VBM_DESCRIPTIONS['skeleton_swing'], options=set())
    skeleton_colliders: bpy.props.BoolProperty(name="Write Collider Data", default=True, description=VBM_DESCRIPTIONS['skeleton_colliders'], options=set())
    skeleton_delimiter_start: bpy.props.StringProperty(name="Armature Delimiter Start", default="", options=set())
    skeleton_delimiter_end: bpy.props.StringProperty(name="Armature Delimiter End", default="", options=set())
    
    action_export: bpy.props.BoolProperty(name="Export Actions", default=True, options=set())
    action_delimiter_start: bpy.props.StringProperty(name="Action Delimiter Start", default="", options=set())
    action_delimiter_end: bpy.props.StringProperty(name="Action Delimiter End", default="", options=set())
    action_clean_threshold: bpy.props.FloatProperty(name="Action Clean Threshold", default=0.0004, options=set())
    
    graph_export: bpy.props.BoolProperty(name="Export Graph", default=True, options=set())
    
    filepath: bpy.props.StringProperty(name="Filepath", default="//model.vbm")
classlist.append(VBM_PG_Queue)

# ===============================================================================================

# -----------------------------------------------------------------
class VBM_PG_SkeletonMask_Bone_Swing(bpy.types.PropertyGroup):
    def UpdateEnabled(self, context):
        rig = [rig for rig in bpy.data.objects if rig.type=='ARMATURE' and self in [x.swing for x in rig.vbm.deform_mask]][0]
        rig.vbm.swing_bones.clear()
        for bone in [x for x in rig.vbm.deform_mask if x.swing.enabled]:
            rig.vbm.swing_bones.add().name = bone.name
    
    enabled: bpy.props.BoolProperty(name="Enabled", default=False, options=set(), update=UpdateEnabled)
    is_chain: bpy.props.BoolProperty(name="Is Chain", default=True, options=set())
    friction: bpy.props.FloatProperty(name="Friction", default=0.1, precision=3, options=set())
    stiffness: bpy.props.FloatProperty(name="Stiffness", default=0.1, min=0.0, max=1.0, precision=3, options=set())
    dampness: bpy.props.FloatProperty(name="Dampness", default=0.1, min=0.0, max=1.0, precision=3, options=set())
    gravity: bpy.props.FloatProperty(name="Gravity", default=0.0, precision=3, options=set())
    offset: bpy.props.FloatVectorProperty(name="Offset", size=3, default=(0,0,0), options=set())
    angle_min_x: bpy.props.FloatProperty(name="Angle Min X", default=-.5, min=-3.14, max=3.14, precision=3, options=set())
    angle_max_x: bpy.props.FloatProperty(name="Angle Max X", default=+.5, min=-3.14, max=3.14, precision=3, options=set())
    angle_min_z: bpy.props.FloatProperty(name="Angle Min Z", default=-.5, min=-3.14, max=3.14, precision=3, options=set())
    angle_max_z: bpy.props.FloatProperty(name="Angle Max Z", default=+.5, min=-3.14, max=3.14, precision=3, options=set())
classlist.append(VBM_PG_SkeletonMask_Bone_Swing)

# -----------------------------------------------------------------
class VBM_PG_SkeletonMask_Bone_Collider(bpy.types.PropertyGroup):
    def UpdateEnabled(self, context):
        rig = [rig for rig in bpy.data.objects if rig.type=='ARMATURE' and self in [x.collider for x in rig.vbm.deform_mask]][0]
        rig.vbm.collider_bones.clear()
        for bone in [x for x in rig.vbm.deform_mask if x.collider.enabled]:
            rig.vbm.collider_bones.add().name = bone.name
    
    enabled: bpy.props.BoolProperty(name="Enabled", default=False, options=set(), update=UpdateEnabled)
    is_chain: bpy.props.BoolProperty(name="Is Chain", default=True, options=set())
    radius: bpy.props.FloatProperty(name="Radius", default=0.1, min=0.0, options=set())
    length: bpy.props.FloatProperty(name="Length", default=0.0, min=0.0, options=set())
    offset: bpy.props.FloatVectorProperty(name="Offset", size=3, default=(0,0,0), options=set())
classlist.append(VBM_PG_SkeletonMask_Bone_Collider)

# ------------------------------------------------------------------
class VBM_PG_SkeletonMask_Bone(bpy.types.PropertyGroup):
    def ToggleTree(self, context):
        if self.get('mutex', 0) == 0:
            self['mutex'] = 1
            mask = [id.vbm.deform_mask for id in [x for x in bpy.data.objects if x.type=='ARMATURE']+list(bpy.data.actions) if self in list(id.vbm.deform_mask)][0]
            IsChild = lambda b,p: True if b.name==p.name else IsChild(mask[b.parent], p) if b.parent else False
            children = [b for b in mask if IsChild(b, self) and b!=self]
            alloff = sum([b.enabled for b in children]) == 0
            for b in children:
                b.enabled = alloff
            self.op_toggletree = False
            self['mutex'] = 0
    
    name: bpy.props.StringProperty(name="Name")
    enabled: bpy.props.BoolProperty(name="Enabled", default=True)
    parent: bpy.props.StringProperty(name="Parent", options={'HIDDEN'})
    depth: bpy.props.IntProperty(name="Depth", options={'HIDDEN'})
    op_toggletree: bpy.props.BoolProperty(name="Enabled", default=False, update=ToggleTree)
    
    swing: bpy.props.PointerProperty(name="Swing", type=VBM_PG_SkeletonMask_Bone_Swing)
    collider: bpy.props.PointerProperty(name="Collider", type=VBM_PG_SkeletonMask_Bone_Collider)
classlist.append(VBM_PG_SkeletonMask_Bone)

# -----------------------------------------------------------------
class VBM_PG_SkeletonMask(bpy.types.PropertyGroup):
    def UpdateSwingIndex(self, context):
        if not self.get('mutex', 0):
            self['mutex'] = 1
            bname = self.swing_bones[self.swing_index].name
            self.swing_index = list(self.swing_bones.keys()).index(bname)
            self.collider_index = list(self.collider_bones.keys()).index(bname) if bname in self.collider_bones.keys() else 0
            self.deform_index = list(self.deform_mask.keys()).index(bname)
            self['mutex'] = 0
    def UpdateColliderIndex(self, context):
        if not self.get('mutex', 0):
            self['mutex'] = 1
            bname = self.collider_bones[self.collider_index].name
            print(bname)
            self.collider_index = list(self.collider_bones.keys()).index(bname)
            self.swing_index = list(self.swing_bones.keys()).index(bname) if bname in self.swing_bones.keys() else 0
            self.deform_index = list(self.deform_mask.keys()).index(bname)
            self['mutex'] = 0
    
    deform_mask: bpy.props.CollectionProperty(name="Bones", type=VBM_PG_SkeletonMask_Bone)
    deform_index: bpy.props.IntProperty(name="Index", min=0)
    
    swing_bones: bpy.props.CollectionProperty(name="Swing Bones", type=VBM_PG_Label)
    swing_index: bpy.props.IntProperty(name="Index", min=0, update=UpdateSwingIndex)
    
    collider_bones: bpy.props.CollectionProperty(name="Collider Bones", type=VBM_PG_Label)
    collider_index: bpy.props.IntProperty(name="Index", min=0, update=UpdateColliderIndex)
classlist.append(VBM_PG_SkeletonMask)

# ===============================================================================================
class VBM_PG_Material(bpy.types.PropertyGroup):
    alias: bpy.props.PointerProperty(name="Alias", type=bpy.types.Material)
classlist.append(VBM_PG_Material)

'# =========================================================================================================================='
'# OPERATORS'
'# =========================================================================================================================='

# -------------------------------------------------------------------------------------------
class VBM_OT_SceneTransfer(bpy.types.Operator):
    """Transfer VBM Data from one scene to another"""
    bl_label = "Scene Transfer"
    bl_idname = 'vbm.scene_transfer'
    bl_options = {'REGISTER', 'UNDO'}
    
    scene_source: bpy.props.StringProperty(name="Source Scene")
    scene_target: bpy.props.StringProperty(name="Target Scene")
    prop_type: bpy.props.EnumProperty(name="Property Type", items=tuple([
        (x,x,x) for x in 'FORMAT QUEUE'.split()]))
    prop_name: bpy.props.StringProperty(name="Property Name")
    
    def draw(self, context):
        layout = self.layout
        c = layout.column(align=1)
        c.prop_search(self, 'scene_source', bpy.data, 'scenes', text="Source")
        c.prop_search(self, 'scene_target', bpy.data, 'scenes', text="Target")
        
        src = bpy.data.scenes.get(self.scene_source, None)
        tgt = bpy.data.scenes.get(self.scene_target, None)
        
        if src and src != tgt:
            r = layout.row(align=0)
            r.prop(self, 'prop_type', text="")
            if self.prop_type == 'FORMAT':
                r.prop_search(self, 'prop_name', src.vbm, 'formats', text="Format")
            elif self.prop_type == 'QUEUE':
                r.prop_search(self, 'prop_name', src.vbm, 'queues', text="Queue")
    
    def invoke(self, context, event):
        if self.scene_target and not self.scene_source:
            self.scene_source = ([x.name for x in bpy.data.scenes if x.name != self.scene_target]+[""])[0]
        return context.window_manager.invoke_props_dialog(self)
    
    def execute(self, context):
        src = bpy.data.scenes.get(self.scene_source, None)
        tgt = bpy.data.scenes.get(self.scene_target, None)
        
        if src and tgt and src != tgt:
            if self.prop_type == 'FORMAT':
                format = src.vbm.formats.get(self.prop_name, None)
                if format:
                    item = tgt.vbm.formats.add()
                    item.name = format.name
                    item.code = format.code
            elif self.prop_type == 'QUEUE':
                q1 = src.vbm.queues.get(self.prop_name, None)
                if q1:
                    q2 = tgt.vbm.queues.add()
                    q2.name = q1.name
                    [setattr(q2, p.identifier, getattr(q1, p.identifier)) for p in q1.bl_rna.properties if not p.is_readonly]
                    for c1 in q1.checkout:
                        c2 = q2.checkout.add()
                        [setattr(c2, p.identifier, getattr(c1, p.identifier)) for p in c1.bl_rna.properties if not p.is_readonly]
        
        return {'FINISHED'}
classlist.append(VBM_OT_SceneTransfer)

# -------------------------------------------------------------------------------------------
class VBM_OT_ActionOperator(bpy.types.Operator):
    """Operation for rig actions"""
    bl_label = "Action Operation"
    bl_idname = 'vbm.action_operation'
    bl_options = {'REGISTER', 'UNDO'}
    
    operation: bpy.props.EnumProperty(name="Operation", options={'HIDDEN'}, items=tuple([
        (x,x,x) for x in 'ADD REMOVE MOVE_UP MOVE_DOWN EXPORT IMPORT RESET DISSOLVE_FILL DISSOLVE_CLEAR'.split()]))
    
    def execute(self, context):
        vbm = context.scene.vbm
        rig = context.active_object; rig = (rig if rig.type=='ARMATURE' else rig.find_armature()) if rig else None
        
        if self.operation == 'RESET':
            for action in bpy.data.actions:
                action['VBM_CHECKSUM'] = 0
                action['VBM_CURVEDATA'] = []
        elif self.operation == 'DISSOLVE_FILL':
            queue = vbm.queues[vbm.queues_index]
            vbm.UpdateDeformMask(queue.checkout[queue.checkout_index].action.vbm.deform_mask, rig)
        elif self.operation == 'DISSOLVE_CLEAR':
            queue = vbm.queues[vbm.queues_index]
            queue.checkout[queue.checkout_index].action.vbm.deform_mask.clear()
        return {'FINISHED'}
classlist.append(VBM_OT_ActionOperator)

# -------------------------------------------------------------------------------------------
class VBM_OT_FormatOperation(bpy.types.Operator, ExportHelper):
    """Operation on vertex format list"""
    bl_label = "Format Operation"
    bl_idname = 'vbm.format_operation'
    bl_options = {'REGISTER', 'UNDO'}
    
    filter_glob: bpy.props.StringProperty(default="*.json", options={'HIDDEN'}, maxlen=255)
    filename_ext: bpy.props.StringProperty(default=".json", options={'HIDDEN'})
    
    operation: bpy.props.EnumProperty(name="Operation", options={'HIDDEN'}, items=tuple([
        (x,x,x) for x in 'ADD REMOVE MOVE_UP MOVE_DOWN EXPORT IMPORT GUIDE PAD'.split()]))
    
    def invoke(self, context, event):
        if self.operation in 'EXPORT IMPORT'.split():
            self.filepath = context.scene.vbm.get('VBM_FORMAT_FILEPATH', "//%s.json" % bpy.data.filepath[:bpy.data.filepath.rfind(".")])
            return super().invoke(context, event)
        return self.execute(context)
    
    def execute(self, context):
        vbm = context.scene.vbm
        for pg in [pg for format in vbm.formats for pg in [x for x in format.attributes]+[format]]:
            pg['mutex'] = 0
        
        if self.operation == 'ADD':
            item = vbm.formats.add()
            item.name = 'Format'
            item.code = vbm.formats[vbm.formats_index].code
            if len(vbm.formats) > 1:
                vbm.formats.move(len(vbm.formats)-1, vbm.formats_index)
            else:
                item.code = VBM_FORMAT_CODEDEFAULT
            vbm.formats_index = max(0, min(len(vbm.formats)-1, vbm.formats_index+1))
        elif self.operation == 'REMOVE':
            vbm.formats.remove(vbm.formats_index)
            vbm.formats_index = max(0, min(len(vbm.formats)-1, vbm.formats_index))
        elif self.operation == 'MOVE_UP':
            vbm.formats.move(vbm.formats_index, vbm.formats_index-1)
            vbm.formats_index -= 1
        elif self.operation == 'MOVE_DOWN':
            vbm.formats.move(vbm.formats_index, vbm.formats_index+1)
            vbm.formats_index = max(0, min(len(vbm.formats)-1, vbm.formats_index+1))
        elif self.operation == 'EXPORT':
            vbm['VBM_FORMAT_FILEPATH'] = self.filepath
            outjson = "{" + ",".join(['\n\t"%s": "%s"' % (f.name, f.code) for f in vbm.formats]) + "\n}\n"
            f = open(self.filepath, 'w'); f.write(outjson); f.close()
            self.report({'INFO'}, "Format JSON written to \"%s\"" % self.filepath)
        elif self.operation == 'GUIDE':
            bpy.context.window_manager.clipboard = vbm.FormatGuide(vbm.formats[vbm.formats_index])[:-1]
        elif self.operation == 'IMPORT':
            f = open(self.filepath, 'r')
            injson = json.loads("".join(list(f)))
            f.close()
            if injson:
                for name, code in injson.items():
                    print(name, [code])
                    if name in [x.name for x in vbm.formats]:
                        vbm.formats[name].code = code
                    else:
                        item = vbm.formats.add()
                        item.code = code
                        item.name = name
            self.report({'INFO'}, "Format JSON read from \"%s\"" % self.filepath)
        return {'FINISHED'}
classlist.append(VBM_OT_FormatOperation)

# -------------------------------------------------------------------------------------------
class VBM_OT_FormatAttributeOperation(bpy.types.Operator):
    """Operation on vertex format list"""
    bl_label = "Format Operation"
    bl_idname = 'vbm.format_attribute_operation'
    bl_options = {'REGISTER', 'UNDO'}
    
    operation: bpy.props.EnumProperty(name="Operation", items=tuple([
        (x,x,x) for x in 'ADD REMOVE MOVE_UP MOVE_DOWN PAD'.split()]))
    
    def execute(self, context):
        vbm = context.scene.vbm
        format = vbm.formats[vbm.formats_index]
        
        if self.operation == 'ADD':
            item = format.attributes.add()
        elif self.operation == 'REMOVE':
            format.attributes.remove(format.attributes_index)
            format.attributes_index = max(0, min(len(format.attributes)-1, format.attributes_index))
        elif self.operation == 'MOVE_UP':
            format.attributes.move(format.attributes_index, format.attributes_index-1)
            format.attributes_index -= 1
        elif self.operation == 'MOVE_DOWN':
            format.attributes.move(format.attributes_index, format.attributes_index+1)
            format.attributes_index += 1
        elif self.operation == 'PAD':
            bytesum = format.bytesum
            a = format.attributes.add()
            a.attribute, a.size, a.is_byte = ('PADDING', 4-(bytesum%4), True)
            format.attributes.move(len(format.attributes)-1, [i+1 for i,a in list(enumerate(format.attributes))[:-1] if a.is_byte][-1])
        [f.UpdateCode(context) for f in vbm.formats]
        return {'FINISHED'}
classlist.append(VBM_OT_FormatAttributeOperation)

# ==========================================================================================
class VBM_OT_QueueListOperation(bpy.types.Operator):
    """Operation on queue list"""
    bl_label = "Queue Operation"
    bl_idname = 'vbm.queue_operation'
    bl_options = {'REGISTER', 'UNDO'}
    
    operation: bpy.props.EnumProperty(name="Operation", items=tuple([
        (x,x,x) for x in 'ADD REMOVE MOVE_UP MOVE_DOWN CLEAR PROJECT_PATH'.split()]))
    
    def execute(self, context):
        vbm = context.scene.vbm
        if self.operation == 'ADD':
            active = vbm.queues[vbm.queues_index] if vbm.queues else None
            item = vbm.queues.add()
            if active:
                [setattr(item, p.identifier, getattr(active, p.identifier)) for p in active.bl_rna.properties if not p.is_readonly]
                for csrc in active.checkout:
                    c = item.checkout.add()
                    [setattr(c, p.identifier, getattr(csrc, p.identifier)) for p in csrc.bl_rna.properties if not p.is_readonly]
            else:
                item.format = vbm.formats[0].name if vbm.formats else item.format
            item.name = "NewQueue"
            vbm.queues_index = max(0, min(len(vbm.queues)-1, vbm.queues_index+1))
        elif self.operation == 'REMOVE':
            vbm.queues.remove(vbm.queues_index)
            vbm.queues_index = max(0, min(len(vbm.queues)-1, vbm.queues_index))
        elif self.operation == 'MOVE_UP':
            vbm.queues.move(vbm.queues_index, vbm.queues_index-1)
            vbm.formats_index -= 1
        elif self.operation == 'MOVE_DOWN':
            vbm.queues.move(vbm.queues_index, vbm.queues_index+1)
            vbm.queues_index = max(0, min(len(vbm.queues)-1, vbm.queues_index-1))
        elif self.operation == 'CLEAR':
            [vbm.queues.remove(x) for x in list(vbm.queues)[::-1]]
            vbm.queues_index = 0
        elif self.operation == 'PROJECT_PATH':
            queue = vbm.queues[vbm.queues_index]
            queue.filepath = vbm.ToggleProjectPath(queue.filepath)
        return {'FINISHED'}
classlist.append(VBM_OT_QueueListOperation)

# -------------------------------------------------------------------------------------------
class VBM_OT_QueueCheckoutOperation(bpy.types.Operator):
    """Operation on queue checkout"""
    bl_label = "Queue Checkout Operation"
    bl_idname = 'vbm.queue_checkout_operation'
    bl_options = {'REGISTER', 'UNDO'}
    
    operation: bpy.props.EnumProperty(name="Operation", items=tuple([
        (x,x,x) for x in 'ADD REMOVE MOVE_UP MOVE_DOWN CLEAR UNPACK SELECTED'.split()]))
    
    def execute(self, context):
        vbm = context.scene.vbm
        queue = vbm.queues[vbm.queues_index]
        
        if self.operation == 'ADD':
            item = queue.checkout.add()
        elif self.operation == 'REMOVE':
            queue.checkout.remove(queue.checkout_index)
            queue.checkout_index = max(0, min(len(queue.checkout)-1, queue.checkout_index))
        elif self.operation == 'CLEAR':
            [queue.checkout.remove(0) for i in range(0, len(queue.checkout))]
            queue.checkout_index = 0
        elif self.operation == 'MOVE_UP':
            queue.checkout.move(queue.checkout_index, queue.checkout_index-1)
            queue.checkout_index -= 1
        elif self.operation == 'MOVE_DOWN':
            queue.checkout.move(queue.checkout_index, queue.checkout_index+1)
            queue.checkout_index += 1
        elif self.operation == 'SELECTED':
            for obj in [obj for obj in context.selected_objects]:
                item = queue.checkout.add()
                item.object = obj
        elif self.operation == 'UNPACK':
            item = queue.checkout[queue.checkout_index]
            objects = []
            if item.collection:
                objects = list(item.collection.objects)
            elif item.object:
                objects = list(item.object.children)
            for obj in [obj for obj in objects if obj.name[0].lower() in 'qwertyuiopasdfghjklzxcvbnm'][::-1]:
                x = queue.checkout.add()
                x.object = obj
                queue.checkout.move(len(queue.checkout)-1, queue.checkout_index+1)
        return {'FINISHED'}
classlist.append(VBM_OT_QueueCheckoutOperation)

# -------------------------------------------------------------------------------------------
class VBM_OT_DissolveTreeOperation(bpy.types.Operator):
    """Operation for armature dissolve tree"""
    bl_label = "Dissolve Tree Operation"
    bl_idname = 'vbm.dissolvetree_operation'
    bl_options = {'REGISTER', 'UNDO'}
    
    operation: bpy.props.EnumProperty(name="Operation", items=tuple([
        (x,x,x) for x in 'UPDATE'.split()]))
    
    def execute(self, context):
        vbm = context.scene.vbm
        rig = context.active_object; rig = (rig if rig.type=='ARMATURE' else rig.find_armature()) if rig else None
        
        if self.operation == 'UPDATE':
            vbm.UpdateDeformMask(rig.vbm.deform_mask, rig)
        return {'FINISHED'}
classlist.append(VBM_OT_DissolveTreeOperation)

# ====================================================================================================
class VBM_OT_ExportModel(bpy.types.Operator, ExportHelper):
    """Export Model"""
    bl_label = "Export Model"
    bl_idname = 'vbm.export_model'
    bl_options = {'REGISTER', 'UNDO'}
    
    filter_glob: bpy.props.StringProperty(default="*.vbm", options={'HIDDEN'}, maxlen=255)
    filename_ext: bpy.props.StringProperty(default=".vbm", options={'HIDDEN'})
    
    def UpdateFileType(self, context):
        self.filename_ext = "."+self.file_type.lower()
    file_type: bpy.props.EnumProperty(name="File Type", default='VBM', update=UpdateFileType, items=VBM_FILETYPE_ITEMS)
    
    dialog: bpy.props.BoolProperty(name="Use Dialog", default=0, options={'HIDDEN'})
    queue: bpy.props.StringProperty(name="Queue", default="")
    
    # Queue Params
    batching: bpy.props.EnumProperty(name="Batching", default='NONE', items=VBM_BATCH_ITEMS, description=VBM_DESCRIPTIONS['batching'])
    format: bpy.props.StringProperty(name="Format", description=VBM_DESCRIPTIONS['format'])
    collection: bpy.props.StringProperty(name="Collection", description=VBM_DESCRIPTIONS['collection'])
    texture_export: bpy.props.BoolProperty(name="Copy Textures", default=True, description=VBM_DESCRIPTIONS['texture_export'])
    
    mesh_export: bpy.props.BoolProperty(name="Export Meshes", default=True, description=VBM_DESCRIPTIONS['mesh_export'])
    mesh_grouping: bpy.props.EnumProperty(name="Grouping", default='OBJECT', items=VBM_GROUPING_ITEMS, description=VBM_DESCRIPTIONS['mesh_grouping'])
    mesh_material_override: bpy.props.StringProperty(name="Mesh Material Override", description=VBM_DESCRIPTIONS['mesh_material_override'])
    mesh_delimiter_start: bpy.props.StringProperty(name="Mesh Delimiter Start", default="", description=VBM_DESCRIPTIONS['mesh_delimiter_start'])
    mesh_delimiter_end: bpy.props.StringProperty(name="Mesh Delimiter End", default="", description=VBM_DESCRIPTIONS['mesh_delimiter_end'])
    mesh_script_pre: bpy.props.StringProperty(name="Mesh Script Pre", default="", description=VBM_DESCRIPTIONS['mesh_script_pre'])
    mesh_script_post: bpy.props.StringProperty(name="Mesh Script Post", default="", description=VBM_DESCRIPTIONS['mesh_script_post'])
    mesh_flip_uvs: bpy.props.BoolProperty(name="Flip UVs", default=True, description=VBM_DESCRIPTIONS['mesh_flip_uvs'])
    mesh_alledges: bpy.props.BoolProperty(name="All Edges", default=False, description=VBM_DESCRIPTIONS['mesh_alledges'])
    
    skeleton_export: bpy.props.BoolProperty(name="Export Armature", default=True, description=VBM_DESCRIPTIONS['skeleton_export'])
    skeleton_delimiter_start: bpy.props.StringProperty(name="Armature Delimiter Start", default="", description=VBM_DESCRIPTIONS['skeleton_delimiter_start'])
    skeleton_delimiter_end: bpy.props.StringProperty(name="Armature Delimiter End", default="", description=VBM_DESCRIPTIONS['skeleton_delimiter_end'])
    skeleton_swing: bpy.props.BoolProperty(name="Write Swing Data", default=True, description=VBM_DESCRIPTIONS['skeleton_swing'], options=set())
    skeleton_colliders: bpy.props.BoolProperty(name="Write Collider Data", default=True, description=VBM_DESCRIPTIONS['skeleton_colliders'], options=set())
    
    action_export: bpy.props.BoolProperty(name="Export Actions", default=True)
    action_delimiter_start: bpy.props.StringProperty(name="Action Delimiter Start", default="")
    action_delimiter_end: bpy.props.StringProperty(name="Action Delimiter End", default="")
    action_clean_threshold: bpy.props.FloatProperty(name="Animation Clean Threshold", default=0.0005, precision=4, description=VBM_DESCRIPTIONS['action_clean_threshold'])
    
    saveprops = '''
        file_type filepath batching collection
        mesh_export mesh_grouping mesh_delimiter_start mesh_delimiter_end mesh_script_post mesh_script_pre mesh_alledges mesh_material_override format
        skeleton_export skeleton_delimiter_start skeleton_delimiter_end skeleton_swing skeleton_colliders
        action_export action_delimiter_start action_delimiter_end action_clean_threshold
    '''.split()
    
    def draw(self, context):
        vbm = context.scene.vbm
        layout = self.layout.column()
        
        b = layout.column(); b.use_property_split = 1
        b.prop_search(self, 'queue', vbm, 'queues')
        r = b.row(); r.active=not self.queue; r.prop_search(self, 'collection', bpy.data, 'collections')
        
        # File
        b = layout.box().column(align=0)
        b.prop(self, 'batching')
        r = b.row(align=1)
        r.prop(self, 'mesh_export', text="Meshes", toggle=True)
        r.prop(self, 'skeleton_export', text="Skeletons", toggle=True)
        r.prop(self, 'action_export', text="Actions", toggle=True)
        
        # Format
        format = vbm.formats[self.format] if self.format in vbm.formats.keys() else None
        b = layout.box().column(align=1)
        b.prop_search(self, 'format', vbm, 'formats')
        if format:
            c = b.column(); c.scale_y = 0.8
            c.template_list('VBM_UL_FormatAttribute', "", format, 'attributes', format, 'attributes_index', rows=3)
        
        # Meshes
        b = layout.box().column(align=1); b.use_property_split = 1
        r = b.row(); r.alignment='CENTER'; r.label(text="== Meshes ==")
        r = b.row(align=1)
        r.prop(self, 'mesh_delimiter_start', text="Delimiters", icon='TRACKING_CLEAR_FORWARDS')
        r.prop(self, 'mesh_delimiter_end', text="", icon='TRACKING_CLEAR_BACKWARDS')
        b.prop(self, 'mesh_grouping')
        b.prop_search(self, 'mesh_material_override', bpy.data, 'materials', text="Mtl Override")
        b.prop_search(self, 'mesh_script_pre', bpy.data, 'texts', text="Pre Script")
        b.prop_search(self, 'mesh_script_post', bpy.data, 'texts', text="Post Script")
        b.prop(self, 'mesh_flip_uvs')
        b.prop(self, 'mesh_alledges')
        b.prop(self, 'texture_export')
        
        # Skeleton
        b = layout.box().column(align=1); b.use_property_split = 1
        r = b.row(); r.alignment='CENTER'; r.label(text="== Skeleton ==")
        r = b.row(align=1)
        r.prop(self, 'skeleton_delimiter_start', text="Delimiters:", icon='TRACKING_CLEAR_FORWARDS')
        r.prop(self, 'skeleton_delimiter_end', text="", icon='TRACKING_CLEAR_BACKWARDS')
        b.prop(self, 'skeleton_swing', text="Write Swing")
        b.prop(self, 'skeleton_colliders', text="Write Colliders")
        
        # Animation
        b = layout.box().column(align=1); b.use_property_split = 1
        r = b.row(); r.alignment='CENTER'; r.label(text="== Animation ==")
        r = b.row(align=1)
        r.prop(self, 'action_delimiter_start', text="Delimiters:", icon='TRACKING_CLEAR_FORWARDS')
        r.prop(self, 'action_delimiter_end', text="", icon='TRACKING_CLEAR_BACKWARDS')
        b.prop(self, 'action_clean_threshold')
    
    def invoke(self, context, event):
        vbm = context.scene.vbm
        queue = vbm.queues.get(self.queue)
        props = {}
        filepath = self.filepath
        
        # Read from queue
        if queue:
            props = queue.get('EXPORT', {})
            [setattr(self, k, "" if v is None else v if isinstance(v, (int, str, float)) else v.name)for k in self.saveprops if k in [p.identifier for p in queue.bl_rna.properties] for v in [getattr(queue, k)]]
            filepath = queue.filepath if queue.filepath else filepath
        else:
            collection = bpy.data.collections.get(self.collection, None)
            if collection:
                props = collection.get('VBM_EXPORT_SETTINGS', {})
                props['collection'] = collection.name
                filepath = props.get('filepath', VBM_PROJECTPATHKEY+collection.name)
            else:
                obj = (list(context.selected_objects)+[context.object])[0]
                if obj:
                    props = obj.get('VBM_EXPORT_SETTINGS', {})
                    filepath = props.get('filepath', VBM_PROJECTPATHKEY+obj.name)
            if not props:
                self.dialog = True
            else:
                [setattr(self, k, v) for k,v in props.items()]
                [setattr(self, k, getattr(queue, k)) for k in self.saveprops if getattr(queue, k, None)]
                filepath = props.get('filepath', filepath)
        
        self.filepath = vbm.ToFullPath(filepath)
        if self.format not in vbm.formats.keys() and len(vbm.formats) > 0:
            self.format = vbm.formats[0].name
        if self.dialog:
            return super().invoke(context, event)
        return self.execute(context)
    
    def execute(self, context):
        vbm = context.scene.vbm
        queue = vbm.queues.get(self.queue)
        props = {}
        selectednames = [x.name for x in context.selected_objects]
        # Write to queue
        if queue:
            datagroups = [bpy.data.actions, bpy.data.materials, bpy.data.objects, bpy.data.meshes]
            queueprops = [k for k in self.saveprops if k in [p.identifier for p in queue.bl_rna.properties]]
            props = {k: v if isinstance(getattr(queue,k), (int,str,float)) else (([x for g in datagroups for x in g if x.name==v]+[None])[0]) for k in queueprops for v in [getattr(self,k)]}
            props['filepath'] = vbm.AsProjectPath(self.filepath) if VBM_PROJECTPATHKEY in queue.filepath else self.filepath
            [setattr(queue, k, v) for k,v in props.items()]
            queue.mesh_script_pre = bpy.data.texts.get(self.mesh_script_pre, None)
            queue.mesh_script_post = bpy.data.texts.get(self.mesh_script_post, None)
            queue.filepath = props['filepath']
            queue['EXPORT'] = props
        else:
            collection = bpy.data.collections.get(self.collection, None)
            if collection:
                props = {k: getattr(self, k) for k in self.saveprops}
                props['collection'] = collection.name
                props['filepath'] = vbm.AsProjectPath(self.filepath) if VBM_PROJECTPATHKEY in collection.get('VBM_EXPORT_SETTINGS', {}).get('filepath', "") else self.filepath
                collection['VBM_EXPORT_SETTINGS'] = props
            else:
                props = {k: getattr(self, k) for k in self.saveprops}
                props['filepath'] = vbm.AsProjectPath(self.filepath)
                for obj in list(context.selected_objects)+[context.object]:
                    if obj:
                        obj['VBM_EXPORT_SETTINGS'] = props
        vbm.Export(queue=self.queue, settings=props)
        [bpy.data.objects.get(x).select_set(True) for x in selectednames if x in list(bpy.data.objects.keys())]
        self.report({'INFO'}, "> Export complete!")
        return {'FINISHED'}
classlist.append(VBM_OT_ExportModel)

# -------------------------------------------------------------------------------------------
class VBM_OT_ExportQueueGroup(bpy.types.Operator):
    """Export Queue group"""
    bl_label = "Queue Export Group"
    bl_idname = 'vbm.queue_export_group'
    bl_options = {'REGISTER', 'UNDO'}
    
    group: bpy.props.IntProperty(name="Group")
    
    def execute(self, context):
        vbm = context.scene.vbm
        selectednames = [x.name for x in context.selected_objects]
        rigstate = [(x.name, x.animation_data.action.name) for x in context.scene.collection.all_objects if x and x.type=='ARMATURE' and x.animation_data and x.animation_data.action]
        for queue in vbm.queues:
            if queue.group == str(self.group):
                vbm.Export(queue=queue.name, settings={'filepath': vbm.ToFullPath(queue.filepath)})
        [bpy.data.objects.get(x).select_set(True) for x in selectednames if x in list(bpy.data.objects.keys())]
        for obj, action in [(x,y) for x,y in rigstate if bpy.data.objects.get(x, None) and bpy.data.actions.get(y, None)]:
            bpy.data.objects.get(obj).animation_data.action = bpy.data.actions.get(action)
        self.report({'INFO'}, "> Queue export complete!")
        return {'FINISHED'}
classlist.append(VBM_OT_ExportQueueGroup)

'# =========================================================================================================================='
'# UI LIST'
'# =========================================================================================================================='

# ====================================================================================================
class VBM_UL_QueueList(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        vbm = context.scene.vbm
        r = layout.row(align=True)
        r.prop(item, 'enabled', text="")
        r = r.row(align=1)
        r.active = item.enabled
        #r.prop_menu_enum(item, 'group', text="", icon=VBM_QUEUE_GROUPICON[int(item.group)])
        r.prop(item, 'group', text="", icon_only=True)
        r.separator()
        r.prop(item, 'name', text="", emboss=False)
        r.prop_search(item, 'format', vbm, 'formats', text="", icon='VERTEXSEL', results_are_suggestions=True)
        op = r.operator('vbm.export_model', text="", icon='WINDOW')
        op.dialog, op.queue = (True, item.name)
        op = r.operator('vbm.export_model', text="", icon='SOLO_ON')
        op.dialog, op.queue = (False, item.name)
classlist.append(VBM_UL_QueueList)

# ----------------------------------------------------------------------------
class VBM_UL_QueueCheckout(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=True)
        r.prop(item, 'enabled', text="", icon='CHECKBOX_HLT' if item.enabled else 'CHECKBOX_DEHLT', toggle=True, emboss=False)
        r = r.row(align=True)
        r.active=item.enabled
        #r.label(text="", icon='GROUP' if item.collection else item.object.type+'_DATA' if item.object else 'ACTION' if item.action else 'QUESTION')
        r.scale_x = 2.0
        if item.collection:
            r.prop(item, 'collection', text="", icon_only=True, icon='GROUP')
            r.scale_x = 1.0; r.separator()
            r.prop(item.collection, 'name', text="", emboss=False)
            r.prop(item, 'include_child_collections', text="", toggle=True, icon='OUTLINER_OB_GROUP_INSTANCE')
            r.prop(item, 'include_child_objects', text="", toggle=True, icon='CON_CHILDOF')
        elif item.object:
            r.prop(item, 'object', text="", icon_only=True, icon=item.object.type+'_DATA')
            r.scale_x = 1.0; r.separator()
            r.prop(item.object, 'name', text="", emboss=False)
            r.prop(item, 'include_child_objects', text="", toggle=True, icon='CON_CHILDOF')
            if item.object.animation_data:
                r.prop(item, 'action', text="")
        elif item.action:
            r.prop(item, 'action', text="", icon_only=True, icon='ACTION')
            r.scale_x = 1.0; r.separator()
            r.prop(item.action, 'name', text="", emboss=False)
            r.scale_x = 0.4
            r.prop(item.action, 'frame_start', text="")
            r.prop(item.action, 'frame_end', text="")
            r.scale_x = 1.0
        else:
            r.label(text="", icon='QUESTION')
            r.prop(item, 'collection', text="")
            r.prop(item, 'object', text="")
            r.prop(item, 'action', text="")
classlist.append(VBM_UL_QueueCheckout)

# ====================================================================================================
class VBM_UL_Format(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=True)
        stride = item.bytesum
        r.alert = stride % 4 != 0
        r.scale_x=2.0; r.prop(item, 'name', text="", emboss=False); r.scale_x=1.0
        r.scale_x=0.7; r.label(text="%d B" % stride); r.scale_x=1.0
        r.scale_x=0.9
        [r.label(text="", icon=VBM_ATTRIBUTE_ICON[att.attribute]) for att in item.attributes]
        [r.label(text="", icon='BLANK1') for i in range(0, 6-len(item.attributes))]
classlist.append(VBM_UL_Format)

# ----------------------------------------------------------------------------
class VBM_UL_FormatAttribute(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=1)
        r.prop_menu_enum(item, 'attribute', text="", icon=VBM_ATTRIBUTE_ICON[item.attribute])
        r.separator()
        r.label(text=item.attribute)
        r.scale_x = 0.15
        r.alert = item.is_byte and data.bytesum % 4 != 0
        r.prop(item, 'size', text="")
        r.scale_x = 1.0
        r.prop(item, 'is_byte', text="", icon='EVENT_B' if item.is_byte else 'EVENT_F')
        r.separator()
        
        rr = r.row(align=1)
        
        obj = context.active_object
        if item.attribute == 'COLOR':
            rr.scale_x = 1.31
            if obj and obj.type=='MESH':
                rr.prop_search(item, 'layer', obj.data, 'color_attributes', text="", results_are_suggestions=True)
            else:
                rr.prop(item, 'layer', text="", icon=VBM_ATTRIBUTE_ICON[item.attribute])
            rr.prop(item, 'is_srgb', text="", icon='BRUSHES_ALL' if item.is_srgb else 'IPO_SINE')
        elif item.attribute == 'UV':
            rr.scale_x = 1.38
            if obj and obj.type=='MESH':
                rr.prop_search(item, 'layer', obj.data, 'uv_layers', text="", results_are_suggestions=True)
            else:
                rr.prop(item, 'layer', text="", icon=VBM_ATTRIBUTE_ICON[item.attribute])
        elif item.attribute == 'GROUP':
            rr.scale_x = 1.38
            if obj and obj.type=='MESH':
                rr.prop_search(item, 'layer', obj, 'vertex_groups', text="", results_are_suggestions=True)
            else:
                rr.prop(item, 'layer', text="", icon=VBM_ATTRIBUTE_ICON[item.attribute])
        else:
            rr.scale_x = 0.5
            for i in (0,1,2,3):
                rrr = rr.row(align=1); rrr.enabled=i<item.size
                rrr.prop(item, 'value_byte' if item.is_byte else 'value_float', index=i, text="")
classlist.append(VBM_UL_FormatAttribute)

# ====================================================================================================
class VBM_UL_SkeletonMask(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=True)
        r.active = item.enabled
        [r.label(text="", icon='THREE_DOTS') for i in range(0, item.depth)]
        r.prop(item, 'op_toggletree', text="", icon='NLA_PUSHDOWN', emboss=True, toggle=False)
        r.prop(item, 'enabled', text=item.name, emboss=True, toggle=False)
classlist.append(VBM_UL_SkeletonMask)

# ----------------------------------------------------------------
class VBM_UL_SkeletonBone(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=True)
        r.active = item.enabled
        r.scale_x=0.8
        [r.label(text="", icon='THREE_DOTS') for i in range(0, item.depth)]
        r.prop(item, 'op_toggletree', text="", icon='NLA_PUSHDOWN', emboss=True, toggle=False)
        r.prop(item, 'enabled', text="", emboss=True, toggle=False)
        r.prop(item, 'name', text="", emboss=False)
        r.prop(item.swing, 'enabled', text="", icon='CON_SPLINEIK' if item.swing.enabled else 'BLANK1', toggle=True, emboss=False)
        r.prop(item.collider, 'enabled', text="", icon='PHYSICS'  if item.collider.enabled else 'BLANK1', toggle=True, emboss=False)
classlist.append(VBM_UL_SkeletonBone)

# ----------------------------------------------------------------
class VBM_UL_SkeletonBoneNoDepth(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        item = data.deform_mask[item.name]
        r = layout.row(align=True)
        #r.active = item.enabled
        r.prop(item, 'enabled', text="", emboss=True, toggle=False)
        r.prop(item, 'name', text="", emboss=False)
        r.prop(item.swing, 'enabled', text="", icon='CON_SPLINEIK' if item.swing.enabled else 'BLANK1', toggle=True, emboss=False)
        r.prop(item.collider, 'enabled', text="", icon='PHYSICS'  if item.collider.enabled else 'BLANK1', toggle=True, emboss=False)
classlist.append(VBM_UL_SkeletonBoneNoDepth)

# ====================================================================================================
class VBM_UL_MaterialSwap(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=True)
        r.prop(item, 'name', text="", emboss=False)
        r.label(text="->")
        r.prop(item.vbm, 'alias', text="")
        if item.vbm.alias:
            r.prop(item.vbm.alias, 'use_fake_user', text="")
classlist.append(VBM_UL_MaterialSwap)

'# =========================================================================================================================='
'# PANELS'
'# =========================================================================================================================='

def Panel_Formats(context, layout):
    vbm = context.scene.vbm
    
    r = layout.row()
    c = r.column(align=1)
    rr = c.row(align=1)
    rr.operator('vbm.format_operation', text="Import", icon='IMPORT').operation='IMPORT'
    op = rr.operator('vbm.scene_transfer', text="", icon='SCENE_DATA')
    op.scene_target, op.prop_type = (context.scene.name, 'FORMAT')
    rr.separator()
    rr.operator('vbm.format_operation', text="Export", icon='EXPORT').operation='EXPORT'
    c.template_list('VBM_UL_Format', "", vbm, 'formats', vbm, 'formats_index', rows=3)
    c = r.column(align=1)
    c.operator('vbm.format_operation', text="", icon='ADD').operation='ADD'
    c.operator('vbm.format_operation', text="", icon='REMOVE').operation='REMOVE'
    c.operator('vbm.format_operation', text="", icon='TRIA_UP').operation='MOVE_UP'
    c.operator('vbm.format_operation', text="", icon='TRIA_DOWN').operation='MOVE_DOWN'
    
    format = vbm.formats[vbm.formats_index] if vbm.formats else None
    if format:
        b = layout.column(align=1)
        b.prop(format, 'code')
        bytesum = sum([a.size*[4,1][a.is_byte] for a in format.attributes])
        r = b.row()
        r.template_list('VBM_UL_FormatAttribute', "", format, 'attributes', format, 'attributes_index', rows=2)
        c = r.column(align=1)
        c.operator('vbm.format_attribute_operation', text="", icon='ADD').operation='ADD'
        c.operator('vbm.format_attribute_operation', text="", icon='REMOVE').operation='REMOVE'
        c.operator('vbm.format_attribute_operation', text="", icon='TRIA_UP').operation='MOVE_UP'
        c.operator('vbm.format_attribute_operation', text="", icon='TRIA_DOWN').operation='MOVE_DOWN'
        if format.attributes:
            r = b.row()
            att = format.attributes[format.attributes_index]
            r.scale_x = 1.3; r.label(text="Default Value:"); r.scale_x = 1.0
            r.prop(att, 'value_byte' if att.is_byte else 'value_float', text="")
        if format.bytesum % 4 != 0:
            r = b.row()
            r.label(text="Byte sum is not disivible by 4 (Sum = %d B)" % bytesum, icon='ERROR')
            r.scale_x = 0.3; r.operator('vbm.format_attribute_operation', text="Fix").operation='PAD'
        
        c = b.box().column()
        r = c.row()
        r.label(text="Code Guide:")
        r.prop(vbm,  'format_guide_display', expand=True)
        if vbm.format_guide_display != 'NONE':
            r.operator('vbm.format_operation', text="", icon='COPYDOWN').operation='GUIDE'
            c = c.column(align=1); c.scale_y=0.6
            [c.label(text=line) for line in vbm.FormatGuide(format).strip().split("\n")]

# ....................................................................................
def Panel_Queues(context, layout):
    vbm = context.scene.vbm
    queue = vbm.queues[vbm.queues_index] if vbm.queues else None
    
    b = layout.column(align=1)
    r = b.row()
    c = r.column(align=1); c.scale_y = 0.9
    c.template_list('VBM_UL_QueueList', "", vbm, 'queues', vbm, 'queues_index', rows=5)
    c = r.column(align=1); c.scale_y = 0.9
    op = c.operator('vbm.scene_transfer', text="", icon='SCENE_DATA')
    op.scene_target, op.prop_type = (context.scene.name, 'QUEUE')
    for op,icon in [(0,0), ('ADD', 'ADD'), ('REMOVE', 'REMOVE'), (0,0), ('MOVE_UP','TRIA_UP'), ('MOVE_DOWN','TRIA_DOWN'), (0,0), ('CLEAR','X')]:
        if op:
            c.operator('vbm.queue_operation', text="", icon=icon).operation=op
        else:
            c.separator()
    if queue:
        b = layout.box().column(align=1)
        r = b.row(align=1)
        r.prop(queue, 'mesh_export', text="Meshes", toggle=True)
        r.prop(queue, 'skeleton_export', text="Skeletons", toggle=True)
        r.prop(queue, 'action_export', text="Animatons", toggle=True)
        
        c = b.column(align=0) # Meshes ........................................
        c.enabled = queue.mesh_export
        r = c.row(align=1)
        r.label(text="Scripts:")
        r.prop_search(queue, 'mesh_script_pre', bpy.data, 'texts', text="Pre")
        r.prop_search(queue, 'mesh_script_post', bpy.data, 'texts', text="Post")
        r = c.row(align=1)
        r.prop_search(queue, 'format', vbm, 'formats')
        r = c.row(align=0)
        r.prop(queue, 'mesh_material_override', text="Override")
        r.prop(queue, 'texture_export', text="Export Textures")
        r = c.row(align=1)
        r.label(text="Delimiters:")
        r.scale_x = 0.5
        r.prop(queue, 'mesh_delimiter_start', text="", icon='OUTLINER_OB_MESH')
        r.prop(queue, 'mesh_delimiter_end', text="")
        r.separator()
        r.prop(queue, 'skeleton_delimiter_start', text="", icon='OUTLINER_OB_ARMATURE')
        r.prop(queue, 'skeleton_delimiter_end', text="")
        r.separator()
        r.prop(queue, 'skeleton_delimiter_start', text="", icon='ACTION')
        r.prop(queue, 'skeleton_delimiter_end', text="")
        
        # List
        br = b.row()
        br.scale_y = 0.8
        br.template_list('VBM_UL_QueueCheckout', "", queue, 'checkout', queue, 'checkout_index', rows=4)
        c = br.column(align=1)
        # Operations
        for op,icon in [('UNPACK','TRANSFORM_ORIGINS'), (0,0), ('ADD', 'ADD'), ('REMOVE', 'REMOVE'), (0,0), ('SELECTED','RESTRICT_SELECT_OFF'), (0,0), ('MOVE_UP','TRIA_UP'), ('MOVE_DOWN','TRIA_DOWN'), (0,0), ('CLEAR','X')]:
            if op:
                c.operator('vbm.queue_checkout_operation', text="", icon=icon).operation=op
            else:
                c.separator()
        
        # Active Item Properties
        if len(queue.checkout) > 0:
            item = queue.checkout[queue.checkout_index]
            b.separator()
            c = b.column(align=1)
            r = c.row()
            r.prop(item, 'include_child_collections')
            r.prop(item, 'include_child_objects')
            r = c.row(); r.label(text="Mesh Grouping:"); r.prop(item, 'mesh_grouping', text="")
            r = c.row(); r.label(text="Material Override:"); r.prop(item, 'material_override', text="")
        
        # Action Bone Mask
        action = queue.checkout[queue.checkout_index].action if len(queue.checkout) > 0 else None
        b = b.box().column(align=1)
        r = b.row()
        if action:
            r.prop(action, 'name', text="", emboss=False, icon='ACTION')
        else:
            r.label(text="(No Action)")
        r.operator('vbm.action_operation', text="Fill From Rig").operation='DISSOLVE_FILL'
        r.operator('vbm.action_operation', text="", icon='X').operation='DISSOLVE_CLEAR'
        
        display = vbm.display_action_dissolvemask
        b.prop(vbm, 'display_action_dissolvemask', toggle=True, icon='DOWNARROW_HLT' if display else 'RIGHTARROW')
        if display and action:
            c = b.column(); c.scale_y=0.7
            c.template_list('VBM_UL_SkeletonMask', "", action.vbm, 'deform_mask', action.vbm, 'deform_index', rows=1)

# ....................................................................................
def Panel_Materials(context, layout):
    vbm = context.scene.vbm
    obj = context.active_object
    if obj and obj.type=='MESH':
        layout.template_list('VBM_UL_MaterialSwap', "", bpy.data, 'materials', obj, 'active_material_index', rows=6)

# ....................................................................................
def Panel_Rig(context, layout):
    vbm = context.scene.vbm
    rig = context.active_object; rig = (rig if rig.type=='ARMATURE' else rig.find_armature()) if rig else None
    layout = layout.column()
    
    if rig:
        mask = rig.vbm.deform_mask
        hits = sum([x.enabled for x in mask])
        layout.label(text="%s  (%4d / %4d)" % (rig.name, hits, len(mask)), icon='ARMATURE_DATA')
        r = layout.row()
        r.prop(rig.data, 'pose_position', text="")
        if rig.animation_data:
            r.prop(rig.animation_data, 'action')
        layout.operator('vbm.dissolvetree_operation', text="Update", icon='FILE_REFRESH').operation='UPDATE'
        c = layout.column(align=1)
        c.row(align=1).prop(vbm, 'tab_select_skeleton', expand=True)
        c = c.column(align=1)
        if vbm.tab_select_skeleton=='BONE':
            c.scale_x, c.scale_y = (1.0, 0.7)
            c.template_list('VBM_UL_SkeletonBone', "", rig.vbm, 'deform_mask', rig.vbm, 'deform_index', rows=4)
        elif vbm.tab_select_skeleton=='SWING':
            c.template_list('VBM_UL_SkeletonBoneNoDepth', "", rig.vbm, 'swing_bones', rig.vbm, 'swing_index', rows=2)
        elif vbm.tab_select_skeleton=='COLLIDER':
            c.template_list('VBM_UL_SkeletonBoneNoDepth', "", rig.vbm, 'collider_bones', rig.vbm, 'collider_index', rows=2)
        
        bone = rig.vbm.deform_mask[rig.vbm.deform_index] if rig.vbm.deform_mask and rig.vbm.deform_index < len(rig.vbm.deform_mask) else None
        if bone:
            b = layout.box().column()
            b.prop(bone, 'name', text="", icon='BONE_DATA', emboss=False)
            swing, collider = bone.swing, bone.collider
            if vbm.tab_select_skeleton == 'SWING':
                c = b
                c.prop(swing, 'enabled', text="Swing", icon=VBM_ICON_SWING)
                c = c.box().column(align=1)
                c.active=swing.enabled
                c.prop(swing, 'is_chain')
                c.prop(swing, 'friction')
                c.prop(swing, 'stiffness')
                c.prop(swing, 'dampness')
                c.prop(swing, 'gravity')
                c.row().prop(swing, 'offset')
                r = c.row(align=1, heading="Angle X")
                r.prop(swing, 'angle_min_x', text="")
                r.prop(swing, 'angle_max_x', text="")
                r = c.row(align=1, heading="Angle Z")
                r.prop(swing, 'angle_min_z', text="")
                r.prop(swing, 'angle_max_z', text="")
            elif vbm.tab_select_skeleton == 'COLLIDER':
                c = b
                c.prop(collider, 'enabled', text="Collider", icon=VBM_ICON_COLLIDER)
                c = c.box().column(align=1)
                c.active=collider.enabled
                c.prop(collider, 'is_chain')
                c.prop(collider, 'radius')
                c.prop(collider, 'length')
                c.row().prop(collider, 'offset')
            else:
                c = b.column(align=1)
                c.prop(bone, 'enabled', text="Deform", icon='BONE_DATA')
                c.prop(swing, 'enabled', text="Swing", icon=VBM_ICON_SWING)
                c.prop(collider, 'enabled', text="Collider", icon=VBM_ICON_COLLIDER)
        
    else:
        r = layout.row()
        r.label(text='(None)', icon='ARMATURE_DATA')
        r = r.row()
        r.enabled = rig != None
        r.operator('vbm.dissolvetree_operation', text="Update", icon='FILE_REFRESH').operation='UPDATE'
        b = layout.box()
        b.label(text="")

# ....................................................................................
def Panel_Rig_Visuals(context, layout):
    vbm = context.scene.vbm
    rig = context.active_object; rig = (rig if rig.type=='ARMATURE' else rig.find_armature()) if rig else None
    layout = layout.column()
    
    b = layout.column(align=1)
    rr = b.row(align=1)
    c = rr.box().column(align=1)
    c.prop(vbm, 'show_bone_swing', text="Swing", toggle=True, icon=VBM_ICON_SWING)
    c = c.column(align=1); c.active=vbm.show_bone_swing
    c.prop(vbm, 'show_bone_swing_hidden', text="Hidden")
    c.prop(vbm, 'show_bone_swing_cones', text="Cones")
    c.prop(vbm, 'show_bone_swing_limits', text="Limits")
    c.prop(vbm, 'show_bone_swing_axis', text="Axes")
    c = rr.box().column(align=1)
    c.prop(vbm, 'show_bone_colliders', text="Colliders", toggle=True, icon=VBM_ICON_COLLIDER)
    c = c.column(align=1); c.active=vbm.show_bone_colliders
    c.prop(vbm, 'show_bone_collider_hidden', text="Hidden")

# ....................................................................................
def Panel_Settings(context, layout):
    vbm = context.scene.vbm
    layout = layout.column()
    layout.prop(vbm, 'project_path')
    layout.prop(vbm, 'cache_actions')
    layout.operator('vbm.action_operation', text="Clear Checksum", icon='ACTION').operation='RESET'
    r = layout.row()
    r.scale_x = 1.4; r.label(text="Clean Exclude:"); r.scale_x = 1.0
    r.prop(vbm, 'export_cleanup_exclude', expand=True)
    
    c = layout.column(align=1)
    c.prop(vbm, 'show_bone_swing')
    c.prop(vbm, 'show_bone_swing_hidden')
    c.prop(vbm, 'show_bone_swing_cones')
    c.prop(vbm, 'show_bone_swing_limits')
    c.prop(vbm, 'show_bone_swing_axis')
    c = layout.column(align=1)
    c.prop(vbm, 'show_bone_colliders')
    c.prop(vbm, 'show_bone_collider_hidden')
    
    if vbm.get('mutex', 0):
        layout.prop(vbm, '["mutex"]')

# =======================================================================================================
class VBM_PT_Master(bpy.types.Panel):
    bl_label = VBM_PANEL_TITLE
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "scene"
    
    def draw(self, context):
        vbm = context.scene.vbm
        layout = self.layout.column()
        collection = context.collection
        queue = vbm.queues[vbm.queues_index] if vbm.queues else None
        
        b = layout.box().column(align=0)
        r = b.row(align=1)
        r.alignment='CENTER'
        r.label(text="== Export ==")
        
        r = b.row(align=1)
        r.label(text="Selection", icon='RESTRICT_SELECT_OFF')
        obj = context.selected_objects[0] if context.selected_objects else None
        op = r.operator('vbm.export_model', text="Selected", icon=obj.type+'_DATA' if obj and obj.type in ('MESH','EMPTY','ARMATURE') else 'BLANK1')
        op.queue, op.dialog, op.collection = ("", True, "")
        rr = r.row(align=1)
        rr.active=bool(obj and obj.get('VBM_EXPORT_SETTINGS', None))
        op = rr.operator('vbm.export_model', text="", icon='SOLO_ON')
        op.queue, op.dialog, op.collection = ("", False, "")
        
        r = b.row(align=1)
        r.label(text="Collection", icon='OUTLINER_COLLECTION')
        op = r.operator('vbm.export_model', text=collection.name if collection else "(None)")
        op.queue, op.dialog, op.collection = ("", True, collection.name)
        rr = r.row(align=1)
        rr.active=bool(collection and collection.get('VBM_EXPORT_SETTINGS', None))
        op = rr.operator('vbm.export_model', text="", icon='SOLO_ON')
        op.queue, op.dialog, op.collection = ("", False, collection.name)
        
        r = b.row(align=1)
        r.label(text="Queue", icon='DECORATE_KEYFRAME')
        r.enabled=queue is not None
        op = r.operator('vbm.export_model', text=(queue.name if queue else "(None)"), icon=VBM_QUEUE_GROUPICON[int(queue.group)] if queue else 'BLANK1')
        op.queue, op.dialog, op.collection = (queue.name if queue else "", True, "")
        rr = r.row(align=1)
        rr.active=bool(queue != "")
        op = rr.operator('vbm.export_model', text="", icon='SOLO_ON')
        op.queue, op.dialog, op.collection = (queue.name if queue else "", False, "")
classlist.append(VBM_PT_Master)

# ----------------------------------------------------------------------------------------------------------
class VBM_PT_Structs(bpy.types.Panel):
    bl_label = "VBM Elements"
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "scene"
    bl_parent_id = 'VBM_PT_Master'
    
    def draw(self, context):
        vbm = context.scene.vbm
        layout = self.layout.box()
        r = layout.row(align=1)
        r.label(text="Queue Groups:", icon='SOLO_ON')
        for group_index,icon in enumerate(VBM_QUEUE_GROUPICON):
            r.operator('vbm.queue_export_group', text="", icon=icon).group=group_index
        
        r = layout.row()
        r.prop(vbm, 'tab_select', expand=True)
        tab_select = vbm.tab_select
        if tab_select == 'FORMAT':
            Panel_Formats(context, layout)
        elif tab_select == 'QUEUE':
            queue = vbm.queues[vbm.queues_index] if vbm.queues else None
            
            c = layout.column(align=1)
            r = c.row(align=1)
            r.scale_x=0.15; r.prop_search(vbm, 'queue_name', vbm, 'queues', text="", icon=VBM_QUEUE_GROUPICON[0]); r.scale_x=1.0
            r.prop(queue, 'name', text="")
            r.operator('vbm.queue_operation', text="", icon='ADD').operation='ADD'
            r.operator('vbm.queue_operation', text="", icon='REMOVE').operation='REMOVE'
            
            r = c.row(align=1)
            r.prop(queue, 'group', text="", icon_only=1)
            r.operator('vbm.queue_operation', text="", icon='FOLDER_REDIRECT').operation='PROJECT_PATH'
            r.prop(queue, 'filepath', text="")
            op = r.operator('vbm.export_model', text="", icon='WINDOW')
            op.dialog, op.queue = (True, queue.name)
            op = r.operator('vbm.export_model', text="", icon='SOLO_ON')
            op.dialog, op.queue = (False, queue.name)
            Panel_Queues(context, layout)
        elif tab_select == 'MATERIAL':
            Panel_Materials(context, layout)
        elif tab_select == 'SETTINGS':
            Panel_Settings(context, layout)
classlist.append(VBM_PT_Structs)

# =======================================================================================================
class VBM_PT_DissolveTree(bpy.types.Panel):
    bl_label = 'Dissolve Tree'
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = "scene"
    bl_parent_id = 'VBM_PT_Master'
    bl_options = {'DEFAULT_CLOSED'}
    
    def draw(self, context):
        vbm = context.scene.vbm
        rig = context.active_object; rig = (rig if rig.type=='ARMATURE' else rig.find_armature()) if rig else None
        layout = self.layout.column(align=1)
        
        r = layout.row(align=1)
        if rig:
            mask = rig.vbm.deform_mask
            hits = sum([x.enabled for x in mask])
            r.label(text="%s  (%4d / %4d)" % (rig.name, hits, len(mask)), icon='ARMATURE_DATA')
            r.operator('vbm.dissolvetree_operation', text="Update", icon='FILE_REFRESH').operation='UPDATE'
            c = layout.column(align=1)
            c.scale_x = 0.77
            c.scale_y = 0.77
            c.template_list('VBM_UL_SkeletonMask', "", rig.vbm, 'deform_mask', rig.vbm, 'deform_index', rows=6)
        else:
            r.label(text='(None)', icon='ARMATURE_DATA')
            r = r.row()
            r.enabled = rig != None
            r.operator('vbm.dissolvetree_operation', text="Update", icon='FILE_REFRESH').operation='UPDATE'
            b = layout.box()
            b.label(text="")
classlist.append(VBM_PT_DissolveTree)

# =======================================================================================================
class VBM_PT_ActiveRig(bpy.types.Panel):
    bl_label, bl_space_type, bl_region_type, bl_category = ("VBM Rig", 'VIEW_3D', 'UI', 'Item')
    def draw(self, context):
        Panel_Rig(context, self.layout)
classlist.append(VBM_PT_ActiveRig)

class VBM_PT_ActiveRig_Visuals(bpy.types.Panel):
    bl_label, bl_space_type, bl_region_type, bl_category = ("Visuals", 'VIEW_3D', 'UI', 'Item')
    bl_parent_id = 'VBM_PT_ActiveRig'
    def draw(self, context):
        Panel_Rig_Visuals(context, self.layout)
classlist.append(VBM_PT_ActiveRig_Visuals)

'# =========================================================================================================================='
'# MASTER'
'# =========================================================================================================================='

class VBM_PG_Master(bpy.types.PropertyGroup):
    def UpdateProjectPath(self, context):
        if not self.project_path:
            for q in self.queues:
                q.filepath = q.filepath.replace(VBM_PROJECTPATHKEY, self.get('LASTPROJECTPATH', "//"))
        else:
            self['LASTPROJECTPATH'] = self.project_path
    
    def UpdateQueueName(self, context):
        if not self.get('mutex', 0):
            self['mutex'] = True
            if self.queue_name in [x.name for x in self.queues]:
                self.queues_index = [x.name for x in self.queues].index(self.queue_name)
            self['mutex'] = False
    
    def UpdateQueueIndex(self, context):
        if not self.get('mutex', 0):
            self['mutex'] = True
            self.queue_name = self.queues[self.queues_index].name if self.queues else ""
            self['mutex'] = False
    
    tab_select: bpy.props.EnumProperty(name="VBM Tab", items=(
        ('FORMAT', "Formats", "Vertex Formats"),
        ('QUEUE', "Queues", "Export Queues"),
        ('MATERIAL', "Materials", "Materials"),
        ('SETTINGS', "Settings", "VBM Settings")
    ))
    
    tab_select_queue: bpy.props.EnumProperty(name="Queue Tab", items=(
        ('ACTIVE', "Active", "Active Queue", 'DECORATE_KEYFRAME', 0),
        ('LIST', "List", "Queue List", 'LINENUMBERS_ON', 1),
    ))
    
    tab_select_skeleton: bpy.props.EnumProperty(name="Skeleton Tab", items=(
        ('BONE', "Bones", "Bones", 'BONE_DATA', 0),
        ('SWING', "Swing", "Swing Bones", 'CON_SPLINEIK', 1),
        ('COLLIDER', "Colliders", "Colliders", 'PHYSICS', 2),
    ))
    
    formats : bpy.props.CollectionProperty(name="Formats", type=VBM_PG_Format)
    formats_index: bpy.props.IntProperty(name="Format Index", min=0)
    format_guide_display: bpy.props.EnumProperty(name="Format Guide Display", items=(
        ('NONE', 'None', "No Guide"), 
        ('GML', 'GML', "Display format creation code for GML"), 
        ('SHADER', "Shader", "Display shader attributes")
    ))
    
    queues: bpy.props.CollectionProperty(name="", type=VBM_PG_Queue)
    queues_index: bpy.props.IntProperty(name="Queue Index", min=0, update=UpdateQueueIndex)
    queue_name: bpy.props.StringProperty(name="Active Queue", update=UpdateQueueName)
    
    project_path: bpy.props.StringProperty(name="Project Path", default="", subtype='DIR_PATH', update=UpdateProjectPath)
    
    cache_actions: bpy.props.BoolProperty(name="Cache Actions", default=True)
    display_action_dissolvemask: bpy.props.BoolProperty(name="Show Dissolve Mask")
    export_cleanup_exclude: bpy.props.EnumProperty(name="Cleanup Exclude", default=set(), options={'ENUM_FLAG'}, items=tuple((x,x,x) for x in VBM_CLEANUPKEYS))
    
    show_bone_swing: bpy.props.BoolProperty(default=True)
    show_bone_swing_hidden: bpy.props.BoolProperty(default=False)
    show_bone_swing_axis: bpy.props.BoolProperty(default=False)
    show_bone_swing_limits: bpy.props.BoolProperty(default=False)
    show_bone_swing_cones: bpy.props.BoolProperty(default=True)
    
    show_bone_colliders: bpy.props.BoolProperty(default=True)
    show_bone_collider_hidden: bpy.props.BoolProperty(default=False)
        
    # ..........................................................................
    def AsProjectPath(self, path):
        fullpath = os.path.abspath(bpy.path.abspath(path))
        fullprojpath = os.path.abspath(bpy.path.abspath(self.project_path))
        return fullpath.replace(fullprojpath, VBM_PROJECTPATHKEY) if self.project_path else path
    
    def ToFullPath(self, path_with_projectpath):
        if VBM_PROJECTPATHKEY in path_with_projectpath:
            fullprojpath = os.path.abspath(bpy.path.abspath(self.project_path)) + "/"
            return path_with_projectpath[path_with_projectpath.find(VBM_PROJECTPATHKEY):].replace(VBM_PROJECTPATHKEY, fullprojpath)
        return path_with_projectpath
    
    def ToggleProjectPath(self, path):
        if VBM_PROJECTPATHKEY in path:
            return self.ToFullPath(path)
        else:
            return self.AsProjectPath(path)
    
    # ..........................................................................
    def FormatStringDecode(self, format_string):
        format = []
        for line in format_string.split():
            line = line + "    "
            k = ([x for x in VBM_FORMAT_KEY if line[:len(x)]==x]+[VBM_FORMAT_KEY[0]])[0].upper()
            size = (int(line[len(k)]) if line[len(k)] in "0123456789" else 0) if sum([x in line for x in VBM_FORMAT_KEY]) else 0
            flags = (
                ( VBM_FORMAT_FL_ISBYTE * ( (line[len(k)+1] in 'Bb') if size else VBM_ATTRIBUTE_ISBYTE[k]) ) |
                ( VBM_FORMAT_FL_SRGB * ('-SRGB' in line.upper()) )
            )
            layer = line[line.find("{")+1:line.find("}")] if "{" in line and "}" in line else ""
            value = [( float('0'+x) if x.isdigit() else 0 ) for x in line[line.find("(")+1:line.find(")")].split(",")] if "(" in line and ")" in line else [0]
            format.append((k, size if size else VBM_ATTRIBUTE_SIZE[k], flags, layer, (value*4)[:4]))
        return format # [ (key, size, flags, layer, value) ]
    
    def FormatGuide(self, format):
        text=""
        bytesum = 0
        if self.format_guide_display == 'GML':
            byteattributes = []
            text += "vertex_format_begin()\n"
            for a in format.attributes:
                if a.is_byte:
                    bytesum += a.size
                    byteattributes.append(a.attribute)
                    while bytesum >= 4:
                        text += "vertex_format_add_color()  // %s\n" % (", ".join(byteattributes))
                        byteattributes = byteattributes[1:]
                        bytesum -= 4
                elif a.attribute == 'POSITION' and a.size == 3:
                    text += "vertex_format_add_position_3d()\n"
                elif a.attribute=='POSITION' and a.size == 2:
                    text += "vertex_format_add_position()\n"
                elif a.attribute=='UV' and a.size == 2:
                    text += "vertex_format_add_texcoord()\n"
                else:
                    text += "vertex_format_add_%s()\n" % a.attribute.lower()
            text += "format = vertex_format_end()"
        elif self.format_guide_display == 'SHADER':
            colorindex = 0
            byteparts = []
            bytenum = sum([a.size for a in format.attributes if a.is_byte])
            for a in format.attributes:
                if a.is_byte:
                    bytesum += a.size
                    byteparts += VBM_ATTRIBUTE_VARPART[a.attribute][:a.size]
                    while bytesum >= 4:
                        if bytenum <= 4:
                            text += "attribute vec%d in_Colour;\t// (%s)\n" % (4, ", ".join(byteparts[:4]))
                        else:
                            text += "attribute vec%d in_Colour%d;\t// (%s)\n" % (4, colorindex, ", ".join(byteparts[:4]))
                        colorindex += 1
                        byteparts = byteparts[4:]
                        bytesum -= 4
                elif a.attribute=='UV':
                    text += "attribute vec%d in_TextureCoord;\t// (%s)\n" % (a.size, ", ".join(VBM_ATTRIBUTE_VARPART[a.attribute][:a.size]))
                else:
                    text += "attribute vec%d in_%s;\t// (%s)\n" % (a.size, a.attribute[0].upper()+a.attribute[1:].lower(), ", ".join(VBM_ATTRIBUTE_VARPART[a.attribute][:a.size]))
        return text
    # ..........................................................................
    def EvaluateDeformOrder(self, skeleton_object, enabled_list=[]):
        if not skeleton_object:
            return ({}, {})
        
        # All -> Deform Only
        deformmap = {}
        deformbones = [b for b in skeleton_object.data.bones if b.use_deform]
        for b in deformbones:
            p = b.parent
            usedparents = []
            if p and not p.use_deform:
                while p and not p.use_deform:
                    usedparents.append(p)
                    d = skeleton_object.data.bones.get(p.name.replace('ORG-', 'DEF-'))
                    p = d if (d and d != b and (d.use_deform or d not in usedparents)) else p.parent
            deformmap[b.name] = p.name if p else None
        deformmapraw = dict(deformmap)
        
        # Deform Only -> Enabled Only
        deformalias = {bname: bname for bname, pname in deformmap.items()} # Map non-enabled bone to first enabled bone, or itself if already enabled
        if enabled_list:
            dissolvemap = {}
            deformalias = {}
            FirstEnabled = lambda bname: bname if (bname in enabled_list or bname=="") else FirstEnabled(deformmap.get(bname, ""))
            for bname, pname in deformmap.items():
                alias = FirstEnabled(bname)
                pname = FirstEnabled(pname)
                deformalias[bname] = alias
                if alias == bname:
                    dissolvemap[bname] = pname
            deformmap = dissolvemap
        
        # Calculate order based on parents
        deformorder = []
        DeformWalk = lambda bname: (deformorder.append(bname), [DeformWalk(child) for child in [k for k,p in list(deformmap.items()) if p==bname]])
        [DeformWalk(bname) for bname,p in deformmap.items() if not p]
        deformorder = ['0'] + deformorder
        
        skeleton_object['DEFORM_MAP'] = {bname: deformmap.get(bname, None) for bname in deformorder} # {bonename: parentname}
        skeleton_object['DEFORM_MAPRAW'] = {bname: deformmapraw.get(bname, None) for bname in deformorder} # {bonename: parentname}
        skeleton_object['DEFORM_ALIAS'] = deformalias   # {bonename: first_enabled_name}
        skeleton_object['DEFORM_ORDER'] = deformorder   # [0, first_bone, second_bone, ...]
        return (skeleton_object['DEFORM_ORDER'], skeleton_object['DEFORM_MAP'])
    
    def UpdateDeformMask(vbm, mask_prop, rig):
        lastbones = {b.name: (
            b.enabled, 
            {p.identifier: getattr(b.swing, p.identifier) for p in b.swing.bl_rna.properties if not p.is_readonly},
            {p.identifier: getattr(b.collider, p.identifier) for p in b.collider.bl_rna.properties if not p.is_readonly}
            ) for b in mask_prop
        }
        mask_prop.clear()
        rig.vbm['mutex'] = 0
        vbm.EvaluateDeformOrder(rig)
        deformorder, deformmap = (rig['DEFORM_ORDER'], rig['DEFORM_MAP'])
        CountParents = lambda name,num=0: CountParents(deformmap[name], num+1) if deformmap.get(name, None) else num
        for bname in deformorder:
            item = mask_prop.add()
            item.name = bname
            item.parent = deformmap.get(bname) if deformmap.get(bname, None) else ""
            item.depth = CountParents(bname)
            if lastbones.get(bname, None):
                enabled, swing, collider = lastbones[bname]
                item.enabled = enabled
                [setattr(item.swing, k, v) for k,v in swing.items()]
                [setattr(item.collider, k, v) for k,v in collider.items()]
    # ..........................................................................
    def MeshChecksum(vbm, mesh_object):
        return sum([
            value for value in (
                [x for v in mesh_object.data.vertices for x in list(v.co)+[vge.weight for vge in v.groups]] +
                [x for lyr in mesh_object.data.color_attributes for v in lyr.data for x in v.color] +
                [x for lyr in mesh_object.data.uv_layers for v in lyr.data for x in v.uv] + 
                [vbm.MeshChecksum(m.object) for m in mesh_object.modifiers if getattr(m, 'object', None)]
            )
        ])
    
    def ActionChecksum(vbm, action, skeleton_object):
        return sum([
            value for value in (
                [x for b in skeleton_object.data.bones for v in (b.head_local, b.tail_local) for x in v] +
                [x for fc in action.fcurves for k in fc.keyframe_points for x in k.co]
            )
        ])
    
    # ..........................................................................
    def Export(vbm, queue="", settings={}):
        benchmark = {}
        benchmark['export'] = time.time()
        
        context = bpy.context
        lastactive = context.active_object.name if context.active_object else ""
        
        def Cleanup():
            [bpy.data.objects.remove(x) for x in list(bpy.data.objects)[::-1] if '_temp' in x.name] if cleanmap.get('OBJECT', 1) else []
            [bpy.data.meshes.remove(x) for x in list(bpy.data.meshes)[::-1] if '_temp' in x.name] if cleanmap.get('OBJECT', 1) else []
            [bpy.data.actions.remove(x) for x in list(bpy.data.actions)[::-1] if '_temp' in x.name] if cleanmap.get('ACTION', 1) else []
            [bpy.data.armatures.remove(x) for x in list(bpy.data.armatures)[::-1] if '_temp' in x.name] if cleanmap.get('ARMATURE', 1) else []
            [bpy.data.images.remove(x) for x in list(bpy.data.images)[::-1] if '_temp' in x.name] if cleanmap.get('IMAGE', 1) else []
        
        cleanmap = {}
        Cleanup()
        cleanmap = {k:k not in vbm.export_cleanup_exclude for i,k in enumerate(VBM_CLEANUPKEYS)}
        
        print("VBM Exporter"+"-"*80)
        
        # Settings ===========================================================================
        queue = vbm.queues.get(settings.get('queue', queue))
        if queue:
            settings = {p.identifier: getattr(queue, p.identifier) for p in queue.bl_rna.properties if not p.is_readonly}
            settings['queue'] = queue.name
        
        filepath = bpy.path.abspath(settings.get('filepath', "//model.vbm"))
        filepath_ext = settings.get('filepath_ext', ".vbm")
        collection = settings.get('collection', "")
        export_meshes = settings.get('mesh_export', True)
        export_skeleton = settings.get('skeleton_export', True)
        export_animation = settings.get('action_export', True)
        compression_level = settings.get('compression_level', -1)
        mesh_material_override = settings.get('mesh_material_override', "")
        mesh_script_pre = settings.get('mesh_script_pre', "")
        mesh_script_post = settings.get('mesh_script_post', "")
        mesh_delimiter = (settings.get('mesh_delimiter_start', ""), settings.get('mesh_delimiter_end', ""))
        mesh_grouping = settings.get('mesh_grouping', 'OBJECT')
        mesh_alledges = settings.get('mesh_alledges', 0)
        action_clean_threshold = settings.get('action_clean_threshold', 0.0001)
        format_code = settings.get('format_code', VBM_FORMAT_CODEDEFAULT)
        
        mesh_material_override = bpy.data.materials.get(mesh_material_override, "") if isinstance(mesh_material_override, str) else mesh_material_override
        mesh_script_post =  bpy.data.texts.get(mesh_script_post, "") if isinstance(mesh_script_post, str) else mesh_script_post
        mesh_script_pre =  bpy.data.texts.get(mesh_script_pre, "") if isinstance(mesh_script_pre, str) else mesh_script_pre
        format = vbm.formats.get(settings.get('format', ""))
        if format:
            format_code = format.code
        
        collections = []
        actions = []
        objectentries = []  # (src, mtl)
        armature = None
        
        if queue:
            print("Queue:", queue)
            for item in queue.checkout:
                if item.enabled:
                    # Collection
                    if item.collection:
                        collections.append(item.collection)
                        [objectentries.append((obj, item)) for obj in item.collection.objects]
                        if item.include_child_collections:
                            for c in item.collection.children:
                                [objectentries.append((obj, item)) for obj in c]
                    # Object
                    elif item.object:
                        if not armature and item.object.type == 'ARMATURE':
                            armature = item.object
                        else:
                            objectentries.append((item.object, item))
                        if item.include_child_objects:
                            objectentries += [(x, item) for x in list(item.object.children)]
                        if item.action:
                            actions.append(item.action)
                    # Action
                    elif item.action:
                        actions.append(item.action)
        else:
            collection = bpy.data.collections.get(collection, None) if isinstance(collection, str) else collection
            if collection:
                print("Collection:", collection)
                [objectentries.append((obj, None)) for obj in collection.all_objects]
            else:
                [objectentries.append((obj, None)) for obj in context.selected_objects]
        
        format_params = vbm.FormatStringDecode(format_code)
        use_skinning = sum([x in [f[0] for f in format_params] for x in 'BONE WEIGHT'.split()]) > 0
        
        objectentries = [x for x in objectentries if x[0].name[0].lower() in 'qwertyuiopasdfghjklzxcvbnm']
        sourcerigs = list(set([x.find_armature() for x,item in objectentries if x.find_armature()])) if use_skinning else []
        netmaterials = []
        netimages = []
        
        for rig in sourcerigs:
            vbm.EvaluateDeformOrder(rig, [x.name for x in rig.vbm.deform_mask if x.enabled])
        
        resources = {
            'skeletons': [],
            'meshes': [],
            'textures': [],
            'animations': [],
        }
        
        # Meshes ========================================================================
        meshgroups = {} # { objectname: {mtlname, loopcount, loopdata} } }
        materialgroups = {} # [ {name, loopcount, loopdata}, ...]
        outmeshes = b''
        
        NodeWalk = lambda nd,out=[]: (out.append(nd), [NodeWalk(l.from_node, out) for s in nd.inputs for l in s.links if l.from_node], out)[-1]
        
        # Evaluate Objects ...............................................................
        if export_meshes:
            print("> Mesh Staging")
            benchmark['mesh_staging'] = time.time()
            targetmeshes = []
            
            # Copy source objects as temporary
            for src,item in objectentries:
                if src and src.type == 'MESH':
                    obj = bpy.data.objects.new(name="__temp_VBMEXPORT-"+src.name, object_data=src.data.copy())
                    obj.data.name = "__temp_VBMEXPORT-"+src.data.name
                    obj.matrix_world = src.matrix_world
                    context.scene.collection.objects.link(obj)
                    
                    if item and item.action and src.find_armature():
                        src.find_armature().animation_data.action = item.action
                        src.find_armature().data.pose_position = 'POSE'
                    
                    # Run Pre Script
                    if mesh_script_pre:
                        print("> Mesh Script Pre:")
                        obj.select_set(True)
                        bpy.context.view_layer.update()
                        context.scene['VBM_EXPORTING'] = True
                        try:
                            exec(mesh_script_pre.as_string())
                        except:
                            print("Error executing export pre script")
                        context.scene['VBM_EXPORTING'] = False
                    
                    # Copy modifiers
                    for msrc in src.modifiers:
                        if msrc.name[0].lower() in 'qwertyuiopasdfghjklzxcvbnm':
                            m = obj.modifiers.new(name=msrc.name, type=msrc.type)
                            [setattr(m, p.identifier, getattr(msrc, p.identifier)) for p in msrc.bl_rna.properties if not p.is_readonly]
                            m.show_viewport = True
                            if m.type == 'NODES':
                                m['Socket_2'] = msrc['Socket_2']
                            if m.type == 'ARMATURE':
                                m.use_vertex_groups = not use_skinning
                    
                    # Use instances
                    instsrc = src.children[0] if src.children else None
                    if src.instance_type=='FACES' and instsrc:
                        instscale = src.instance_faces_scale if src.use_instance_faces_scale else 1.0
                        for p in obj.data.polygons:
                            # TODO: Implement rotation for instanced objects
                            inst = bpy.data.objects.new(name="__temp_VBMEXPORT-"+instsrc.name, object_data=instsrc.data.copy())
                            scale = (p.area ** 0.5) * instscale
                            inst.matrix_world = src.matrix_world @ mathutils.Matrix.LocRotScale(p.center, None, [scale]*3)
                            context.scene.collection.objects.link(inst)
                            if not mesh_alledges:
                                m = inst.modifiers.new(name="Triangle", type='TRIANGULATE')
                                if bpy.app.version < (4,2,0):
                                    m.keep_custom_normals=True
                            targetmeshes.append((inst, instsrc, item))
                    else:
                        if not mesh_alledges:
                            m = obj.modifiers.new(name="Triangle", type='TRIANGULATE')
                            if bpy.app.version < (4,2,0):
                                m.keep_custom_normals=True
                        targetmeshes.append((obj, src, item))
            
            # Finalize objects
            if targetmeshes:
                [x.select_set(False) for x in context.selected_objects]
                [x.select_set(True) for x,src,mtl in targetmeshes]
                [obj.select_set(True) for obj,src,mtl in targetmeshes]
                
                context.view_layer.objects.active = targetmeshes[0][0]
                bpy.ops.object.convert(target='MESH')
                bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
                context.view_layer.objects.active = bpy.data.objects.get(lastactive, None)
            benchmark['mesh_staging'] = time.time()-benchmark['mesh_staging']
            
            # Build VBs .....................................................................
            print("> Mesh building")
            benchmark['mesh_data'] = time.time()
            for obj,src,checkout_item in targetmeshes:
                print(src.name, checkout_item)
                groupkey = src.data.name if mesh_grouping == 'MESH' else src.name
                context.view_layer.objects.active = obj
                obj.select_set(True)
                
                # Object .............................................................
                if mesh_script_post:
                    print("> Mesh Script Post:")
                    bpy.context.view_layer.update()
                    context.scene['VBM_EXPORTING'] = True
                    try:
                        exec(mesh_script_post.as_string())
                    except:
                        print("Error executing export post script")
                    context.scene['VBM_EXPORTING'] = False
                
                obj.data.calc_loop_triangles()
                if VBM_BLENDER_4_0:
                    obj.data.calc_normals_split()
                obj.data.update()
                
                # Data ..........................................................................................
                verts = tuple(obj.data.vertices)
                loops = tuple(obj.data.loops)
                polys = tuple(obj.data.polygons)
                skinning = [ ((0,1.0), (0,0.0), (0,0.0), (0,0.0)) ] * len(verts)
                
                armature = src.find_armature()
                boneorder = armature['DEFORM_ORDER'] if (use_skinning and armature) else []
                if sum([vg.name in boneorder for vg in obj.vertex_groups]):
                    deformalias = armature['DEFORM_ALIAS']
                    grouptobone = {     # Map vertex group index to bone in deformmap
                        vg.index: boneorder.index(deformalias[vg.name] if deformalias.get(vg.name, None) else vg.name) 
                        for vg in obj.vertex_groups if vg.name in boneorder or deformalias.get(vg.name, None) in boneorder
                    }
                    
                    skinning = [ [ (grouptobone[vge.group], vge.weight) for vge in v.groups if vge.weight > 0.0 and vge.group in list(grouptobone.keys())] for v in verts ]
                    [v.sort(key=lambda x: x[1]) for v in skinning]  # Sort by weight
                    skinning = [ (x+[(0,0.0), (0,0.0), (0,0.0), (0,0.0)])[:4] for x in skinning ]    # Add padding, Clamp to 4
                
                # Mesh Groups ................................................................................
                faceloops = tuple((l,v) for p in polys for l,v in zip(p.loop_indices, p.vertices))
                
                meshsplitvgroupindices = tuple([vg.index for vg in obj.vertex_groups if vg.name[:5]=="MESH="])
                polyindexgroups = []     # [ (material_index, groupname, polyindices[]) ]
                
                for material_index, mtl in enumerate(obj.data.materials):
                    mtlpolys = tuple([p for p in polys if p.material_index == material_index])
                    for vg in [vg for vg in obj.vertex_groups if vg.index in meshsplitvgroupindices]:
                        polyindexgroups.append((
                            material_index, vg.name.replace("MESH=", ""),
                            tuple([p.index for p in mtlpolys if sum([vge.group==vg.index for v in p.vertices for vge in verts[v].groups])==len(p.vertices)]) 
                        ))
                    polyindexgroups.append((
                        material_index, groupkey,
                        tuple([p.index for p in mtlpolys if sum([vge.group in meshsplitvgroupindices for v in p.vertices for vge in verts[v].groups])!=len(p.vertices)]) 
                    ))
                
                # Build data by attribute .....................................................................
                attribdata = [bytearray() for x in format_params]
                attribformat = [[i]+list(a) for i,a in enumerate(format_params)]
                for attrib_index, attrib_type, size, flags, lyrname, value in attribformat:
                    attrib_datatype = 'B' if flags else 'f'
                    isbyte = flags & VBM_FORMAT_FL_ISBYTE
                    srgbpower = (1.0/2.2) if (flags & VBM_FORMAT_FL_SRGB) else 1.0
                    if isbyte:
                        value = [x/255 for x in value]
                    
                    if attrib_type == 'POSITION':
                        attribdata[attrib_index].extend(b''.join([Pack('f', x) for l,v in faceloops for x in verts[v].co[:size]]))
                    elif attrib_type == 'NORMAL':
                        if isbyte:
                            attribdata[attrib_index].extend(b''.join([Pack('B', int(x*255.0)) for l,v in faceloops for x in ([y*0.5+0.5 for y in loops[l].normal]+value[3:])[:size] ]))
                        else:
                            attribdata[attrib_index].extend(b''.join([Pack('f', x) for l,v in faceloops for x in (list(loops[l].normal)+value)[:size] ]))
                    elif attrib_type == 'COLOR':
                        lyr = obj.data.color_attributes.get(lyrname, obj.data.color_attributes[obj.data.color_attributes.active_color_index]) if obj.data.color_attributes else None
                        lyrvalues = [ list(v.color) for v in lyr.data ] if lyr else [numpy.array(value)] * len(faceloops)
                        if isbyte:
                            attribdata[attrib_index].extend(b''.join([Pack('B', int((x**srgbpower)*255.0)) for v in lyrvalues for x in v[:size]]))
                        else:
                            attribdata[attrib_index].extend(b''.join([Pack('f', (x**srgbpower)) for v in lyrvalues for x in v[:size]]))
                    elif attrib_type == 'UV':
                        lyr = obj.data.uv_layers.get(lyrname, ([x for x in obj.data.uv_layers if x.active_render]+[None])[0])
                        lyrvalues = [ list((v.uv[0], 1.0-v.uv[1])) for v in lyr.data ] if lyr else [value] * len(faceloops)
                        if isbyte:
                            attribdata[attrib_index].extend(b''.join([Pack('B', int(x*255.0)) for v in lyrvalues for x in v[:size]]))
                        else:
                            attribdata[attrib_index].extend(b''.join([Pack('f', x) for v in lyrvalues for x in v[:size]]))
                    elif attrib_type == 'BONE':
                        if isbyte:
                            attribdata[attrib_index].extend(b''.join([Pack('B', int(b)) for l,v in faceloops for b,w in skinning[v][:size]]))
                        else:
                            attribdata[attrib_index].extend(b''.join([Pack('f', b) for l,v in faceloops for b,w in skinning[v][:size]]))
                    elif attrib_type == 'WEIGHT':
                        skinning_attrib = [ [(b,w/s) for b,w in v[:size]] for v in skinning for s in [sum([w for b,w in v[:size]])+0.00000001] ] # Normalize weights
                        if isbyte:
                            attribdata[attrib_index].extend(b''.join([Pack('B', int(w*255.0)) for l,v in faceloops for b,w in skinning_attrib[v]]))
                        else:
                            attribdata[attrib_index].extend(b''.join([Pack('f', w) for l,v in faceloops for b,w in skinning_attrib[v]]))
                    elif attrib_type == 'GROUP':
                        group = obj.vertex_groups.get(lyrname, None)
                        lyrvalues = [([vge.weight for vge in v.groups if vge.group==group.index]+[0.0])[0] for v in verts] if group else ([value[0]]*len(verts))
                        if isbyte:
                            attribdata[attrib_index].extend(b''.join([Pack('B', int(x*255.0)) for l,v in faceloops for x in [lyrvalues[v]]*size]))
                        else:
                            attribdata[attrib_index].extend(b''.join([Pack('f', x) for l,v in faceloops for x in [lyrvalues[v]]*size]))
                    else: # Padding
                        if isbyte:
                            attribdata[attrib_index].extend(b''.join([Pack('B', int(x*255.0)) for l in range(0, len(faceloops)) for x in value[:size]]))
                        else:
                            attribdata[attrib_index].extend(b''.join([Pack('f', x) for l in range(0, len(faceloops)) for x in value[:size]]))
                    attribdata[attrib_index] = bytes(attribdata[attrib_index])
                
                # Partition data per loop ............................................................................
                for material_index, groupkey, polyindices in polyindexgroups:
                    if not mesh_alledges:
                        vb = b''.join([
                            attribdata[attrib_index][l*space:l*space+space]
                            for t in polyindices
                            for l,v in faceloops[t*3:t*3+3]
                            for attrib_index, dtype, size, flags, lyrname, value in attribformat
                            for space in [size * (1 if (flags & VBM_FORMAT_FL_ISBYTE) else 4)]
                        ])
                        loopcount = len(polyindices)*3
                    else:
                        vb = b''.join([
                            attribdata[attrib_index][l*space:l*space+space]
                            for t in polyindices
                            for i in range(0, polys[t].loop_total)
                            for faceloop in [( faceloops[polys[t].loop_indices[i]], faceloops[polys[t].loop_indices[(i+1)%polys[t].loop_total]] )]
                            for l,v in faceloop
                            for attrib_index, dtype, size, flags, lyrname, value in attribformat
                            for space in [size * (1 if (flags & VBM_FORMAT_FL_ISBYTE) else 4)]
                        ])
                        loopcount = sum([polys[t].loop_total*2 for t in polyindices])
                    
                    if loopcount > 0:
                        groupkey = groupkey[groupkey.find(mesh_delimiter[0])+1:] if mesh_delimiter[0] and mesh_delimiter[0] in groupkey else groupkey
                        groupkey = groupkey[:groupkey.find(mesh_delimiter[1])] if mesh_delimiter[1] and mesh_delimiter[1] in groupkey else groupkey
                        
                        grouping = checkout_item.mesh_grouping if checkout_item and checkout_item.mesh_grouping != 'NONE' else mesh_grouping
                        
                        material = obj.data.materials[material_index] if grouping == 'MATERIAL' else obj.active_material
                        material = mesh_material_override if mesh_material_override else material
                        material = checkout_item.material_override if checkout_item and checkout_item.material_override else material
                        if material.vbm.alias:
                            material = material.vbm.alias
                        
                        nodes = []
                        [NodeWalk(nd, nodes) for nd in material.node_tree.nodes if nd.bl_idname=='ShaderNodeOutputMaterial']
                        materialimages = list(set([nd.image for nd in nodes if nd.bl_idname=='ShaderNodeTexImage' and nd.image]))
                        netmaterials.append(material)
                        netimages += materialimages
                        
                        if grouping == 'MATERIAL':
                            meshkey = material.name if material else ""
                        else:
                            meshkey = groupkey
                        
                        meshgroups[meshkey] = meshgroups.get(groupkey, {'data': b'', 'material': 0, 'loopcount': 0, 'format': []})
                        meshgroups[meshkey]['data'] += vb
                        meshgroups[meshkey]['loopcount'] += loopcount
                        meshgroups[meshkey]['is_edge'] = mesh_alledges
                        meshgroups[meshkey]['format'] = [
                            VBM_FORMAT_KEY.index(attribname) | (size << 4) | (bool(flags & VBM_FORMAT_FL_ISBYTE) << 7)
                            for attribname,size,flags,lyrname,value in format_params
                        ]
                        meshgroups[meshkey]['texture'] = materialimages[0].name if materialimages else ""
                        meshgroups[meshkey]['material'] = material.name if material else ""
                        
                        xcoords, ycoords, zcoords = ([], [], [])
                        [(xcoords.append(x), ycoords.append(y), zcoords.append(z)) for t in polyindices for l,v in faceloops[t*3:t*3+3] for x,y,z in [verts[v].co]]
                        meshgroups[meshkey]['bounds_min'] = (numpy.min(xcoords), numpy.min(ycoords), numpy.min(zcoords))
                        meshgroups[meshkey]['bounds_max'] = (numpy.max(xcoords), numpy.max(ycoords), numpy.max(zcoords))
                        
                        print(
                            "  %16s VB: %8d | loops: %6d | stride: %2d | %s" % 
                                (groupkey, len(vb), loopcount, len(vb)/loopcount, material.name if material else "(nullmtl)"), 
                            "<"+ " ".join(["%s=%d" % (f[0][:3],f[1]*(1 if f[2] else 4)) for f in format_params]) + ">"
                        )
            benchmark['mesh_data'] = time.time()-benchmark['mesh_data']
            
            Cleanup()
            
            netmaterials = list(set(netmaterials))
            netimages = list(set(netimages))
            
            # Write Mesh Entries
            benchmark['mesh_file'] = time.time()
            for meshname, meshgroup in meshgroups.items():
                outmesh = b''
                outmesh += PackString(meshname) # Mesh name
                outmesh += Pack('B', [x.name for x in netimages].index(meshgroup['texture']) if meshgroup.get('texture', "") else 255) # Texture Index
                outmesh += Pack('B', [x.name for x in netmaterials].index(meshgroup['material']) if meshgroup.get('material', "") else 255) # Material Index
                outmesh += PackVector('f', meshgroup['bounds_min'])
                outmesh += PackVector('f', meshgroup['bounds_max'])
                outmesh += Pack('B', len(meshgroup['format'])) # Format Length
                outmesh += b''.join([Pack('B', x) for x in meshgroup['format']]) # Format Attributes
                outmesh += Pack('B', VBM_MESH_FL_ISEDGE * meshgroup['is_edge']) # Flags
                outmesh += Pack('I', meshgroup['loopcount']) # Loopcount
                outmesh += Pack('I', len(meshgroup['data'])) # Buffer size
                outmesh += meshgroup['data'] # Buffer data
                resources['meshes'].append(outmesh)
            benchmark['mesh_file'] = time.time()-benchmark['mesh_file']
        
        # Texture ==================================================================================
        for image in netimages:
            w,h = image.size
            pixels = numpy.array(image.pixels).reshape((-1,h,4))[::-1,:,:].flatten() # Partition to rows, columns, channels; Flip rows; Flatten
            pixelbytes = (pixels*255.0).astype(numpy.uint8)
            colors = numpy.frombuffer(pixelbytes.tobytes(), dtype=numpy.uint32)
            palette = list( set(colors) )
            print(image.name, "psize:", len(palette))
            
            for i,m in enumerate([2, 4, 8, 12, 16, 24, 32, 48, 64, 96, 128]):
                if len(palette) > 255:
                    colors = numpy.frombuffer(  ( ((pixels*255)/m).round()*m ).clip(0,255).astype(numpy.uint8).tobytes(), dtype=numpy.uint32)
                    palette = list( set(colors) )
                    print("psize [%d]:" % i, len(palette))
            indices = numpy.array([palette.index(x) for x in colors], dtype=numpy.uint8)
            
            tmp = bpy.data.images.new('__temp-'+image.name, image.size[0], image.size[1], alpha=True)
            tmp.pixels = numpy.frombuffer(  numpy.array([palette[i] for i in indices], dtype=numpy.uint32).tobytes(), dtype=numpy.uint8).astype(numpy.float32) / 255.0
            
            outimage = b''
            outimage += PackString(image.name)  # Image name
            outimage += Pack('I', w)    # Width
            outimage += Pack('I', h)    # Height
            outimage += Pack('B', len(palette))    # Palette Size
            outimage += b''.join([Pack('I', color) for color in palette])   # Palette Colors
            outimage += indices.tobytes()   # Color indices
            resources['textures'].append(outimage)
        
        # Skeleton ==================================================================================
        if export_skeleton:
            boneentries = [] # [ {name, head, tail, roll, parentname} ]
            for rig in sourcerigs:
                vbmskeleton = rig.vbm
                CountParents = lambda name,num=0: CountParents(deformmap[name], num+1) if deformmap.get(name, None) else num
                deformorder, deformmap, deformmapraw = (rig['DEFORM_ORDER'], rig['DEFORM_MAP'], rig['DEFORM_MAPRAW'])
                DeformChain = lambda chain: ([chain.append(bname) for bname,pname in deformmapraw.items() if pname in chain], chain)[-1]
                
                # Swing + Colliders
                swingchains = []
                colliderchains = []
                for pb in rig.pose.bones:
                    if pb.bone.use_deform:
                        swinglabel = vbmskeleton.swing_bones.get(pb.name, "")
                        swing = vbmskeleton.deform_mask.get(swinglabel.name, None).swing if swinglabel else None
                        if swing and swing.is_chain:
                            swingchains.append(DeformChain([pb.name]))
                        
                        colliderlabel = vbmskeleton.collider_bones.get(pb.name, "")
                        collider = vbmskeleton.deform_mask.get(colliderlabel.name, None).collider if colliderlabel else None
                        if collider and collider.is_chain:
                            colliderchains.append(DeformChain([pb.name]))
                swinglist = []
                colliderlist = []
                swingmap = {}   # { bname: swing_index }
                collidermap = {}   # { bname: swing_index }
                
                for bname in deformorder:
                    if not vbmskeleton.deform_mask or vbmskeleton.deform_mask[bname].enabled:
                        swinglabel = vbmskeleton.swing_bones.get(bname, "")
                        swing = vbmskeleton.deform_mask.get(swinglabel.name, None).swing if swinglabel else None
                        if not swing:
                            for chain in swingchains[::-1]:
                                if bname in chain:
                                    swing = vbmskeleton.deform_mask.get(chain[0]).swing
                                    break
                        if swing:
                            if swing not in swinglist:
                                swinglist.append(swing)
                            swingmap[bname] = swinglist.index(swing)
                        
                        colliderlabel = vbmskeleton.collider_bones.get(bname, "")
                        collider = vbmskeleton.deform_mask.get(colliderlabel.name, None).collider if colliderlabel else None
                        if not collider:
                            for chain in colliderchains[::-1]:
                                if bname in chain:
                                    collider = vbmskeleton.deform_mask.get(chain[0]).collider
                                    break
                        if collider:
                            if collider not in colliderlist:
                                colliderlist.append(collider)
                            collidermap[bname] = colliderlist.index(collider)
                
                # Bone meta
                for bname in deformorder:
                    b = rig.data.bones.get(bname)
                    if b:
                        boneentries.append({
                            'name': b.name,
                            'head': b.head_local,
                            'tail': b.tail_local,
                            'roll': b.AxisRollFromMatrix(mathutils.Matrix([v[:3] for v in b.matrix_local[:3]]))[1], 
                            'parent': deformmap.get(b.name),
                            'swing_index': swingmap.get(bname, 255),
                            'collider_index': collidermap.get(bname, 255)
                        })
                    else:
                        boneentries.append({'name': "0", 'head': (0,0,0), 'tail': (0,1,0), 'roll': 0.0, 'parent': "0", 'swing_index': 255, 'collider_index': 255})
                
                outskeleton = b''
                outskeleton += Pack('I', len(swinglist))
                for swing in swinglist:
                    outskeleton += Pack('f', swing.friction)
                    outskeleton += Pack('f', swing.stiffness)
                    outskeleton += Pack('f', swing.dampness)
                    outskeleton += Pack('f', swing.gravity)
                    outskeleton += PackVector('f', swing.offset)
                    outskeleton += PackVector('f', [swing.angle_min_x, swing.angle_max_x])
                    outskeleton += PackVector('f', [swing.angle_min_z, swing.angle_max_z])
                
                outskeleton += Pack('I', len(colliderlist))
                for collider in colliderlist:
                    outskeleton += Pack('f', collider.radius)
                    outskeleton += Pack('f', collider.length)
                    outskeleton += PackVector('f', collider.offset)
                
                outskeleton += Pack('I', len(boneentries))
                for bone in boneentries:
                    outskeleton += PackString(bone['name'].replace('DEF-', ""))
                    outskeleton += Pack('I', deformorder.index(bone['parent']) if bone['parent'] in deformorder else 0)
                    outskeleton += PackVector('f', bone['head'])
                    outskeleton += PackVector('f', bone['tail'])
                    outskeleton += Pack('f', bone['roll'])
                    outskeleton += Pack('B', bone['swing_index'])
                    outskeleton += Pack('B', bone['collider_index'])
                
                resources['skeletons'].append(outskeleton)
        
        # Animations ================================================================================
        animationentries = []
        if export_animation:
            for rig in sourcerigs:
                sourceactions = []
                #nlaactions = [s.action for t in rig.animation_data.nla_tracks for s in t.strips if s.action][::-1] if rig and rig.animation_data else []
                #[sourceactions.append(x) for x in nlaactions+[rig.animation_data.action] if x not in actions]
                [sourceactions.append(x) for x in actions+([rig.animation_data.action] if rig.animation_data and rig.animation_data.action else []) if x not in sourceactions]
                print([x.name for x in sourceactions])
                if sourceactions:
                    preaction = rig.animation_data.action
                    
                    # Create Proxy ............................................................................
                    benchmark['anim_staging'] = time.time()
                    proxy = bpy.data.objects.new(name='__temp_VBMEXPORT-'+rig.name, object_data=bpy.data.armatures.new('__temp_VBMEXPORT-'+rig.data.name))
                    context.scene.collection.objects.link(proxy)
                    context.view_layer.objects.active=proxy
                    proxy.animation_data_create()
                    proxy.display_type='WIRE'
                    proxy.show_in_front=True
                    
                    proxymeta = {
                        b.name: (b.head_local.copy(), b.tail_local.copy(), b.AxisRollFromMatrix(b.matrix_local.to_3x3())[1], b.use_connect, b.matrix_local.copy())
                        for b in rig.data.bones if b.use_deform
                    }
                    deformmap = rig['DEFORM_MAP']
                    deformorder = rig['DEFORM_ORDER']
                    
                    [x.select_set(False) for x in context.selected_objects]
                    proxy.select_set(True)
                    bpy.ops.object.mode_set(mode='EDIT')
                    
                    for b,meta in [(proxy.data.edit_bones.new(bname), meta) for bname, meta in proxymeta.items()]:
                        b.head, b.tail, b.roll, b.use_connect = (list(meta[:4]))
                        #b.tail, b.roll, b.use_connect = ((b.head[0], b.head[1]+0.1, b.head[2]), 0, 0)
                    for b in proxy.data.edit_bones:
                        b.parent = proxy.data.edit_bones[deformmap.get(b.name)] if deformmap.get(b.name) else None
                        
                    bpy.ops.object.mode_set(mode='POSE')
                    bpy.ops.pose.select_all(action='SELECT')
                    for pb in proxy.pose.bones:
                        c = pb.constraints.new(type='COPY_TRANSFORMS')
                        c.target, c.subtarget = (rig, pb.name)
                        #c.mix_mode, c.target_space, c.owner_space = ('AFTER_SPLIT', 'LOCAL_OWNER_ORIENT', 'WORLD')
                        #c = pb.constraints.new(type='COPY_LOCATION')
                        #c.target, c.subtarget = (rig, pb.name)
                    benchmark['anim_staging'] = time.time()-benchmark['anim_staging']
                    
                    # Parse Actions .............................................................................
                    benchmark['anim_bake'] = time.time()
                    for src in sourceactions:
                        checksum = vbm.ActionChecksum(src, rig)
                        if src.get('VBM_CHECKSUM', 0) != checksum or not src.get('VBM_CURVEDATA', []):
                            action = src.copy()
                            action.name = '__temp_VBMEXPORT-'+src.name
                            
                            # Bake Action ...............................................................
                            rig.animation_data.action = src
                            proxy.animation_data.action = action
                            fstart, fend = src.frame_start, max(src.frame_start+1, src.frame_end)
                            duration = max(1, fend-fstart)
                            context.scene.frame_set(int(fstart))
                            
                            print("> Baking Action", src.name, (fstart, fend))
                            
                            srccurvepaths = tuple([fc.data_path[fc.data_path.find('"')+1:fc.data_path.rfind('"')] for fc in src.fcurves])
                            usedbones = [b.name for b in rig.data.bones if b.name in srccurvepaths]
                            usedbones += ['DEF-'+bname for bname in usedbones]
                            
                            for pb in list(rig.pose.bones) + list(proxy.pose.bones):
                                pb.location, pb.rotation_quaternion, pb.rotation_euler, pb.scale = ((0,0,0), (1,0,0,0), pb.rotation_euler, (1,1,1))
                            
                            bpy.ops.nla.bake(
                                frame_start=int(src.curve_frame_range[0]), frame_end=int(src.curve_frame_range[1]), bake_types={'POSE'}, step=1,
                                only_selected=False, visual_keying=True, clear_constraints=False, clear_parents=False, use_current_action=True, clean_curves=True,
                            )
                            [fc.update() for fc in action.fcurves]
                            areatype = context.area.type
                            context.area.type = 'GRAPH_EDITOR'
                            bpy.ops.graph.clean(channels=False, threshold=action_clean_threshold)
                            context.area.type = areatype
                            
                            # Write Action ...............................................................
                            fcurves = action.fcurves
                            curvepaths = tuple([fc.data_path[fc.data_path.find('"')+1:fc.data_path.rfind('"')] for fc in fcurves])
                            
                            transformkeys = [('.location', i) for i in (0,1,2)] + [('.rotation_quaternion', i) for i in (0,1,2,3)] + [('.scale', i) for i in (0,1,2)]
                            curvedata = {bname: [ [] for i in range(0, 10) ] for bname in deformorder}
                            fcurves = action.fcurves
                            
                            for bone_index, bonename in enumerate(deformorder):
                                for transform_index, transform_key in enumerate(transformkeys):
                                    fc = fcurves.find('pose.bones["%s"]%s' % (bonename, transform_key[0]), index=transform_key[1])
                                    curvedata[bonename][transform_index] = [tuple(k.co) for k in fc.keyframe_points] if fc else []
                            
                            if vbm.cache_actions:
                                src['VBM_CHECKSUM'] = checksum
                                src['VBM_CURVEDATA'] = curvedata
                        
                        # Assemble ..............................................................................
                        bonecurves = src['VBM_CURVEDATA']
                        bonemask = deformorder
                        if src.vbm.deform_mask:
                            bonemask = [x.name for x in src.vbm.deform_mask if x.enabled]
                        print(src.name)
                        def CurveBytes(curvegroup):
                            hits = 0
                            outchunk = b''
                            for bname, channels in curvegroup.items():
                                if bname in bonemask and sum([len(k) for k in channels]) > 0:
                                    outchunk += PackString(bname.replace("DEF-", ""))     # Curve name
                                    outchunk += Pack('I', len(channels)) # Channel Count
                                    for keyframes in channels: # For each indexed transform
                                        outchunk += Pack('I', len(keyframes))    #Size
                                        outchunk += b''.join([Pack('f', k[0]-src.frame_start) for k in keyframes])  # Keyframes
                                        outchunk += b''.join([Pack('f', k[1]) for k in keyframes])  # Values
                                    hits += 1
                            return (outchunk, hits)
                        
                        bonechunk, bonecurvecount = CurveBytes(bonecurves)
                        numkeyframes = len([k[0] for bname,channels in bonecurves.items() for keyframes in channels for k in keyframes])
                        animationentries.append({
                            'data': bonechunk,
                            'action': src,
                            'numbonecurves': bonecurvecount,
                            'numkeyframes': numkeyframes,
                        })
                    
                    bpy.ops.object.mode_set(mode='OBJECT')
                    [pb.constraints.remove(c) for pb in proxy.pose.bones for c in pb.constraints]
                    benchmark['anim_bake'] = time.time()-benchmark['anim_bake']
                    rig.animation_data.action = preaction
                
                benchmark['anim_file'] = time.time()
                for anim in animationentries:
                    outanimation = b''
                    action = anim['action']
                    outanimation += PackString(action.name) # String
                    outanimation += Pack('I', action.use_cyclic) # Flags
                    outanimation += Pack('I', int(action.frame_end-action.frame_start)) # Duration
                    outanimation += Pack('I', anim['numbonecurves']) # Num Curves
                    outanimation += Pack('I', anim['numkeyframes']) # Num Keyframes
                    outanimation += anim['data'] # Data
                    resources['animations'].append(outanimation)
                benchmark['anim_file'] = time.time()-benchmark['anim_file']
        
        Cleanup()
        
        # Output ====================================================================================
        def ResItem(restypename, resversion, resdata): # [ 'RES' + version + numbytes + data ]
            print("Res:", (restypename, resversion), "%8d / %8d" % (len(resdata), 0xffffff))
            return b''.join([Pack('B',ord(x)) for x in restypename]) + Pack('B', int(resversion)) + Pack('I', len(resdata)) + resdata
        
        benchmark['output'] = time.time()
        outfile = b''
        outfile += b'VBM' + Pack('B', 4)
        
        numresources = len(resources['meshes']) + len(resources['meshes']) + len(resources['meshes'])
        outfile += Pack('I', numresources)
        for data in resources['textures']:
            outfile += ResItem('TEX', 0, data)
        for data in resources['meshes']:
            outfile += ResItem('MSH', 0, data)
        for data in resources['skeletons']:
            outfile += ResItem('SKE', 0, data)
        for data in resources['animations']:
            outfile += ResItem('ANI', 0, data)
        
        filelength = [len(outfile), 0]
        outfile = zlib.compress(outfile, compression_level)
        filelength[1] = len(outfile)
        
        f = open(vbm.ToFullPath(filepath), 'wb')
        f.write(outfile)
        f.close()
        
        print("Exported to \"{}\"  ({:4.2f} KB -> {:4.2f} KB)".format(filepath, filelength[0]/1024, filelength[1]/1024))
        benchmark['output'] = time.time()-benchmark['output']
        
        # Restore ===================================================================================
        context.view_layer.objects.active = bpy.data.objects.get(lastactive, None)
        if context.object:
            context.object.select_set(True)
        for rig in sourcerigs:
            vbm.EvaluateDeformOrder(rig)
        
        benchmark['export'] = time.time()-benchmark['export']
        
        # Benckmarking ........................................................................
        if bpy.data.texts.get('benchmark'):
            bpy.data.texts['benchmark'].from_string("{%s}\n"%"".join(["'%s': %.2f, "%(k,v) for k,v in benchmark.items()]) + bpy.data.texts['benchmark'].as_string())
classlist.append(VBM_PG_Master)

'# =========================================================================================================================='
'# GPU'
'# =========================================================================================================================='

shader = gpu.shader.from_builtin('UNIFORM_COLOR')
ringverts = [(x,y) for j in range(0, VBM_SWINGCIRCLEPRECISION) for i in [j,j+1] for a in [(i/VBM_SWINGCIRCLEPRECISION)*PI*2] for x,y in [(cos(a), sin(a))]]
batch_ring_y = batch_for_shader(shader, 'LINES', {"pos": [(x,0,y) for x,y in ringverts] + [(.1,1,0), (0,1.2,0), (0,1.2,0), (-.1,1,0)] })
batch_ring_y1 = batch_for_shader(shader, 'LINES', {"pos": [(x,1,y) for x,y in ringverts] + [(.1,1,0), (0,1.2,0), (0,1.2,0), (-.1,1,0)] })
batch_swing_limit_x = batch_for_shader(shader, 'LINES', {"pos": [(0,0,0), (0,1,0), (0,1,0), (0,cos(VBM_SWINGLIMITSEP),sin(VBM_SWINGLIMITSEP)), (0,cos(VBM_SWINGLIMITSEP),sin(VBM_SWINGLIMITSEP)), (0,0,0)] })
batch_swing_limit_z = batch_for_shader(shader, 'LINES', {"pos": [(0,0,0), (0,1,0), (0,1,0), (sin(VBM_SWINGLIMITSEP),cos(VBM_SWINGLIMITSEP),0), (sin(VBM_SWINGLIMITSEP),cos(VBM_SWINGLIMITSEP),0), (0,0,0)] })
batch_sphere = batch_for_shader(shader, 'LINES', {"pos": [(x,y,0) for x,y in ringverts] + [(x,0,y) for x,y in ringverts] + [(0,x,y) for x,y in ringverts]})
batch_semi = batch_for_shader(shader, 'LINES', {"pos": [(x,0,y) for x,y in ringverts] + [(0,y,x) for x,y in ringverts[:len(ringverts)//2]] + [(x,y,0) for x,y in ringverts[:len(ringverts)//2]]})
batch_shell = batch_for_shader(shader, 'LINES', {"pos": [(1,0,0),(1,1,0), (-1,0,0),(-1,1,0), (0,0,1),(0,1,1), (0,0,-1),(0,1,-1)]})
batch_cone = batch_for_shader(shader, 'TRIS', {"pos": [
    (-0.92,1.00,0.38),(-0.71,1.00,0.71),(0.00,0.00,0.00),
    (-0.92,1.00,0.38),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (0.92,1.00,-0.38),(0.71,1.00,-0.71),(0.00,0.00,0.00),
    (0.92,1.00,-0.38),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (-1.00,1.00,-0.00),(-0.92,1.00,0.38),(0.00,0.00,0.00),
    (-1.00,1.00,-0.00),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (1.00,1.00,-0.00),(0.92,1.00,-0.38),(0.00,0.00,0.00),
    (1.00,1.00,-0.00),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (-0.92,1.00,-0.38),(-1.00,1.00,-0.00),(0.00,0.00,0.00),
    (-0.92,1.00,-0.38),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (0.92,1.00,0.38),(1.00,1.00,-0.00),(0.00,0.00,0.00),
    (0.92,1.00,0.38),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (-0.71,1.00,-0.71),(-0.92,1.00,-0.38),(0.00,0.00,0.00),
    (-0.71,1.00,-0.71),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (0.71,1.00,0.71),(0.92,1.00,0.38),(0.00,0.00,0.00),
    (0.71,1.00,0.71),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (-0.38,1.00,-0.92),(-0.71,1.00,-0.71),(0.00,0.00,0.00),
    (-0.38,1.00,-0.92),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (0.38,1.00,0.92),(0.71,1.00,0.71),(0.00,0.00,0.00),
    (0.38,1.00,0.92),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (0.00,1.00,-1.00),(-0.38,1.00,-0.92),(0.00,0.00,0.00),
    (0.00,1.00,-1.00),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (-0.38,1.00,0.92),(0.00,1.00,1.00),(0.00,0.00,0.00),
    (-0.38,1.00,0.92),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (0.00,1.00,1.00),(0.38,1.00,0.92),(0.00,0.00,0.00),
    (0.00,1.00,1.00),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (0.38,1.00,-0.92),(0.00,1.00,-1.00),(0.00,0.00,0.00),
    (0.38,1.00,-0.92),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (-0.71,1.00,0.71),(-0.38,1.00,0.92),(0.00,0.00,0.00),
    (-0.71,1.00,0.71),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (0.71,1.00,-0.71),(0.38,1.00,-0.92),(0.00,0.00,0.00),
    (0.71,1.00,-0.71),(0.00,0.00,0.00),(0.00,0.00,0.00),
    (0.00,1.00,1.00),(-0.38,1.00,0.92),(-0.71,1.00,0.71),
    (-0.71,1.00,0.71),(-0.92,1.00,0.38),(-1.00,1.00,-0.00),
    (-1.00,1.00,-0.00),(-0.92,1.00,-0.38),(-0.71,1.00,-0.71),
    (-0.71,1.00,-0.71),(-0.38,1.00,-0.92),(0.00,1.00,-1.00),
    (0.00,1.00,-1.00),(0.38,1.00,-0.92),(0.71,1.00,-0.71),
    (0.71,1.00,-0.71),(0.92,1.00,-0.38),(1.00,1.00,-0.00),
    (1.00,1.00,-0.00),(0.92,1.00,0.38),(0.71,1.00,0.71),
    (0.71,1.00,0.71),(0.38,1.00,0.92),(0.00,1.00,1.00),
    (0.00,1.00,1.00),(-0.71,1.00,0.71),(-1.00,1.00,-0.00),
    (-1.00,1.00,-0.00),(-0.71,1.00,-0.71),(0.00,1.00,-1.00),
    (0.00,1.00,-1.00),(0.71,1.00,-0.71),(1.00,1.00,-0.00),
    (1.00,1.00,-0.00),(0.71,1.00,0.71),(0.00,1.00,1.00),
    (0.00,1.00,1.00),(-1.00,1.00,-0.00),(0.00,1.00,-1.00),
    (0.00,1.00,-1.00),(1.00,1.00,-0.00),(0.00,1.00,1.00)
]})

VBM_GPUSWING_HDLKEY = int(time.time())
def vbm_draw_gpu():
    context = bpy.context
    if not getattr(context.scene, 'vbm', None):
        return
    vbm = context.scene.vbm
    
    if vbm.get('VBM_GPUSWING_HDLKEY', 0) < VBM_GPUSWING_HDLKEY:
        vbm['VBM_GPUSWING_HDLKEY'] = VBM_GPUSWING_HDLKEY
        print("> Updating handle key...")
    if vbm.get('VBM_GPUSWING_HDLKEY', 0) != VBM_GPUSWING_HDLKEY:
        return
    
    if not context.space_data.overlay.show_overlays:
        return
    
    obj = context.active_object
    rig = (obj if obj.type=='ARMATURE' else obj.find_armature()) if obj else None
    rig = rig if rig and not rig.hide_get() else None
    
    if obj and rig and obj.mode in ('POSE', 'OBJECT'):
        if not getattr(rig, 'vbm', None):
            return

        if not rig.vbm.deform_mask:
            return
        
        r = context.region_data
        viewpos = r.view_location + (r.view_rotation.to_matrix() @ Vector((0,0,-1))) * r.view_distance
        
        mat4axis = (Matrix.Rotation(PI/2, 4, 'Z'), Matrix.Rotation(PI/2, 4, 'Y'), Matrix.Rotation(PI/2, 4, 'X'))
        VBM_COLOR_SWINGAXIS = (Vector((1,0,.5,0.5)), Vector((.5,1,0,0.5)), Vector((0,.5,1,0.5)))
        VBM_COLOR_SWINGLIMIT = ( Vector((.5, .4, .4, 0.1)), Vector((.4, .4, .5, 0.1)) )
        VBM_COLOR_SWINGCONE = Vector((.5, .5, 1, 0.01))
        VBM_COLOR_COLLIDER = Vector((1, .7, .4, 1))
        
        axisentries = []    # [ (matrix, swing) ]
        limitentries = []   # [ (matrix, swing) ]
        coneentries = []   # [ (matrix, swing) ]
        colliderentries = []   # [ (matrix, collider) ]
        
        if VBM_BLENDER_4_0:
            use_solo = 1
            visible = [pb.name for pb in rig.pose.bones if not pb.bone.hide and sum([c.is_visible if use_solo else c.is_visible for c in pb.bone.collections])]
        else:
            use_solo = sum([c.is_solo for c in rig.data.collections]) > 0
            visible = [pb.name for pb in rig.pose.bones if not pb.bone.hide and sum([c.is_solo if use_solo else c.is_visible for c in pb.bone.collections])]
        
        visible += ['DEF-'+x for x in visible]
        vbmskeleton = rig.vbm
        deformmap = rig.get('DEFORM_MAPRAW', {})
        swingchains = []
        colliderchains = []
        DeformChain = lambda chain: ([chain.append(bname) for bname,pname in deformmap.items() if pname in chain], chain)[-1]
        
        # Parse Chains ..............................................................................
        for pb in rig.pose.bones:
            if pb.bone.use_deform:
                swinglabel = vbmskeleton.swing_bones.get(pb.name, "")
                swing = vbmskeleton.deform_mask.get(swinglabel.name, None).swing if swinglabel else None
                if swing:
                    if swing.is_chain:
                        swingchains.append(DeformChain([pb.name]))
                
                colliderlabel = vbmskeleton.collider_bones.get(pb.name, "")
                collider = vbmskeleton.deform_mask.get(colliderlabel.name, None).collider if colliderlabel else None
                if collider:
                    if collider.is_chain:
                        chain = [pb.name]
                        [chain.append(bname) for bname,pname in deformmap.items() if pname in chain]
                        colliderchains.append(chain)
        
        # Parse Bones ..............................................................................
        for pb in rig.pose.bones:
            if pb.bone.use_deform:
                deform = vbmskeleton.deform_mask[pb.name].enabled
                if deform:
                    # Swing
                    if vbm.show_bone_swing and (vbm.show_bone_swing_hidden or pb.name in visible):
                        swinglabel = vbmskeleton.swing_bones.get(pb.name, "")
                        swing = vbmskeleton.deform_mask.get(swinglabel.name, None).swing if swinglabel else None
                        if not swing:
                            for chain in swingchains[::-1]:
                                if pb.name in chain:
                                    swing = vbmskeleton.deform_mask.get(chain[0]).swing
                                    break
                        if swing:
                            if vbm.show_bone_swing_axis:
                                axisentries.append( (pb.matrix, swing) )
                            if vbm.show_bone_swing_limits:
                                limitentries.append( (pb.matrix, swing) )
                            if vbm.show_bone_swing_cones:
                                coneentries.append( (pb.matrix, swing, pb.bone.length) )
                    
                    # Collider
                    if vbm.show_bone_colliders and (vbm.show_bone_collider_hidden or pb.name in visible):
                        colliderlabel = vbmskeleton.collider_bones.get(pb.name, "")
                        collider = vbmskeleton.deform_mask.get(colliderlabel.name, None).collider if colliderlabel else None
                        if not collider:
                            for chain in colliderchains:
                                if pb.name in chain:
                                    collider = vbmskeleton.deform_mask.get(chain[0]).collider
                                    break
                        if collider:
                            colliderentries.append( (pb.matrix, collider) )
        
        # Render ..................................................................................
        gpu.matrix.load_projection_matrix(bpy.context.region_data.perspective_matrix)
        
        # Swing Cones
        divPI_4 = 1/(PI*4)
        shader.uniform_float("color", VBM_COLOR_SWINGCONE)
        for matrix, swing, length in coneentries:
            xmid = (swing.angle_min_x+swing.angle_max_x) * 0.5
            zmid = (swing.angle_max_z+swing.angle_min_z) * 0.5
            xscale = (swing.angle_max_x-swing.angle_min_x) * divPI_4
            zscale = (swing.angle_max_z-swing.angle_min_z) * divPI_4
            gpu.matrix.load_matrix(matrix @ Matrix.LocRotScale(None, mathutils.Euler((xmid,0,zmid)), (1,1,1)) @ Matrix.LocRotScale(None, None, (zscale,length,xscale)) )
            batch_cone.draw(shader)
        shader.uniform_float("color", VBM_COLOR_SWINGCONE*2.0)
        for matrix, swing, length in coneentries:
            xmid = (swing.angle_max_x+swing.angle_min_x) * 0.5
            zmid = (swing.angle_max_z+swing.angle_min_z) * 0.5
            xscale = (swing.angle_max_x-swing.angle_min_x) * divPI_4
            zscale = (swing.angle_max_z-swing.angle_min_z) * divPI_4
            gpu.matrix.load_matrix(matrix @ Matrix.LocRotScale(None, mathutils.Euler((xmid,0,zmid)), (1,1,1)) @ Matrix.LocRotScale(None, None, (zscale,length,xscale)) )
            batch_ring_y1.draw(shader)
        # Swing Limits
        shader.uniform_float("color", VBM_COLOR_SWINGLIMIT[0])
        for matrix, swing in limitentries:
            for i in range(int(swing.angle_min_x*VBM_SWINGLIMITN), int(swing.angle_max_x*VBM_SWINGLIMITN)+1):
                gpu.matrix.load_matrix(matrix @ Matrix.Rotation(1*i/VBM_SWINGLIMITN, 4, 'X') @ Matrix.Scale(0.04, 4))
                batch_swing_limit_x.draw(shader)
        shader.uniform_float("color", VBM_COLOR_SWINGLIMIT[1])
        for matrix, swing in limitentries:
            for i in range(int(swing.angle_min_z*VBM_SWINGLIMITN), int(swing.angle_max_z*VBM_SWINGLIMITN)+1):
                gpu.matrix.load_matrix(matrix @ Matrix.Rotation(1*i/VBM_SWINGLIMITN, 4, 'Z') @ Matrix.Scale(0.04, 4))
                batch_swing_limit_z.draw(shader)
        # Swing Axes
        for i in (0,1,2):
            shader.uniform_float("color", VBM_COLOR_SWINGAXIS[i])
            for matrix, swing in axisentries:
                scale = (matrix.decompose()[0] - viewpos).length * 0.02
                gpu.matrix.load_matrix(matrix @ mat4axis[i] @ Matrix.Scale(scale, 4))
                batch_ring_y.draw(shader)
        
        # Colliders
        shader.uniform_float("color", VBM_COLOR_COLLIDER)
        for matrix, collider in colliderentries:
            matscale = Matrix.Scale(collider.radius, 4)
            if collider.length <= 0.01:
                gpu.matrix.load_matrix(matrix @ matscale)
                batch_sphere.draw(shader)
            else:
                gpu.matrix.load_matrix(matrix @ matscale @ Matrix.Rotation(PI, 4, 'X'))
                batch_semi.draw(shader)
                gpu.matrix.load_matrix(matrix @ matscale @ Matrix.Translation((0,collider.length,0)))
                batch_semi.draw(shader)
                gpu.matrix.load_matrix(matrix @ matscale @ Matrix.Scale(collider.length, 4, (0,1,0)))
                batch_shell.draw(shader)
        
        gpu.matrix.load_matrix(Matrix.Identity(4)) # Reset matrix for Gizmo drawing

'# =========================================================================================================================='
'# REGISTER'
'# =========================================================================================================================='

VBM_HDL_DrawGpu = None
def register():
    [bpy.utils.register_class(c) for c in classlist]
    bpy.types.Scene.vbm = bpy.props.PointerProperty(type=VBM_PG_Master)
    bpy.types.Material.vbm = bpy.props.PointerProperty(type=VBM_PG_Material)
    bpy.types.Object.vbm = bpy.props.PointerProperty(type=VBM_PG_SkeletonMask, poll=lambda s,c: s.type=='ARMATURE')
    bpy.types.Action.vbm = bpy.props.PointerProperty(type=VBM_PG_SkeletonMask)

    bpy.types.SpaceView3D.draw_handler_add(vbm_draw_gpu, (), 'WINDOW', 'POST_VIEW')
    print(VBM_GPUSWING_HDLKEY)

def unregister():
    [bpy.utils.unregister_class(c) for c in classlist[::-1]]
    VBM_GPUSWING_HDLKEY = 1
    print(VBM_GPUSWING_HDLKEY)

if __name__ == "__main__":
    register()
