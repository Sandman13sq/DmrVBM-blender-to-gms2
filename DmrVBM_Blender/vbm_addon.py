import bpy
import os
import numpy as np
import zlib
import time
from mathutils import Vector, Color, Matrix, Euler, Quaternion
from bpy.props import BoolProperty, BoolVectorProperty, IntProperty, IntVectorProperty, FloatProperty, FloatVectorProperty, StringProperty, EnumProperty, PointerProperty, CollectionProperty
from struct import pack as Pack
from struct import unpack as Unpack

PackChars = lambda s: b''.join([Pack('B', ord(c)) for c in s])
PackString = lambda s: b''.join([Pack('B', ord(c)) for c in s]) + Pack('B', 0)
PackVector = lambda k,v: b''.join([Pack(k,x) for x in v])
PackMatrix = lambda m: b''.join([Pack('ffff', *tuple(v)) for v in m.copy().transposed().copy()])

HexString = lambda value,n=8: "".join("0123456789ABCDEF"[(value>>(i*4)) & 0xF] for i in range(0, n))[::-1]

classlist = []

"======================================================================================================"
"CONSTANTS"
"======================================================================================================"

MODEL_NULLINDEX = 255

VBM_FILEEXT = ".vbm"

VBM_LAYERMASKSIZE = 32
VBM_LAYERMASKICON = 'INFO'
VBM_MESHTYPES = ('MESH', 'CURVE')

VBM_EXPORTENABLEDICONS = ('CHECKBOX_DEHLT', 'CHECKBOX_HLT', 'CHECKMARK')

VBM_BONEFLAGS_HIDDEN = (1<<0)
VBM_BONEFLAGS_SWINGBONE = (1<<1)
VBM_BONEFLAGS_HASPROPS = (1<<2)

VBM_MATERIALFLAGS_TRANSPARENT = (1<<0)

VBM_TEXTUREFLAG_FILTERLINEAR = (1<<1)
VBM_TEXTUREFLAG_EXTEND = (1<<2)

VBM_ANIMATIONFLAGS_CURVENAMES = (1<<0)

VFORMATDATA = (     # (name, size, space, icon)
    ('POS', 3, 12, 'EMPTY_ARROWS'),
    ('NOR', 3, 12, 'NORMALS_VERTEX'),
    ('TAN', 3, 12, 'NORMALS_VERTEX_FACE'),
    ('BTN', 3, 12, 'MOD_NORMALEDIT'),
    ('COL', 4,  4, 'GROUP_VCOL'),
    ('UVS', 2,  8, 'UV'),
    ('UV2', 2,  8, 'GROUP_UVS'),
    ('BON', 4, 16, 'BONE_DATA'),
    ('WEI', 4, 16, 'MOD_VERTEX_WEIGHT'),
    ('GRO', 4,  4, 'GROUP_VERTEX'),
)

VFORMAT_NAME = [x[0] for x in VFORMATDATA]
VFORMAT_ELEMENTS = [x[1] for x in VFORMATDATA]
VFORMAT_INDEX = {k: i for i,k in enumerate(VFORMAT_NAME)}
VFORMAT_SPACE = [x[2] for x in VFORMATDATA]
VFORMAT_ICON = [x[3] for x in VFORMATDATA]

VFORMAT_DEFAULTMASK = sum([
    ((1<<i) * (VFORMAT_NAME[i] in 'POS COL UVS'.split())) | ((1<<(i+16)) * (VFORMAT_NAME[i] in ['COL']))
    for i in range(0,10)
])

Items_Framerate = tuple([ (str(i),str(i),str(i), 'NONE', i) for i in range(1,61) if (60/i)==float(60//i) ])
Items_LayermaskSize = tuple([ (str(i),str(i),str(i), 'NONE', i) for i in (8,16,32) ])

"======================================================================================================"
"FUNCTIONS"
"======================================================================================================"

def CalcStride(format_mask):
    stride = 0
    for i in range(0, 16):
        if format_mask & (1<<i):
            is_bytes = (format_mask & (1<<(i+16))) != 0
            stride += (4) if is_bytes else (VFORMAT_ELEMENTS[i] * 4)
    return stride

def ActiveCollection():
    return bpy.context.collection

def CollectionRig(collection=None):
    if not collection:
        collection=ActiveCollection()
    return ([x for x in collection.all_objects if x.type=='ARMATURE' and x.children]+[None])[0]

def FixName(name):
    return "".join([x if x.lower() in "qwertyuiopasdfghjklzxcvbnm1234567890" else "_" for x in name.replace('DEF-', "")])

def ValidName(name):
    return name[0].lower() in "qwertyuiopasdfghjklzxcvbnm1234567890" and (name[:4] != 'WGTS')

def MaskVectorStr(maskboolvector):
    return "0b"+"".join(["01"[x] for i,x in enumerate(maskboolvector[:int(bpy.context.scene.vbm.layermask_display_size)])])

LayerCollections = lambda c, outdict: (outdict.update({c.name: c}), [LayerCollections(child, outdict) for child in c.children], outdict)[-1] 
LayerCollection = lambda c: LayerCollections(bpy.context.view_layer.layer_collection, {})[c.name]
def SelectCollection(collection):
    bpy.context.view_layer.active_layer_collection = LayerCollections(bpy.context.view_layer.layer_collection, {})[collection.name]

def FileWrite(outbin, filepath):
    outcompressed = zlib.compress(outbin)
    print("> File: \"%s\" (%2.2f KB)" % (filepath, len(outbin)/1024))
    f = open(os.path.abspath(bpy.path.abspath(filepath)), 'wb')
    f.write(outbin)
    f.close()
    
def FileWriteCompressed(outbin, filepath):
    outcompressed = zlib.compress(outbin)
    print("> File: \"%s\" (%2.2f KB -> %2.2f KB)" % (filepath, len(outbin)/1024, len(outcompressed)/1024))
    f = open(os.path.abspath(bpy.path.abspath(filepath)), 'wb')
    f.write(outcompressed)
    f.close()
    
# ..........................................................................
def EvaluateDeformOrder(skeleton_object):
    if not skeleton_object:
        return ([], {}, {})
    
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
    
    # Calculate order based on parents
    deformorder = []
    DeformWalk = lambda bname: (deformorder.append(bname), [DeformWalk(child) for child in [k for k,p in list(deformmap.items()) if p==bname]])
    [DeformWalk(bname) for bname,p in deformmap.items() if not p]
    
    # Sort by depth to minimize parent switches
    BoneDepth = lambda bname, deformmap: (1+BoneDepth(deformmap[bname], deformmap)) if deformmap[bname] else 0
    deformlist = list(deformorder)
    deformlist.sort(key=lambda bname: BoneDepth(bname, deformmap))
    
    skeleton_object.vbm['DEFORM_MAP'] = {bname: (deformmap[bname] if deformmap.get(bname, None) else None) for bname in deformorder} # {bonename: parentname}
    skeleton_object.vbm['DEFORM_LIST'] = deformlist   # [0, first_bone, second_bone, ...]
    skeleton_object.vbm['DEFORM_ROUTE'] = {bname: bname for bname in deformorder}    # {sourcename: bonename}
    return (list(skeleton_object.vbm['DEFORM_LIST']), skeleton_object.vbm['DEFORM_MAP'], skeleton_object.vbm['DEFORM_ROUTE'])

# .....................................................................
def VBM_TexturePadding(image):
    # Modified image filtering code of IMB_filter_extend() from Blender source:
    # https://github.com/blender/blender/blob/main/source/blender/imbuf/intern/filter.cc#L200
    save = False
    
    exec_time = time.time_ns()
    w,h = image.size
    n = w*h
    iterations = max(w//8, h//8)
    
    dstpixels = np.frombuffer( ((255.0*np.array(tuple(image.pixels), dtype=np.float32)).astype(np.uint8)).tobytes(), dtype=np.uint32)
    srcpixels = []
    assigned = np.array([(x>>24) >= 255 and (x&0x00FFFFFF) != 0 for x in dstpixels])
    tmp = 0
    
    for r in range(0, iterations):
        srcpixels = dstpixels
        dstpixels = np.array(srcpixels)
        index = 0
        for index in range(0, n):
            if not assigned[index]:
                x = index % w
                y = index // w
                # Check if adjacent pixels have been assigned
                if (
                    (x-1 >=0 and assigned[y*w+(x-1)]) or
                    (x+1 < w and assigned[y*w+(x+1)]) or
                    (y-1 >=0 and assigned[(y-1)*w+x]) or
                    (y+1 < h and assigned[(y+1)*w+x])
                ):
                    # Test around active pixel
                    for i,j in ( (-1,0), (1,0), (0,-1), (0,1) ):
                        tmpindex = (y+j)*w+(x+i)
                        if (x+i >= 0) and (x+i < w) and (y+j >= 0) and (y+j < h) and assigned[tmpindex]:
                            tmp = srcpixels[tmpindex]
                    if tmp != 0:
                        dstpixels[index] = tmp
                        assigned[index] = True
                        tmp = 0
    
    image.pixels = np.frombuffer(np.array(dstpixels, dtype=np.uint32).tobytes(), dtype=np.uint8).astype(np.float32)/255.0
    
    if save:
        if image.packed_file:
            image.pack()
        elif image.filepath:
            image.save()

"======================================================================================================"
"STRUCTS"
"======================================================================================================"

class VBM_PG_Label(bpy.types.PropertyGroup):
    pass
classlist.append(VBM_PG_Label)

class VBM_PG_CollectionItem(bpy.types.PropertyGroup):
    collection: PointerProperty(type=bpy.types.Collection, options=set())
    depth: IntProperty(min=0, default=0, options=set())
classlist.append(VBM_PG_CollectionItem)

class VBM_PG_ActionItem(bpy.types.PropertyGroup):
    action: PointerProperty(type=bpy.types.Action)
    export_enabled: BoolProperty(name="Export Enabled", default=1, options=set(), description="Include action on export")
classlist.append(VBM_PG_ActionItem)

# ---------------------------------------------------------------------------------------------------------
class VBM_PG_Image(bpy.types.PropertyGroup):
    pass
classlist.append(VBM_PG_Image)

class VBM_PG_Material(bpy.types.PropertyGroup):
    def get_shader(self):
        return self.shader if self.shader else bpy.context.scene.vbm.shader_default
    shader: StringProperty(default="", description="Name of shader asset")
    transparent: BoolProperty(default=False, options=set(), description="Sets transparency flag on export")
classlist.append(VBM_PG_Material)

class VBM_PG_MaterialOverride(bpy.types.PropertyGroup):
    material: PointerProperty(type=bpy.types.Material, description="Material to replace")
    override: PointerProperty(type=bpy.types.Material, description="Material to overwrite with")
classlist.append(VBM_PG_MaterialOverride)

class VBM_PG_Action(bpy.types.PropertyGroup):
    def get_action(self):
        return [x for x in bpy.data.actions if x.vbm==self][0]
    def update_action(self, context):
        if self.get('MUTEX', 0):
            return
        self['MUTEX'] = 1
        action = self.get_action()
        frame_step = int(self.frame_step)
        action.frame_start = self.frame_start
        if self.frame_end:
            action.frame_end = self.frame_end
            
            rig = CollectionRig()
            if rig and rig.animation_data.action == action:
                context.scene.frame_start = int(action.frame_start)
                context.scene.frame_end = int(action.frame_end)
        else:
            self.frame_end = int(action.frame_range[1])
        self['MUTEX'] = 0
    
    frame_start: IntProperty(min=0, update=update_action)
    frame_end: IntProperty(min=0, update=update_action)
    frame_step: EnumProperty(items=Items_Framerate, default='1', update=update_action)
    
    layermask: BoolVectorProperty(
        name="Layer Mask", 
        size=VBM_LAYERMASKSIZE, 
        default=[True for i in range(0,VBM_LAYERMASKSIZE)],
        description="Bone curves in layer mask will be exported. Use 'Swing Bones' tab to set bone layer masks."
    )
classlist.append(VBM_PG_Action)

class VBM_PG_Object(bpy.types.PropertyGroup):
    export_enabled: BoolProperty(name="Export Enabled", default=True)
    script_id: StringProperty(name="Script ID", default="")
    is_collision: BoolProperty(name="Is Collision", default=False, options=set(), description="Export object as Prism type in file")
    layermask: BoolVectorProperty(name="Layer Mask", size=VBM_LAYERMASKSIZE, default=[i==0 for i in range(0,VBM_LAYERMASKSIZE)])
classlist.append(VBM_PG_Object)

class VBM_PG_Swingbone(bpy.types.PropertyGroup):
    name: StringProperty(default="s_bone")
    enabled: BoolProperty(name="Enabled", default=1)
    stiffness: FloatProperty(name="Stiffness", default=0.1, min=0.0, max=1.0, subtype='FACTOR', description="Speed that bone approaches goal")
    damping: FloatProperty(name="Damping", default=0.2, min=0.0, max=1.0, subtype='FACTOR', description="Controls particle distance from goal")
    limit: FloatProperty(name="Limit", default=0.8, min=0.0, max=1.0, subtype='FACTOR', description="Limits maximum rotation")
    force_strength: FloatProperty(name="Force Strength", default=1.0, min=0.0, max=1.0, subtype='FACTOR', description="Amount of influence by forces such as gravity")
    
    bones: CollectionProperty(name="Bones", type=VBM_PG_Label)
    bone_index: IntProperty(name="Bone Index", min=0)
    layermask: BoolVectorProperty(name="Layer Mask", size=VBM_LAYERMASKSIZE, default=[i==0 for i in range(0,VBM_LAYERMASKSIZE)])
classlist.append(VBM_PG_Swingbone)

# -----------------------------------------------------------------------------------------------------
class VBM_PG_Collection(bpy.types.PropertyGroup):
    def export(self):
        collection = ActiveCollection()
        hits = Walk_ExportCollection(self.get_collection())
        SelectCollection(collection)
        return hits
    
    def refresh(self):
        sccollection = self.get_collection()
        [c.vbm.children.remove(0) for c in [sccollection]+list(sccollection.children_recursive) for i in range(0,len(c.vbm.children))]
        
        def VBMCollection_WalkRefresh(root, collection, depth):
            if root != collection:
                item = root.vbm.children.add()
                item.collection = collection
                item.depth = depth-1
                
            for c in list(collection.children):
                c.vbm.refresh()
                VBMCollection_WalkRefresh(root, c, depth+1)
        VBMCollection_WalkRefresh(sccollection, sccollection, 0)
    
    def get_collection(self):
        return ([x for x in bpy.data.collections if x.vbm==self]+[bpy.context.scene.collection])[0]
    def get_name(self):
        return self.name if self.name else self.get_collection().name
    
    def select_action(self, context):
        if self.actions:
            rig = CollectionRig(self.get_collection())
            if rig:
                action = self.actions[self.action_index].action
                rig.animation_data.action = action
                rig.animation_data.action_slot = action.slots[0]
                action.vbm.update_action(context)
    def update_pose_action(self, context):
        if self.action_pose:
            rig = CollectionRig(self.get_collection())
            if rig:
                rig.animation_data.action = self.action_pose
                rig.animation_data.action_slot = self.action_pose.slots[0]
    
    def sort_actions(self):
        order = [x.action for x in self.actions]
        order.sort(key=lambda x: x.name)
        [self.actions.move([x.action for x in self.actions].index(action), 0) for action in order[::-1]]
    
    def fix_materials(self):
        collection = self.get_collection()
        materials = list(set([mtl for obj in collection.all_objects if obj.type=='MESH' for mtl in obj.data.materials if mtl]))
        for mtl in materials:
            mtl.use_backface_culling = True
            mtl.use_backface_culling_shadow = True
            outputnode = ([nd for nd in mtl.node_tree.nodes if nd.bl_idname=='ShaderNodeOutputMaterial'])[0]
            offset = tuple(outputnode.location)
            for nd in mtl.node_tree.nodes:
                nd.location[0] -= offset[0]
                nd.location[1] -= offset[1]
            imagenodes = [nd for nd in mtl.node_tree.nodes if nd.bl_idname=='ShaderNodeTexImage' and nd.image and nd.image]
            if len(imagenodes) == 1:
                imagenodes[0].name = "Image Texture"
    
    def get_materials(self):
        collection = self.get_collection()
        materials = list(set([mtl for obj in collection.all_objects if obj.type=='MESH' for mtl in obj.data.materials if mtl]))
        materials += [mtl for item in self.material_overrides for mtl in (item.material, item.override) if mtl]
        return list(set(materials))
    
    def get_material_override(self, material):
        for item in self.material_overrides:
            if item.material == material:
                return item.override
        return material
    
    def get_bone_layermask(self, bonename):
        layervector = self.bone_layermask_default
        for swing in self.swing_bones:
            if bonename in list(swing.bones.keys()):
                layervector = swing.layermask
        return int( sum([1<<i for i,x in enumerate(layervector) if x]) )
        
    def get_format(self):
        return self.format if self.format else []
    
    def update_format(self, context):
        if sum(self.format[:16]) == 0:
            format = [0]*32
            collection = self.get_collection()
            format[VFORMAT_INDEX['POS']] = 1
            format[VFORMAT_INDEX['COL']] = 1
            format[VFORMAT_INDEX['COL']+16] = 1
            format[VFORMAT_INDEX['UVS']] = 1
            
            if CollectionRig():
                format[VFORMAT_INDEX['BON']] = 1
                format[VFORMAT_INDEX['BON']+16] = 1
                format[VFORMAT_INDEX['WEI']] = 1
                format[VFORMAT_INDEX['WEI']+16] = 1
            self.format = [x > 0 for x in format]
    format: BoolVectorProperty(name="Vertex Format", size=32, options=set(), default=tuple([((1<<i)&VFORMAT_DEFAULTMASK) != 0 for i in range(0, 32)]), update=update_format)   # [0:15] = Attribute, [16:31] = Is byte
    
    name: StringProperty(default="", options=set())
    enabled: BoolProperty(default=False, name="Export as File")
    object_index: IntProperty(min=0)
    
    actions: CollectionProperty(type=VBM_PG_ActionItem)
    action_index: IntProperty(min=0, update=select_action)
    
    children: CollectionProperty(options={'HIDDEN'}, type=VBM_PG_CollectionItem)
    child_index: IntProperty(min=0)
    
    use_material_names: BoolProperty(name="Use Mtl Names", default=False, description="Append material name to name of object on export")
    merge_meshes: BoolProperty(name="Merge Meshes", default=False, description="Merge meshes with similar names, after truncating name after \".\" character")
    action_pose: PointerProperty(name="Action Pose", type=bpy.types.Action, update=update_pose_action, description="Pose to export mesh with (if skinning attributes are disabled and/or rig is not present)")
    
    color_layer_name: StringProperty(name="VC Layer Name", default="", options=set(), description="Vertex color layer to use on export. Uses 'Color' if empty")
    color_layer_default: FloatVectorProperty(name="VC Layer Default", size=4, default=(1,1,1,1), subtype='COLOR_GAMMA', options=set(), description="Default vertex color if vc layer name is set but not found")
    uv_layer_name: StringProperty(name="UV Layer Name", default="", options=set(), description="UV layer to use on export. Uses 'UVMap' if empty")
    uv_layer_default: FloatVectorProperty(name="UV Layer Default", size=2, default=(1,1), options=set(), description="Default uv value if uv layer name is set but not found")
    
    object_script_pre: PointerProperty(name="Object Pre Script", type=bpy.types.Text, description="Internal python script to run before applying modifiers")
    object_script_post: PointerProperty(name="Object Post Script", type=bpy.types.Text, description="Internal python script to run after applying modifiers")
    
    swing_bones: CollectionProperty(name="Swing Bones", type=VBM_PG_Swingbone, options=set())
    swing_bone_index: IntProperty(min=0, options=set())
    
    material_overrides: CollectionProperty(name="Material Overrides", type=VBM_PG_MaterialOverride, options=set())
    material_override_index: IntProperty(min=0, options=set())
    
    bone_layermask_default: BoolVectorProperty(
        name="Bone Layer Mask Default", 
        size=VBM_LAYERMASKSIZE, 
        default=[i==0 for i in range(0,VBM_LAYERMASKSIZE)], 
        options=set(),
        description="Default layer mask for bones not in a swing bone group"
    )
classlist.append(VBM_PG_Collection)

class VBM_PG_Scene(bpy.types.PropertyGroup):
    def update_datapath(self, context):
        datapath = self.data_path
        if datapath[-1] not in "/\\":
            datapath += "/"
        if datapath != self.data_path:
            self.data_path = datapath
    
    def refresh_collection(self, context):
        collection = context.scene.collection
        checksum = sum([i*ord(c) for i,x in enumerate(collection.children_recursive) for c in x.name])
        
        if checksum != self.get('VBM_CHECKSUM', -1):
            print("> VBM Collection Refresh")
            context.scene.collection.vbm.refresh()
            self['VBM_CHECKSUM'] = checksum
    
    def texture_apply_padding(self, image):
        VBM_TexturePadding(image)
    
    data_path: StringProperty(name="Data Path", default="", subtype='DIR_PATH', update=update_datapath)
    layermask_display_size: EnumProperty(name="Mask Display Size", items=Items_LayermaskSize, default='8', options=set(), description="Number of layer mask bits to display")
    layermask_display_list: BoolProperty(name="Show Layermask in List", default=False, options=set(), description="Show layer masks in item lists that support it")
    shader_default: StringProperty(name="Default Shader", default="DEFAULT", options=set(), description="Default shader name for materials.")
    panel_tab: EnumProperty(default=1, update=refresh_collection, items=tuple([
        ('SCENE', "", "Scnene settings", 'PREFERENCES', 0),
        ('COLLECTION', "CLL", "Collection settings", 'OUTLINER_COLLECTION', 1),
        ('OBJECT', "OBJ", "Collection object settings", 'OBJECT_DATA', 2),
        ('MATERIAL', "MTL", "Material settings", 'MATERIAL_DATA', 3),
        ('ACTION', "ANI", "Action settings", 'ACTION', 4),
    ]))
    express_export: BoolProperty(name="Express Export", default=False)
    compress_model_files: BoolProperty(name="Compress on Export", default=False)
classlist.append(VBM_PG_Scene)

"======================================================================================================"
"OPERATORS"
"======================================================================================================"

class VBM_OT_CollectionClearChecksum(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_clear_checksum', 'Clear Checksum', {'REGISTER', 'UNDO'}
    group: EnumProperty(items=tuple([(x,x,x) for x in 'OBJECT ACTION IMAGE ALL'.split()])) 
    def execute(self, context):
        collection = ActiveCollection()
        hits = 0
        for item in (
            collection.all_objects if self.group == 'OBJECT' else
            [x.action for x in collection.vbm.actions] if self.group == 'ACTION' else
            list(set([nd.image for obj in collection.all_objects if obj.type=='MESH' for mtl in obj.data.materials if mtl for nd in mtl.node_tree.nodes if nd.bl_idname=='ShaderNodeTexImage' and nd.image])) if self.group == 'IMAGE' else
            []
        ):
            hit = 0
            for k in tuple(item.keys())[::-1]:
                if "VBM_" in k:
                    del item[k]
                    hit = 1
            for k in tuple(item.vbm.keys())[::-1]:
                if "VBM_" in k:
                    del item.vbm[k]
            hits += hit
        self.report({'INFO'}, "%d hits" % hits)
        SelectCollection(collection)
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionClearChecksum)

class VBM_OT_CollectionRenameObjects(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.rename_objects', "Rename Objects", {'REGISTER', 'UNDO'}
    def execute(self, context):
        hits = 0
        def WalkRename(collection):
            hits = 0
            collectionname = collection.name
            for obj in collection.objects:
                nodename = obj.name.split("/")[-1]
                while nodename[0] in "!`-_.,|[]:';-=~":
                    nodename = nodename[1:]
                if obj.name[0] in "!`-_.,|[]:';-=~":
                    newname = obj.name[0] + collectionname + "/" + nodename
                else:
                    newname = collectionname + "/" + nodename
                if collection == context.scene.collection:
                    newname = nodename
                    
                if obj.name != newname:
                    obj.name = newname
                    if obj.data:
                        obj.data.name = newname
                    hits += 1
            objects = list(collection.objects)
            objects.sort(key=lambda obj: ("z" if not ValidName(obj.name[0]) else "") + obj.type + obj.name)
            [collection.objects.unlink(obj) for obj in objects]
            [collection.objects.link(obj) for obj in objects]
            
            for c in collection.children:
                hits += WalkRename(c)
            return hits
        collection = ActiveCollection()
        hits = WalkRename(collection)
        self.report({'INFO'}, "Hit(s) %d" % hits)
        SelectCollection(collection)
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionRenameObjects)

class VBM_OT_CollectionMoveObject(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_object_move', 'Move Object', {'REGISTER', 'UNDO'}
    direction: EnumProperty(name="Direction", items=tuple([(x,x,x) for x in 'UP DOWN'.split()]))
    def execute(self, context):
        collection = ActiveCollection()
        objects = list(collection.objects)
        index = collection.vbm.object_index
        if self.direction == 'UP' and index > 0:
            order = [objects[(i-1) if i==index else (i+1) if i==index-1 else i] for i in range(0,len(objects))]
            print([x.name for x in objects])
            print([x.name for x in order])
            [collection.objects.unlink(obj) for obj in objects]
            [collection.objects.link(obj) for obj in order]
            collection.vbm.object_index -= 1
        if self.direction == 'DOWN' and index < len(objects)-1:
            order = [objects[(i+1) if i==index else (i-1) if i==index+1 else i] for i in range(0,len(objects))]
            [collection.objects.unlink(obj) for obj in objects]
            [collection.objects.link(obj) for obj in order]
            collection.vbm.object_index += 1
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionMoveObject)

# ---------------------------------------------------------------------------------------------------------
class VBM_OT_CollectionAddAction(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_add_action', 'Add Action', {'REGISTER', 'UNDO'}
    def execute(self, context):
        collection = ActiveCollection()
        rig = CollectionRig(collection)
        action = rig.animation_data.action
        if action not in [x.action for x in collection.vbm.actions]:
            collection.vbm.actions.add().action = action
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionAddAction)

class VBM_OT_CollectionRemoveAction(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_remove_action', 'Remove Action', {'REGISTER', 'UNDO'}
    def execute(self, context):
        collection = ActiveCollection()
        collection.vbm.actions.remove(collection.vbm.action_index)
        collection.vbm.action_index = max(0, min(collection.vbm.action_index, len(collection.vbm.actions)-1))
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionRemoveAction)

class VBM_OT_CollectionMoveAction(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_action_move', 'Move Action', {'REGISTER', 'UNDO'}
    direction: EnumProperty(name="Direction", items=tuple([(x,x,x) for x in 'UP DOWN'.split()]))
    def execute(self, context):
        collection = ActiveCollection()
        if self.direction == 'UP':
            collection.vbm.actions.move(collection.vbm.action_index, collection.vbm.action_index-1)
            collection.vbm.action_index -= 1
        if self.direction == 'DOWN':
            collection.vbm.actions.move(collection.vbm.action_index, collection.vbm.action_index+1)
            collection.vbm.action_index += 1
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionMoveAction)

class VBM_OT_CollectionActionSort(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_sort', 'Sort Actions', {'REGISTER', 'UNDO'}
    def execute(self, context):
        collection = ActiveCollection()
        collection.vbm.sort_actions()
        SelectCollection(collection)
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionActionSort)

class VBM_OT_CollectionMaterialFix(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_material_fix', 'Fix Materials', {'REGISTER', 'UNDO'}
    def execute(self, context):
        collection = ActiveCollection()
        collection.vbm.fix_materials()
        SelectCollection(collection)
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionMaterialFix)

# -----------------------------------------------------------------------------
class VBM_OT_CollectionAddSwing(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_add_swing', 'Add Swing Bone', {'REGISTER', 'UNDO'}
    def execute(self, context):
        collection = ActiveCollection()
        swing = collection.vbm.swing_bones.add()
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionAddSwing)

class VBM_OT_CollectionAddSwingSelected(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_add_swing_selected', 'Add Selected Bones to Swing', {'REGISTER', 'UNDO'}
    @classmethod
    def poll(self, context):
        return context.active_object and context.active_object.type=='ARMATURE' and context.object.mode == 'POSE'
    
    def execute(self, context):
        collection = ActiveCollection()
        swing = collection.vbm.swing_bones[collection.vbm.swing_bone_index]
        
        rig = CollectionRig(collection)
        bonenames = tuple(rig.data.bones.keys())
        for pb in context.selected_pose_bones:
            bname = pb.name
            if "DEF-"+bname.split("-")[-1] in bonenames:
                bname = "DEF-"+bname.split("-")[-1]
            elif "DEF-"+bname.split("-")[-1].replace("_ik","") in bonenames:
                bname = "DEF-"+bname.split("-")[-1].replace("_ik","")
            elif "DEF-"+bname.split("-")[-1].replace("_fk","") in bonenames:
                bname = "DEF-"+bname.split("-")[-1].replace("_fk","")
            if not ValidName(bname) or bname in list(swing.bones.keys()):
                continue
            b = rig.data.bones[bname]
            if b.use_deform:
                swing.bones.add().name = bname
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionAddSwingSelected)

class VBM_OT_CollectionRemoveSwingBone(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_remove_swing_bone', 'Add Swing Bone', {'REGISTER', 'UNDO'}
    index: IntProperty(name="Index")
    def execute(self, context):
        collection = ActiveCollection()
        swing = collection.vbm.swing_bones[collection.vbm.swing_bone_index]
        swing.bones.remove(self.index)
        swing.bone_index = max(0, min(swing.bone_index, len(swing.bones)-1))
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionRemoveSwingBone)

# -----------------------------------------------------------------------------
class VBM_OT_CollectionMaterialOverrideAdd(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_material_override_add', 'Add Material Override', {'REGISTER', 'UNDO'}
    def execute(self, context):
        collection = ActiveCollection()
        collection.vbm.material_overrides.add()
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionMaterialOverrideAdd)

class VBM_OT_CollectionMaterialOverrideRemove(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_material_override_remove', 'Remove Material Override', {'REGISTER', 'UNDO'}
    def execute(self, context):
        collection = ActiveCollection()
        collection.vbm.material_overrides.remove(collection.vbm.material_override_index)
        collection.vbm.material_override_index = max(0, min(collection.vbm.material_override_index, len(collection.vbm.material_overrides)-1))
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionMaterialOverrideRemove)

# ===================================================================================================
Clean = lambda: [data.remove(x) for data in (bpy.data.meshes, bpy.data.objects, bpy.data.armatures, bpy.data.images, bpy.data.actions) for x in list(data)[::-1] if x.get('TEMP', False)]

def Walk_ExportCollection(collection):
    hits = 0
    if collection.vbm.enabled:
        ExportModel(collection, report=False)
        hits += 1
    for c in collection.children:
        hits += Walk_ExportCollection(c)
    return hits

class VBM_OT_ExportCollection(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.export_collection', 'Export Collection', {'REGISTER', 'UNDO'}
    def execute(self, context):
        collection = ActiveCollection()
        t = time.time_ns()
        hits = collection.vbm.export()
        SelectCollection(collection)
        if hits == 0:
            self.report({'WARNING'}, "> No collections exported")
        else:
            self.report({'INFO'}, "> Export Complete \"%s\" (%d hit(s), %2.2f sec)" % (collection.name, hits, (time.time_ns()-t)/1_000_000_000 ))
        return {'FINISHED'}
classlist.append(VBM_OT_ExportCollection)

class VBM_OT_ExportCollectionAll(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.export_collection_all', 'Export Scene Collections', {'REGISTER', 'UNDO'}
    def execute(self, context):
        t = time.time_ns()
        hits = context.scene.collection.vbm.export()
        if hits == 0:
            self.report({'WARNING'}, "> No collections exported")
        else:
            self.report({'INFO'}, "> Export Complete (%d hits, %2.2f sec)" % (hits, (time.time_ns()-t)/1_000_000_000))
        SelectCollection(context.scene.collection)
        return {'FINISHED'}
classlist.append(VBM_OT_ExportCollectionAll)

# ============================================================================================
class VBM_OT_TexturePadding(bpy.types.Operator):
    bl_idname, bl_label, bl_options = ('vbm.texture_apply_padding', 'VBM Texture Padding', {'REGISTER', 'UNDO'})
    bl_description = "Extend edges of pixels on texture to fill in alpha."
    
    image : bpy.props.StringProperty(name="Image", default="")
    
    def invoke(self, context, event):
        if 1 or self.image == "":
            for a in [a for a in context.screen.areas if (a.type == 'IMAGE_EDITOR' or a.type == 'UV_EDIT') and a.spaces[0].image][:1]:
                self.image = a.spaces[0].image.name
        return context.window_manager.invoke_props_dialog(self)
    
    def draw(self, context):
        self.layout.prop_search(self, 'image', bpy.data, 'images')
    
    def execute(self, context):
        image = bpy.data.images.get(self.image, None)
        if image:
            context.scene.vbm.texture_apply_padding(image)
        return {'FINISHED'}
classlist.append(VBM_OT_TexturePadding)

class VBM_OT_RigClearPose(bpy.types.Operator):
    bl_idname, bl_label, bl_options = ('vbm.rig_clear_pose', 'VBM Rig Clear Pose', {'REGISTER', 'UNDO'})
    bl_description = "Resets transforms of pose bones."
    
    def execute(self, context):
        rig = CollectionRig()
        if rig:
            for pb in rig.pose.bones:
                pb.location = (0,0,0)
                pb.rotation_quaternion = (1,0,0,0)
                pb.rotation_euler = (0,0,0)
                pb.scale = (1,1,1)
        return {'FINISHED'}
classlist.append(VBM_OT_RigClearPose)

"======================================================================================================"
"UILIST"
"======================================================================================================"

class VBM_UL_CollectionChildren(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        collection = item.collection
        if collection:
            numfiles = len([x for x in [collection]+list(collection.children_recursive) if x.vbm.enabled])
            layout = layout.row(align=1)
            layout.prop(collection.vbm, 'enabled', text="", icon=VBM_EXPORTENABLEDICONS[collection.vbm.enabled], emboss=False)
            r = layout.row(align=1)
            r.enabled = numfiles > 0
            
            rr = r.row(align=1)
            rr.scale_x = 0.8
            for i in range(0, item.depth-1):
                rr.label(text="", icon='THREE_DOTS')
            rr.label(text="", icon='TEXT' if collection.vbm.enabled else 'OUTLINER_COLLECTION' if numfiles>0 else 'GROUP')
            
            r.separator()
            r.prop(collection, 'name', text="", emboss=False)
            rr = r.row(align=1)
            rr.alignment = 'RIGHT'
            rr.label(text="%d File(s)" % numfiles)
classlist.append(VBM_UL_CollectionChildren)

# ------------------------------------------------------------------------------------------------
class VBM_UL_CollectionObjects(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        layout = layout.column(align=1)
        obj = item
        layout.enabled = ValidName(obj.name)
        r = layout.row(align=1)
        r.prop(obj.vbm, 'export_enabled', text="", icon=VBM_EXPORTENABLEDICONS[obj.vbm.export_enabled*(2-layout.enabled)], emboss=False)
        icon = 'OUTLINER_OB_GROUP_INSTANCE' if obj.instance_collection else (('OUTLINER_DATA_')+obj.type)
        
        if layout.enabled:
            rr = r.row(align=1)
            rr.prop(obj, 'name', text="", placeholder="(Export Name)", emboss=0, icon=icon)
            rr.active = index==data.vbm.object_index
            
            if obj.type in VBM_MESHTYPES:
                r.separator()
                r.prop(obj.vbm, 'is_collision', text="", icon='PHYSICS')
        else:
            rr = r.row(align=1)
            rr.label(text="", icon='MESH_PLANE')
            rr.scale_x = 0.09
            r.label(text="( %s )"%obj.name, icon=icon)
        
        if obj.type == 'ARMATURE':
            rr = r.row()
            rr.alignment='RIGHT'
            rr.label(text="%d" % len(obj.vbm['DEFORM_LIST'] if obj.vbm.get('DEFORM_LIST',None) else [b for b in obj.data.bones if b.use_deform]), icon='BONE_DATA')
        
        if context.scene.vbm.layermask_display_list:
            r = layout.row(align=1)
            r.alignment='RIGHT'
            r.label
            r.label(text="Mask: " + MaskVectorStr(obj.vbm.layermask))
classlist.append(VBM_UL_CollectionObjects)

# -------------------------------------------------------------------------------------
class VBM_UL_CollectionActions(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        action = item.action
        layout = layout.column(align=1)
        r = layout.row(align=1)
        r.prop(item, 'export_enabled', text="", icon=VBM_EXPORTENABLEDICONS[item.export_enabled], emboss=False)
        rr = r.row(align=1)
        rr.active = item.export_enabled
        rr.scale_x = 1.5
        rr.prop(action, 'name', text="", emboss=False)
        
        rr = r.row(align=1)
        rr.enabled = action.use_frame_range
        rr.label(text="%02d:%02d" % (action.frame_range[0], action.frame_range[1]))
        r.prop(action, 'use_frame_range', text="", icon='PREVIEW_RANGE')
        
        # Extended info
        if context.scene.vbm.layermask_display_list:
            r = layout.row(align=1)
            r = r.row(align=1)
            r.alignment='RIGHT'
            r.label(text="Markers: %d |" % len(action.pose_markers))
            r.label(text="Mask:")
            r.label(text=MaskVectorStr(action.vbm.layermask))
classlist.append(VBM_UL_CollectionActions)

# -------------------------------------------------------------------------------------
class VBM_UL_CollectionSwingbones(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=1)
        r.prop(item, 'enabled', text="", icon='CHECKBOX_HLT' if item.enabled else 'CHECKBOX_DEHLT', emboss=False)
        r.prop(item, 'name', text="", icon='BONE_DATA', emboss=False)
        rr = r.row(align=1)
        rr.alignment = 'RIGHT'
        rr.label(text="%2d Bones" % len(item.bones))
classlist.append(VBM_UL_CollectionSwingbones)

class VBM_UL_CollectionSwingbonesBones(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=1)
        r.label(text=item.name, icon='BONE_DATA')
        r.operator('vbm.collection_remove_swing_bone', text="", icon='X', emboss=False)
classlist.append(VBM_UL_CollectionSwingbonesBones)

# -------------------------------------------------------------------------------------
class VBM_UL_CollectionMaterialoverride(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=1)
        #r.prop(item, 'enabled', text="", icon='CHECKBOX_HLT' if item.enabled else 'CHECKBOX_DEHLT', emboss=False)
        r.prop(item, 'material', text="")
        r.prop(item, 'override', text="->")
classlist.append(VBM_UL_CollectionMaterialoverride)

"======================================================================================================"
"PANELS"
"======================================================================================================"

def VBMDrawLayermask(layout, id, propname, text=""):
    n = int(bpy.context.scene.vbm.layermask_display_size)
    w = bpy.context.region.width
    c = layout.column(align=1)
    if n <= 16:
        if text:
            c.label(text=text+":")
        r = c.row(align=1)
        if n ==16 and w < 350:
            [r.prop(id, propname, text=str(i)[-1], index=i, toggle=1) for i in range(0,n)]
        else:
            [r.prop(id, propname, text="%02d"%i, index=i, toggle=1) for i in range(0,n)]
    else:
        if text:
            c.label(text=text+":")
        for i in range(0,n):
            if (i%(n//2))==0:
                r = c.row(align=1)
            if n > 16 and w < 350:
                r.prop(id, propname, text=str(i)[-1], index=i, toggle=1)
            else:
                r.prop(id, propname, text="%02d"%i, index=i, toggle=1)

# ---------------------------------------------------------------------------------------
def VBMActionPanel(layout, collection):
    context = bpy.context
    
    rig = CollectionRig(collection)
    if rig:
        r = layout.row()
        r.label(text=rig.name, icon='ARMATURE_DATA')
        r.operator('vbm.rig_clear_pose', text="", icon='MOD_ARMATURE')
        layout.template_ID(rig.animation_data, 'action')
        
    r = layout.box().row()
    if collection.vbm.action_pose:
        rr = r.row()
        rr.scale_x = 0.5
        rr.label(text="Pose:")
        r.prop(collection.vbm, 'action_pose', text="")
        #r.template_ID(collection.vbm, 'action_pose', text="")
    else:
        r.prop(collection.vbm, 'action_pose')
    
    r = layout.row(align=1)
    c = r.column(align=1)
    c.scale_y = 0.7
    c.template_list('VBM_UL_CollectionActions', "", collection.vbm, 'actions', collection.vbm, 'action_index', rows=8)
    c = r.column(align=1)
    c.scale_y = 0.8
    c.prop(context.scene.vbm, 'layermask_display_list', text="", icon=VBM_LAYERMASKICON)
    c.separator()
    c.operator('vbm.collection_add_action', text="", icon='ADD')
    c.operator('vbm.collection_remove_action', text="", icon='REMOVE')
    c.separator()
    c.operator('vbm.collection_action_move', text="", icon='TRIA_UP').direction='UP'
    c.operator('vbm.collection_action_move', text="", icon='TRIA_DOWN').direction='DOWN'
    c.separator()
    c.operator('vbm.collection_sort', text="", icon='SORTALPHA')
    c.operator('vbm.collection_clear_checksum', text="", icon='UNLINKED').group='ACTION'
    
    if collection.vbm.actions:
        action = collection.vbm.actions[collection.vbm.action_index].action
        c = layout.column(align=0)
        
        VBMDrawLayermask(c, action.vbm, 'layermask', "Bone Mask")
        
        r = c.row(align=1)
        r.prop(action.vbm, 'frame_start', text="Frame Start")
        r.prop(action.vbm, 'frame_end', text="Frame End")
        #r.separator()
        #r.prop(action.vbm, 'frame_step', text="Step")
        rr = r.row(align=1)
        rr.scale_x = 0.5
        #rr.label(text="%2d" % context.scene.render.fps)

# ------------------------------------------------------------------------------------
class VBM_PT_Rig3DView(bpy.types.Panel):
    bl_label, bl_space_type, bl_region_type = ("DmrVBM Rig", 'VIEW_3D', 'UI')
    bl_category = "DmrVBM"
    
    def draw(self, context):
        layout = self.layout
        collection = ActiveCollection()
        rig = CollectionRig(collection)
        
        if not rig:
            layout.label(text=collection.name, icon='GROUP')
            layout.label(text="(No Armature Selected)")
        else:
            c = layout.column(align=1)
            c.scale_y = 0.8
            c.label(text=collection.name, icon='GROUP')
            r = c.row(align=1)
            r.label(text=rig.name, icon='ARMATURE_DATA')
            rr = r.row()
            rr.scale_x = 0.3
            rr.prop(rig.data, 'pose_position', expand=True)
classlist.append(VBM_PT_Rig3DView)

class VBM_PT_Rig3DView_Actions(bpy.types.Panel):
    bl_label, bl_space_type, bl_region_type = ("Actions", 'VIEW_3D', 'UI')
    bl_parent_id = 'VBM_PT_Rig3DView'
    #bl_category = "DmrVBM"
    
    def draw(self, context):
        VBMActionPanel(self.layout, ActiveCollection())
classlist.append(VBM_PT_Rig3DView_Actions)

# -----------------------------------------------------------------------------------------------------------
class VBM_PT_Rig3DView_Swingbones(bpy.types.Panel):
    bl_label, bl_space_type, bl_region_type, bl_options = ("Bones", 'VIEW_3D', 'UI', {'DEFAULT_CLOSED'})
    bl_parent_id = 'VBM_PT_Rig3DView'
    #bl_category = "DmrVBM"
    
    def draw(self, context):
        layout = self.layout
        collection = ActiveCollection()
        rig = CollectionRig(collection)
        
        if rig:
            deformbones = rig.get('DEFORM_LIST', None)
            if not deformbones:
                deformbones = [b for b in rig.data.bones if b.use_deform]
            
            c = layout.column(align=1)
            r = c.row(align=1)
            r.label(text="Default Layer Mask:")
            r = r.row(align=1)
            r.alignment='RIGHT'
            r.label(text="(%3d) Bones" % (len(deformbones)))
            VBMDrawLayermask(c, collection.vbm, 'bone_layermask_default', text="")
            
            r = layout.row(align=1)
            c = r.column(align=1)
            c.scale_y = 0.9
            c.template_list('VBM_UL_CollectionSwingbones', "", collection.vbm, 'swing_bones', collection.vbm, 'swing_bone_index', rows=6)
            c = r.column(align=1)
            c.scale_y = 1.0
            c.operator('vbm.collection_add_swing', text="", icon='ADD')
            c.operator('vbm.collection_remove_swing_bone', text="", icon='REMOVE')
            c.separator()
            c.prop(context.scene.vbm, 'layermask_display_list', text="", icon=VBM_LAYERMASKICON)
            
            swing = collection.vbm.swing_bones[collection.vbm.swing_bone_index] if collection.vbm.swing_bones else None
            if swing:
                b = layout.box().column(align=0)
                
                VBMDrawLayermask(b, swing, 'layermask', text="Layer Mask")
                
                c = b.column(align=0)
                c.scale_y = 0.9
                c.use_property_split = True
                c.prop(swing, 'stiffness')
                c.prop(swing, 'damping')
                c.prop(swing, 'limit')
                c.prop(swing, 'force_strength')
                
                r = b.row(align=1)
                c = r.column(align=1)
                c.scale_y = 0.7
                c.template_list('VBM_UL_CollectionSwingbonesBones', "", swing, 'bones', swing, 'bone_index', rows=6)
                c = r.column(align=1)
                c.scale_y = 1.0
                c.operator('vbm.collection_add_swing_selected', text="", icon='RESTRICT_SELECT_OFF')
classlist.append(VBM_PT_Rig3DView_Swingbones)

# -----------------------------------------------------------------------------------------------------------
class VBM_PT_Asset(bpy.types.Panel):
    bl_label, bl_space_type, bl_region_type = ("DmrVBM v1.5", 'PROPERTIES', 'WINDOW')
    bl_context = "scene"
    
    def draw(self, context):
        layout = self.layout
        vbm = context.scene.vbm
        collection = ActiveCollection()
        sc = context.scene
        obj = context.active_object
        
        # Collection ...............................................
        r = layout.row(align=1)
        r.prop(vbm, 'data_path', placeholder="(.blend folder)")
        
        r = layout.row(align=1)
        r.prop(collection.vbm, 'enabled', text="")
        r.label(text=collection.name, icon='GROUP')
        rr = r.row(align=1)
        rr.alignment = 'RIGHT'
        rr.label(text="%d File(s)" % (collection.vbm.enabled + len([1 for c in collection.children_recursive if c.vbm.enabled])) )
        
        r = layout.row(align=0)
        r.operator('vbm.export_collection', text="Export Collection" if collection.vbm.enabled else "Export Collection Files", icon='EXPORT')
        r = r.row()
        r.scale_x = 0.8
        r.operator('vbm.export_collection_all', text="Export All", icon='EXPORT')
        
        # Tab ----------------------------------------------------
        layout = layout.box().column(align=1)
        layout.row(align=1).prop(context.scene.vbm, 'panel_tab', expand=True)
        layout = layout.box().column(align=0)
        export_enabled = collection.vbm.enabled
        
        # Settings --------------------------------------------------------
        if context.scene.vbm.panel_tab == 'SCENE':
            c = layout.column()
            c.use_property_split = 1
            c.prop(context.scene.vbm, 'shader_default')
            c.prop(context.scene.vbm, 'layermask_display_size', text="Layer Mask Size")
            c.prop(context.scene.vbm, 'layermask_display_list', text="Show Mask in List")
            
            r = layout.row(align=1)
            r.label(text="Clear Checksum:", icon='UNLINKED')
            rr = r.row(align=1)
            rr.scale_x = 0.6
            rr.operator('vbm.collection_clear_checksum', text="OBJ").group='OBJECT'
            rr.operator('vbm.collection_clear_checksum', text="ANI").group='ACTION'
            rr.operator('vbm.collection_clear_checksum', text="TEX").group='IMAGE'
            
            layout.separator()
            c = layout.column(align=1)
            c.scale_y = 0.7
            c.template_list('VBM_UL_CollectionChildren', "", sc.collection.vbm, 'children', sc.collection.vbm, 'child_index', rows=6 if sc.collection.children else 2)
        # Collection -----------------------------------------------------
        elif context.scene.vbm.panel_tab == 'COLLECTION':
            # Active Collection
            r = layout.row(align=1)
            r.prop(collection.vbm, 'enabled', text="")
            r.prop(collection.vbm, 'name', text="", icon='GROUP', placeholder=collection.name+".vbm")
            rr = r.row(align=1)
            rr.alignment = 'RIGHT'
            rr.label(text="%d File(s)" % (collection.vbm.enabled + len([1 for c in collection.children_recursive if c.vbm.enabled])) )
            
            # Format
            format = collection.vbm.format
            b = layout.row(align=1)
            b.label(text="Format:")
            c = b.column(align=1)
            c.active = export_enabled
            r = c.row(align=1)
            for i,attribute_name in enumerate(VFORMAT_NAME):
                p = r.column(align=1)
                active = format[i]
                isbyte = format[i+16]
                p.prop(collection.vbm, 'format', text="", index=i, icon=VFORMAT_ICON[i], emboss=active, invert_checkbox=0)
                p.prop(collection.vbm, 'format', text="", index=i+16, icon=('EVENT_B' if isbyte else 'EVENT_F'), emboss=active, invert_checkbox=0)
            
            r = layout.row(align=1)
            r.scale_y = 0.9
            c = [r.column(align=0), r.column(align=0), r.column(align=0)]
            c[1].scale_x = 1.5
            c[2].scale_x = 0.6
            
            e = [x.row(align=1) for x in c]
            e[0].label(text="Color", icon=VFORMAT_ICON[VFORMAT_INDEX['COL']])
            if obj and obj.type=='MESH':
                e[1].prop_search(collection.vbm, 'color_layer_name', obj.data, 'color_attributes', text="", results_are_suggestions=True)
            else:
                e[1].prop(collection.vbm, 'color_layer_name', text="", placeholder="<Active VC Layer>")
            e[2].prop(collection.vbm, 'color_layer_default', text="")
            
            e = [x.row(align=1) for x in c]
            e[0].label(text="UV", icon=VFORMAT_ICON[VFORMAT_INDEX['UVS']])
            if obj and obj.type=='MESH':
                e[1].prop_search(collection.vbm, 'uv_layer_name', obj.data, 'uv_layers', text="", results_are_suggestions=True)
            else:
                e[1].prop(collection.vbm, 'uv_layer_name', text="", placeholder="<Active UV Layer>")
            e[2].row().prop(collection.vbm, 'uv_layer_default', text="")
            layout.separator()
            
            # Children
            c = layout.column(align=1)
            c.scale_y = 0.7
            c.template_list('VBM_UL_CollectionChildren', "", collection.vbm, 'children', collection.vbm, 'child_index', rows=6 if collection.children else 2)
            
        # Objects ----------------------------------------------------------
        elif context.scene.vbm.panel_tab == 'OBJECT':
            r = layout.row()
            r.label(text="", icon='TEXT')
            r.prop(collection.vbm, 'object_script_pre', text="Pre")
            r.prop(collection.vbm, 'object_script_post', text="Post")
            
            r = layout.row()
            r.active = export_enabled
            #r.prop(context.scene.vbm, 'express_export', text="", icon='FF')
            r.prop(collection.vbm, 'use_material_names')
            r.prop(collection.vbm, 'merge_meshes')
            
            r = layout.row(align=1)
            c = r.column()
            c.active = export_enabled
            c.scale_y = 0.7
            c.template_list('VBM_UL_CollectionObjects', "", collection, 'all_objects', collection.vbm, 'object_index', rows=8)
            c = r.column(align=1)
            c.prop(context.scene.vbm, 'layermask_display_list', text="", icon=VBM_LAYERMASKICON)
            c.separator()
            c.operator('vbm.collection_object_move', text="", icon='TRIA_UP').direction='UP'
            c.operator('vbm.collection_object_move', text="", icon='TRIA_DOWN').direction='DOWN'
            c.separator()
            c.operator('vbm.rename_objects', text="", icon='COPY_ID')
            c.operator('vbm.collection_clear_checksum', text="", icon='UNLINKED').group='OBJECT'
            
            if collection.all_objects:
                obj = collection.all_objects[collection.vbm.object_index]
                b = layout.column(align=1)
                b.label(text=obj.name, icon=obj.type+"_DATA")
                VBMDrawLayermask(b, obj.vbm, 'layermask', "Object Layer Mask")
                
                c = b.column(align=1)
                c.use_property_split = True
                c.prop(obj.vbm, 'export_enabled')
                c.prop(obj.vbm, 'is_collision')
            
        # Material ----------------------------------------------------------
        elif context.scene.vbm.panel_tab == 'MATERIAL':
            materials = collection.vbm.get_materials()
            materials.sort(key=lambda mtl: mtl.name)
            
            r = layout.row()
            r.operator('vbm.collection_material_fix', icon='MODIFIER')
            r.operator('vbm.texture_apply_padding', icon='CON_SIZELIMIT')
            
            # Overrides
            r = layout.row(align=1)
            c = r.column()
            c.scale_y = 0.8
            c.template_list('VBM_UL_CollectionMaterialoverride', "", collection.vbm, 'material_overrides', collection.vbm, 'material_override_index', rows=4)
            c = r.column(align=1)
            c.operator('vbm.collection_material_override_add', text="", icon='ADD')
            c.operator('vbm.collection_material_override_remove', text="", icon='REMOVE')
            c.separator()
            c.operator('vbm.collection_clear_checksum', text="", icon='UNLINKED').group='IMAGE'
            layout.separator()
            
            # Object Materials
            b = layout.row(align=0)
            r = b.row(align=1)
            r.scale_y=0.8
            c = [r.column(align=1) for i in (0,1,2,4)]
            c[0].scale_x = 1.1
            c[1].scale_x = 0.8
            c[2].scale_x = 1.2
            c[0].label(text="MTL", icon='MATERIAL')
            c[1].label(text="SHD", icon='CONSOLE')
            c[2].label(text="TEX", icon='NODE_TEXTURE')
            c[3].label(text="", icon='IMAGE_ALPHA')
            for mtl in materials:
                c[0].prop(mtl, 'name', text="")
                c[1].prop(mtl.vbm, 'shader', text="", placeholder=mtl.vbm.get_shader())
                ndimage = mtl.node_tree.nodes.get("Image Texture", None)
                if ndimage:
                    c[2].prop(ndimage, 'image', text="")
                else:
                    c[2].label(text="(No Image)")
                c[3].prop(mtl.vbm, 'transparent', text="")
        # Action
        elif context.scene.vbm.panel_tab == 'ACTION':
            VBMActionPanel(layout, collection)
classlist.append(VBM_PT_Asset)

"================================================================================================================================================="
"EXPORT"
"================================================================================================================================================="

def MeshData(src, rig=None, action=None, object_script_pre=None, object_script_post=None):
    checksum_key = (
        (action.name if action else "") + 
        (object_script_pre.name if object_script_pre else "") + 
        (object_script_post.name if object_script_post else "")
    )
    checksum = sum(tuple(np.array([x for x in (
        (
            (
                [x for s in src.data.splines for p in s.points for x in p.co]
            ) if src.type=='CURVE' else
            (
                [x for v in src.matrix_local for x in v] +
                [x for v in src.data.vertices for x in v.co] +
                [ord(x) for mtl in src.data.materials if mtl for x in mtl.name] +
                [x for lyr in src.data.color_attributes for v in lyr.data for x in v.color] +
                [x for lyr in src.data.uv_layers for v in lyr.uv for x in tuple(v.vector)]
            ) if src.type == 'MESH' else []
        ) +
        [ord(x) for m in src.modifiers if ValidName(m.name) for x in m.name]+
        [v for m in src.modifiers if ValidName(m.name) for v in [getattr(m,p.identifier) for p in m.bl_rna.properties if not p.is_readonly] if isinstance(v, (bool,int,float))]+
        ([i*ord(x) for i,bname in enumerate(EvaluateDeformOrder(src.find_armature())[0]) for x in bname] if src.find_armature() else [])+
        ([x for fc in action.fcurves for k in fc.keyframe_points for x in k.co] if action else [])+
        ([ord(c) for script in [object_script_pre, object_script_post] if script for line in script.lines for c in line.body])
        )
    ]).tobytes()))
    
    if int(src.vbm.get('VBM_CHECKSUM'+checksum_key, -1)) != checksum or not src.vbm.get('VBM_DATA'+checksum_key, {}):
        print("> Building mesh \"%s\"..." % src.name, action.name if action else "")
        
        # Staging ............................................................................................
        context = bpy.context
        obj = src.copy()
        obj.data = src.data.copy()
        obj['TEMP'] = True
        obj.data['TEMP'] = True
        obj.name = "(VBMtemp)-"+obj.name
        obj.data.name = "(VBMtemp)-"+obj.data.name
        
        [c.objects.unlink(obj) for c in list(obj.users_collection)]
        [x.select_set(False) for x in list(context.selected_objects)]
        context.scene.collection.objects.link(obj)
        context.view_layer.objects.active = obj
        obj.select_set(True)
        
        # Action Pose
        if rig:
            if action:
                if not rig.animation_data:
                    rig.animation_data_create()
                rig.data.pose_position = 'POSE'
                rig.animation_data.action = action
                rig.animation_data.action_slot = action.slots[0]
                context.scene.frame_set(context.scene.frame_current)
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        
        # Pre Script
        if object_script_pre:
            context.scene['VBM_EXPORTING'] = True
            err = ""
            try:
                err = exec(object_script_pre.as_string())
            except:
                print("> VBM: Error executing object Pre Script (%s)" % str(object_script_pre))
                print(err)
            context.scene['VBM_EXPORTING'] = False
            context.view_layer.objects.active = obj
            obj.select_set(True)
        
        # Apply modifiers
        use_skinning = rig and not action
        for m in list(obj.modifiers):
            if not ValidName(m.name) or (m.type=='ARMATURE' and use_skinning):
                bpy.ops.object.modifier_remove(modifier=m.name)
            else:
                try:
                    bpy.ops.object.modifier_apply(modifier=m.name)
                except:
                    print(src.name, m.type, m.name)
                    #bpy.ops.object.modifier_remove(modifier=m.name)
        obj.modifiers.new(name='TRIANGULATE', type='TRIANGULATE').keep_custom_normals=True
        
        bpy.ops.object.convert(target='MESH')
        obj.data.calc_tangents()
        obj.parent = None
        context.view_layer.objects.active = obj
        
        if "UVMap" not in list(obj.data.uv_layers.keys()):
            obj.data.uv_layers.new(name="UVMap")
        if "Color" not in list(obj.data.color_attributes.keys()):
            lyr = obj.data.color_attributes.new(name="Color", type='BYTE_COLOR', domain='CORNER')
            lyr.data.foreach_set('color', np.ones(len(lyr.data)*4))
        
        # Post Script
        if object_script_post:
            context.scene['VBM_EXPORTING'] = True
            err = ""
            try:
                err = exec(object_script_post.as_string())
            except:
                print("> VBM: Error executing object Post Script (%s)" % str(object_script_post))
                print(err)
            context.scene['VBM_EXPORTING'] = False
            context.view_layer.objects.active = obj
            obj.select_set(True)
        
        # Data .........................................................................................................
        uvlyr = obj.data.uv_layers.get("UVMap", obj.data.uv_layers[0])
        vclyr = obj.data.color_attributes.get("STYLE", obj.data.color_attributes.get("Color", obj.data.color_attributes[0]))
        uvdata = [tuple((uv.vector[0], 1-uv.vector[1])) for uv in uvlyr.uv]
        vcdata = [tuple(vc.color) for vc in vclyr.data]
        if sum([x for v in vcdata for x in v]) == 0:
            vcdata = [(1,1,1,1) for v in vcdata]
        
        deformorder, deformmap, deformroute = EvaluateDeformOrder(rig)
        bonemap = {vg.index: deformorder.index(vg.name) for vg in obj.vertex_groups if vg.name in deformorder}
        skinning = [ [ (bonemap[vge.group], vge.weight) for vge in v.groups if vge.weight > 0.0 and vge.group in list(bonemap.keys())] for v in obj.data.vertices ]
        [v.sort(key=lambda x: x[1]) for v in skinning]  # Sort by weight
        skinning = [ (x+[(0,0.0), (0,0.0), (0,0.0), (0,0.0)])[:4] for x in skinning ]    # Add padding, Clamp to 4
        skinning = [ [(b,w/s) for b,w in v[:4]] for v in skinning for s in [sum([w for b,w in v[:4]])+0.00000001] ] # Normalize weights
        gamma = 0.4545 if vclyr.name == 'STYLE' else 0.4545
        
        # Compose ..............................................................................................................
        verts, loops, tris = tuple(obj.data.vertices), tuple(obj.data.loops), tuple(obj.data.loop_triangles)
        vgoutline = obj.vertex_groups.get('OUTLINEWEIGHT', None).index if 'OUTLINEWEIGHT' in list(obj.vertex_groups.keys()) else -1
        otdata = (np.array([([vge.weight for vge in v.groups if vge.group == vgoutline]+[1.0])[0] for v in verts])*255.0).astype(np.uint8)
        
        mtlvbs = {}
        material_count = len(obj.data.materials)
        material_indices = list(range(0, material_count)) if material_count > 0 else [0]
        for material_index in material_indices:
            mtl = obj.data.materials[material_index] if material_count > 0 else None
            mtlloops = [l for p in tris if p.material_index == material_index for l in p.loops]
            if mtlloops:
                mtlname = mtl.name if mtl else ""
                if mtlname not in mtlvbs:
                    mtlvbs[mtlname] = {k:b'' for k in VFORMAT_NAME}
                
                mtlvbs[mtlname]['POS'] += b''.join([PackVector('f', verts[loops[l].vertex_index].co) for l in mtlloops])
                mtlvbs[mtlname]['COL'] += b''.join([PackVector('B', [int(255*(x**gamma)) for x in vcdata[l]]) for l in mtlloops])
                mtlvbs[mtlname]['UVS'] += b''.join([PackVector('f', uvdata[l]) for l in mtlloops])
                mtlvbs[mtlname]['NOR'] += b''.join([PackVector('f', loops[l].normal) for l in mtlloops])
                mtlvbs[mtlname]['TAN'] += b''.join([PackVector('f', loops[l].tangent) for l in mtlloops])
                mtlvbs[mtlname]['BTN'] += b''.join([PackVector('f', loops[l].bitangent) for l in mtlloops])
                mtlvbs[mtlname]['BON'] += b''.join([PackVector('f', [b for b,w in skinning[loops[l].vertex_index]]) for l in mtlloops])
                mtlvbs[mtlname]['WEI'] += b''.join([PackVector('f', [w for b,w in skinning[loops[l].vertex_index]]) for l in mtlloops])
                
                for vclyr in obj.data.color_attributes:
                    if vclyr.name not in mtlvbs[mtlname].keys():
                        mtlvbs[mtlname][vclyr.name] = b''
                    mtlvbs[mtlname][vclyr.name] += b''.join([PackVector('B', [int(255*(x**gamma)) for x in vclyr.data[l].color]) for l in mtlloops])
                
        if src.vbm.get('VBM_DATA'+checksum_key, None):
            del src.vbm['VBM_DATA'+checksum_key]
        src.vbm['VBM_DATA'+checksum_key] = {mtlname: {streamkey: zlib.compress(stream) for streamkey,stream in streams.items()} for mtlname,streams in mtlvbs.items()}
        src.vbm['VBM_CHECKSUM'+checksum_key] = checksum
    return {mtlname: {streamkey: zlib.decompress(streamcompressed) for streamkey,streamcompressed in mtlstreams.items()} for mtlname,mtlstreams in src.vbm['VBM_DATA'+checksum_key].items()}

def AnimData(action, rig):
    checksum = sum(np.array([x for x in (
        [x for b in rig.data.bones for v in (b.head_local, b.tail_local) for x in v] +
        [x for fc in action.fcurves for k in fc.keyframe_points for x in k.co] +
        ([i*ord(x) for i,bname in enumerate(EvaluateDeformOrder(rig)[0]) for x in bname] if rig else [])
    )]).tobytes() )
    if action.vbm.get('VBM_CHECKSUM', -1) != checksum:
        # Make Proxy
        context = bpy.context
        deformorder, deformmap, deformroute = EvaluateDeformOrder(rig)
        
        proxy = bpy.data.objects.get(rig.vbm.get('PROXY', ""), None)
        if not proxy:
            proxy = bpy.data.objects.new(name="PROXY_"+rig.name, object_data=bpy.data.armatures.new(name="PROXY_"+rig.name))
            proxy['TEMP'] = True
            proxy.data['TEMP'] = True
            context.scene.collection.objects.link(proxy)
            proxy.show_in_front=True
            context.view_layer.objects.active = proxy
            proxy.animation_data_create()
            
            bpy.ops.object.mode_set(mode='OBJECT')
            bonedata = [
                (b.name, b.head_local, b.tail_local, b.AxisRollFromMatrix(b.matrix_local.to_3x3())[1], b.use_connect) 
                for bname in deformorder if bname in rig.data.bones.keys() for b in [rig.data.bones[bname]]
            ]
            
            proxy.select_set(True)
            bpy.ops.object.mode_set(mode='EDIT')
            for bname, head, tail, roll, use_connect in bonedata:
                b = proxy.data.edit_bones.new(name=bname)
                b.head, b.tail, b.roll = (head,tail,roll)
                b.parent = proxy.data.edit_bones[deformmap[bname]] if deformmap.get(bname, None) in list(proxy.data.edit_bones.keys()) else None
                b.use_connect = use_connect
            bpy.ops.object.mode_set(mode='POSE')
            rig.vbm['PROXY'] = proxy.name
        
        # Bake Animation
        print("> Baking animation", action.name)
        
        [obj.select_set(False) for obj in context.selected_objects]
        context.view_layer.objects.active = proxy
        proxy.select_set(True)
        proxy.animation_data.action = bpy.data.actions.new(action.name+"__deform")
        proxy.animation_data.action['TEMP'] = True
        
        rig.animation_data.action = action
        rig.animation_data.action_slot = action.slots[0]
        rig.data.pose_position = 'POSE'
        proxy.data.pose_position = 'POSE'
        
        bpy.ops.object.mode_set(mode='POSE')
        for pb in rig.pose.bones:
            pb.location = (0,0,0)
            pb.rotation_quaternion = (1,0,0,0)
            pb.scale = (1,1,1)
        for pb in proxy.pose.bones:
            c = pb.constraints.new(type='COPY_TRANSFORMS')
            c.target = rig
            c.subtarget = pb.name
            
        bpy.ops.nla.bake(
            frame_start=int(action.frame_range[0]), frame_end=int(action.frame_range[1]+1), step=1, 
            only_selected=False, visual_keying=True, clear_constraints=True, clear_parents=False, 
            use_current_action=True, clean_curves=True, 
            bake_types={'POSE'}, channel_types={'LOCATION', 'ROTATION', 'SCALE'}
        )
        
        fcurves = proxy.animation_data.action.fcurves
        bonefcurves = {
            bname: (
                fcurves.find("pose.bones[\"%s\"].location" % bname, index=0),
                fcurves.find("pose.bones[\"%s\"].location" % bname, index=1),
                fcurves.find("pose.bones[\"%s\"].location" % bname, index=2),
                fcurves.find("pose.bones[\"%s\"].rotation_quaternion" % bname, index=0),
                fcurves.find("pose.bones[\"%s\"].rotation_quaternion" % bname, index=1),
                fcurves.find("pose.bones[\"%s\"].rotation_quaternion" % bname, index=2),
                fcurves.find("pose.bones[\"%s\"].rotation_quaternion" % bname, index=3),
                fcurves.find("pose.bones[\"%s\"].scale" % bname, index=0),
                fcurves.find("pose.bones[\"%s\"].scale" % bname, index=1),
                fcurves.find("pose.bones[\"%s\"].scale" % bname, index=2),
            )
            for bname in deformorder
        }
        
        curvesbone = {
            bname: [ [(k.co[0]-action.frame_start, k.co[1]) for k in fc.keyframe_points] if fc else [] for fc in bonechannels]
            for bname, bonechannels in bonefcurves.items()
        }
        
        if action.vbm.get('VBM_DATA', None):
            del action.vbm['VBM_DATA']
        action.vbm['VBM_DATA'] = curvesbone
        action.vbm['VBM_CHECKSUM'] = checksum
    
    return {
        curvename: tuple([
            tuple([
                tuple(k) for k in channel   # Keyframes
            ])
            for channel in curvedata    # Channels
        ])
        for curvename, curvedata in action.vbm['VBM_DATA'].items()    # Curves
    }

def ImageData(image, palette_max=255):
    checksum = sum(tuple(image.pixels)) + palette_max
    if image.vbm.get('VBM_CHECKSUM', -1) != checksum:
        srcpixels = np.frombuffer((np.array(image.pixels)*255).astype(np.uint8).tobytes(), dtype=np.uint32)
        w,h = image.size
        srcpixels = srcpixels.reshape(-1,w)[::-1].flatten()     # Flip image pixels
        pixels = srcpixels[:]
        palette = list(set(pixels))
        
        # Reduce number of colors while palette count is higher than max
        n1 = len(palette)
        if n1 > 0:
            p = 1
            # Old Method
            if 0:
                pbytes = np.array(tuple(pixels.tobytes()), dtype=np.uint8)
                if image.alpha_mode == 'NONE':
                    pbytes |= 0xFF000000
                while len(palette) >= palette_max:
                    p += 1
                    pixels = np.frombuffer((pbytes // p) * p, dtype=np.uint32)
                    palette = list(set(pixels))
            # Palette Map, maintaining colors used in image
            elif len(palette) < palette_max:
                newpixels = pixels
                srcpalette = np.unique(pixels)
                for pmask in (0xf7f7f7f7, 0xf0f0f0f0, 0xaaaaaaaa, 0xa2a2a2a2, 0x88888888):
                    print(HexString(pmask, 8))
                    palette_map = { x&pmask: i for i,x in enumerate(srcpalette) }
                    newpixels = tuple([srcpalette[ palette_map[x&pmask] ] for x in pixels])
                    palette = list(set(newpixels))
                    if len(palette) < palette_max:
                        break
                pixels = newpixels
                
            print(image.name, "| Palette ", n1, "->", len(palette), "| P =", p)
        palette.sort()
        indices = [palette.index(x) for x in pixels]
        
        image.vbm['VBM_DATA'] = (zlib.compress(np.array(palette, dtype=np.uint32)), zlib.compress(np.array(indices, dtype=np.uint32)))
        image.vbm['VBM_CHECKSUM'] = checksum
    
    palette = np.frombuffer( zlib.decompress(image.vbm['VBM_DATA'][0]), dtype=np.uint32 )
    indices = np.frombuffer( zlib.decompress(image.vbm['VBM_DATA'][1]), dtype=np.uint32 )
    
    if ( image.alpha_mode.upper() == 'NONE' ):
        palette = palette | 0xFF000000
    return (palette, indices)

# ===================================================================================================================
def ExportModel(collection, report=True):
    print("> Exporting model \"%s\" ***********************************************************************" % collection.name)
    
    Clean()
    
    context = bpy.context
    
    collectionobjects = [x for x in collection.objects]
    meshobjects = [x for x in collection.objects if x.type=='MESH' and ValidName(x.name)]
    
    action_pose = collection.vbm.action_pose
    rig = ([obj for obj in collection.all_objects if obj.type=='ARMATURE' and len(obj.children) > 0]+[None])[0]
    deformorder, deformmap, deformroute = EvaluateDeformOrder(rig)
    
    last_active_object = context.active_object
    last_rig_action = rig.animation_data.action if rig and rig.animation_data else None
    last_rig_position = rig.data.pose_position if rig else None
    
    format = collection.vbm.format
    format_mask = sum([1<<i for i,x in enumerate(format) if x]) // 1
    stride = CalcStride(format_mask)
    
    swing_collection = collection
    if rig and len(collection.vbm.swing_bones) == 0:
        swing_collection = rig.users_collection[0]
    swing_bones = swing_collection.vbm.swing_bones
    
    palette_max = 1024
    
    print("\t%02dB:"%stride, [VFORMAT_NAME[i] for i in range(0,16) if format_mask&(1<<i)])
    
    meshitems = []
    collisionitems = []
    boneitems = []
    materialitems = []
    textureitems = []
    animationitems = []
    
    modeldata = {k: [] for k in 'NAM VTX MSH PSM SKE TEX MTL ANI'.split()}
    
    # Objects -------------------------------------------------------------------------------
    vbmap = {}
    material_names = []
    
    def ExportModel_WalkObjects(state, parent_index, objects, depth=0):
        vbmap = state['vbmap']
        modeldata = state['modeldata']
        format_mask = state['format_mask']
        collection = state['collection']
        material_names = state['material_names']
        
        object_script_pre = collection.vbm.object_script_pre
        object_script_post = collection.vbm.object_script_post
        
        use_material_names = collection.vbm.use_material_names
        merge_meshes = collection.vbm.merge_meshes
        
        objects = list(objects)
        for obj in objects:
            if not ValidName(obj.name):
                continue
            if not obj.vbm.export_enabled:
                continue
            
            node_enabled = 1
            node_index = len(modeldata['SKE'])
            node_meshes = []
            layermask = sum([1<<i for i,x in enumerate(obj.vbm.layermask) if x])
            
            if obj.type in VBM_MESHTYPES:
                # Prism .....................................................
                if obj.vbm.is_collision:
                    vb = b''
                    for mtlname, mtlstreams in MeshData(obj, rig).items():
                        vb += mtlstreams['POS']
                    
                    coords = ([Vector(Unpack('fff', vb[i:i+12])) for i in range(0, len(vb), VFORMAT_SPACE[0])])
                    bounds = (
                        tuple([min([v[i] for v in coords]) for i in (0,1,2)]),
                        tuple([max([v[i] for v in coords]) for i in (0,1,2)])
                    )
                    loop_count = len(coords)
                    triangle_count = loop_count // 3
                    
                    flags = (
                        0
                    )
                    
                    collisionbin = b''
                    collisionbin += Pack('i', flags)
                    collisionbin += Pack('i', ~0 if rig else node_index)    # Node Index
                    collisionbin += Pack('i', len(coords))
                    collisionbin += b''.join([PackVector('f', v) for v in coords])
                    modeldata['PSM'].append(collisionbin)
                # Mesh .......................................................
                else:
                    mtlvbs = MeshData(obj, rig, action=action_pose, object_script_pre=object_script_pre, object_script_post=object_script_post).items()
                    for mtlname,mtlstreams in mtlvbs:
                        # Fix name
                        meshname = obj.name.split("/")[-1]
                        if merge_meshes:
                            meshname = meshname.split(".")[0]
                        if use_material_names:
                            meshname += "_"+mtlname
                        meshname = FixName(meshname)
                        
                        if meshname not in list(vbmap.keys()):
                            vbmap[meshname] = {'vb': b'', 'material': mtlname, 'node_index': node_index, 'layermask': layermask}
                        else:
                            node_enabled = 0
                        
                        if mtlname not in material_names:
                            material_names.append(mtlname)
                        
                        loop_count = len(mtlstreams['POS']) // 12
                        
                        streams = []
                        streamspaces = []
                        for a in range(0, 10):
                            if format_mask & (1<<a):
                                space = VFORMAT_SPACE[a]
                                # Use given color layer
                                if VFORMAT_NAME[a] == 'COL' and collection.vbm.color_layer_name != "":
                                    if collection.vbm.color_layer_name in mtlstreams.keys():
                                        streams.append(mtlstreams[collection.vbm.color_layer_name])
                                    else:
                                        streams.append(PackVector('B', [int(255*x) for x in collection.vbm.color_layer_default])*loop_count)
                                # Use given UV layer
                                elif VFORMAT_NAME[a] == 'UVS' and collection.vbm.uv_layer_name != "":
                                    if collection.vbm.uv_layer_name in mtlstreams.keys():
                                        streams.append(mtlstreams[collection.vbm.uv_layer_name])
                                    else:
                                        streams.append(PackVector('f', collection.vbm.uv_layer_default)*loop_count)
                                # Normals
                                elif VFORMAT_NAME[a] == 'NOR' and format_mask & (VFORMAT_INDEX['NOR']<<16):
                                    stream = mtlstreams['NOR']
                                    stream = b''.join([PackVector('B', [int(255*(x*0.5+0.5)) for x in Unpack('fff', stream[l*12:(l+1)*12])]+[0]) for l in range(0, loop_count)])
                                    space = 3*4
                                    streams.append(stream)
                                # Bones, Weights
                                elif VFORMAT_NAME[a] == 'BON':
                                    stream = mtlstreams[VFORMAT_NAME[a]]
                                    if format_mask & (1<<(a+16)):
                                        stream = b''.join([PackVector('B', [int(x) for x in Unpack('ffff', stream[l*16:(l+1)*16])]) for l in range(0, loop_count)])
                                        space = 4
                                    streams.append(stream)
                                elif VFORMAT_NAME[a] == 'WEI':
                                    stream = mtlstreams[VFORMAT_NAME[a]]
                                    if format_mask & (1<<(a+16)):
                                        stream = b''.join([PackVector('B', [int(x*255.0) for x in Unpack('ffff', stream[l*16:(l+1)*16])]) for l in range(0, loop_count)])
                                        space = 4
                                    streams.append(stream)
                                # Other attribute
                                else:
                                    streams.append(mtlstreams[VFORMAT_NAME[a]])
                                streamspaces.append(space)
                        
                        vb = b''.join(tuple([
                            streams[a][l*space:(l+1)*space]
                            for l in range(0, loop_count)
                            for a,space in enumerate(streamspaces)
                        ]))
                        vbmap[meshname]['vb'] += vb
            
            if node_enabled:
                flags = 0
                bonebin = b''
                bonebin += Pack('i', flags)         # Flags
                bonebin += Pack('i', layermask)     # Layermask
                bonebin += PackMatrix(obj.matrix_world)    # Bind Matrix
                bonebin += Pack('i', parent_index)                    # Parent Index
                bonebin += PackString(FixName(obj.name.split("/")[-1]))     # Name
            
            modeldata['SKE'].append(bonebin)
            ExportModel_WalkObjects(state, node_index, obj.children, depth+1)
        return state
    
    walkobjects = list(collection.objects)
    def ExportModel_WalkCollection(objects, collection):
        for c in collection.children:
            if ValidName(c.name) and not c.vbm.enabled:
                objects += list(c.objects)
                ExportModel_WalkCollection(objects, c)
    ExportModel_WalkCollection(walkobjects, collection)
    
    walkstate = ExportModel_WalkObjects(
        {'collection': collection, 'vbmap': vbmap, 'modeldata':modeldata, 'vb':b'', 'format': format, 'format_mask': format_mask, 'material_names':material_names}, 
        ~0, 
        [x for x in walkobjects if not x.parent]
    )
    
    netvb = b''
    
    # Meshes ------------------------------------------------------------------------------
    for meshname, meshdata in list(vbmap.items()):
        mtlname = meshdata['material']
        vb = meshdata['vb']
        node_index = meshdata['node_index']
        layermask = meshdata['layermask']
        
        loop_count = len(vb) // stride
        loop_offset = len(netvb) // stride
        
        flags = 0
        #print("\tMSH [%6d: %6d] %16s | Mtl: \"%s\"" % (loop_offset, loop_offset+loop_count, meshname, mtlname))
        
        coords = ([Vector(Unpack('fff', vb[i:i+12])) for i in range(0, len(vb), stride)])
        bounds = (
            tuple([min([v[i] for v in coords]) for i in (0,1,2)]),
            tuple([max([v[i] for v in coords]) for i in (0,1,2)])
        )
        
        meshbin = b''
        meshbin += Pack('i', flags)     # Flags
        meshbin += Pack('i', layermask)     # Layermask
        meshbin += PackString(meshname)     # Mesh name
        meshbin += Pack('i', ~0 if rig else node_index)    # Node Index
        meshbin += Pack('i', material_names.index(mtlname))     # Material Index
        meshbin += Pack('i', loop_offset)     # Loop Start
        meshbin += Pack('i', loop_count)     # Loop Count
        meshbin += PackVector('f', bounds[0]) + PackVector('f', bounds[1])     # Bounds
        modeldata['MSH'].append(meshbin)
        
        netvb += vb
    
    # Bones -------------------------------------------------------------------------------
    if rig:
        modeldata['SKE'] = []
        deformorder, deformmap, deformroute = EvaluateDeformOrder(rig)
        
        parent_index_last = 255
        parent_switches = 0
        switched = 0
        
        for bname in deformorder:
            layermask = swing_collection.vbm.get_bone_layermask(bname)
            swing = ([swing for swing in swing_bones if bname in list(swing.bones.keys())]+[None])[0]
            flags = (
                (VBM_BONEFLAGS_SWINGBONE if swing else 0)
            )
            
            switched = 0
            parent_index = deformorder.index(deformmap[bname]) if deformmap[bname] else ~0
            if parent_index != parent_index_last:
                parent_index_last = parent_index
                parent_switches += 1
                switched = 1
            
            b = rig.data.bones.get(bname, None)
            bonebin = b''
            bonebin += Pack('i', flags)             # Flags
            bonebin += Pack('i', layermask)         # Layermask
            bonebin += PackMatrix(b.matrix_local if b else Matrix.Identity(4))  # Bind Matrix
            bonebin += Pack('i', parent_index)    # Parent Node Index
            bonebin += PackString(FixName(bname))   # Node Name
            
            BoneDepth = lambda bname, deformmap: (1+BoneDepth(deformmap[bname], deformmap)) if deformmap[bname] else 0
            #print("[%3d ^ %3d] %s %s%s" % (len(modeldata['SKE']), parent_index, " !"[switched], "| "*BoneDepth(bname, deformmap), bname))
            
            if flags & VBM_BONEFLAGS_SWINGBONE:
                bonebin += Pack('f', swing.stiffness)
                bonebin += Pack('f', swing.damping)
                bonebin += Pack('f', swing.limit)
                bonebin += Pack('f', swing.force_strength)
            
            modeldata['SKE'].append(bonebin)
        #print("Switches:", parent_switches)
    
    # Materials --------------------------------------------------------------------------
    texturenames = []
    for mtlname in material_names:
        mtl = bpy.data.materials.get(mtlname, None)
        if not mtl:
            continue
        mtl = collection.vbm.get_material_override(mtl)
        flags = (
            VBM_MATERIALFLAGS_TRANSPARENT * (mtl.vbm.transparent)
        )
        
        texturenodes = [nd for nd in mtl.node_tree.nodes if ValidName(nd.name) and nd.bl_idname=='ShaderNodeTexImage' and nd.image]
        texturenodes.sort(key=lambda nd: -nd.location[1] if nd else 1000000000000)
        for nd in texturenodes:
            if nd.image.name not in texturenames:
                texturenames.append(nd.image.name)
        texturenodes = (texturenodes+[None]*4)[:4]
        
        mtlbin = b''
        mtlbin += Pack('i', flags)
        mtlbin += PackString(mtl.vbm.shader)  # Shader Name
        
        # 4 Textures max
        for texturenode in texturenodes:
            if texturenode:
                texflags = (
                    (VBM_TEXTUREFLAG_FILTERLINEAR * (texturenode.interpolation.upper() != 'CLOSEST')) |
                    (VBM_TEXTUREFLAG_EXTEND * (texturenode.interpolation=='EXTEND'))
                )
            else:
                texflags = 0
            mtlbin += Pack('i', texflags)  # Texture Flags
            mtlbin += Pack('i', texturenames.index(texturenode.image.name) if texturenode else 0)   # Texture Index
            mtlbin += PackString(texturenode.name if texturenode else "")  # Texture Name
        modeldata['MTL'].append(mtlbin)
    
    # Images --------------------------------------------------------------------------------
    for texturename in texturenames:
        image = bpy.data.images.get(texturename)
        w,h = image.size
        palette, indices = ImageData(image, palette_max)
        index_dtype = 'H' if len(palette) >= 256 else 'B'
        
        imagebin = b''
        imagebin += Pack('III', w, h, len(palette))
        imagebin += PackVector('I', palette)
        
        # Switch data type based on palette count
        imagebin += PackVector(index_dtype, indices)
        modeldata['TEX'].append(imagebin)
    
    # Actions -----------------------------------------------------------------------------
    Clean()
    for actionitem in collection.vbm.actions:
        if not actionitem.export_enabled:
            continue
        
        action = actionitem.action
        actionname = action.name
        
        if 1:
            actionname = actionname.split("/")[-1]
        
        bonemask = int(sum([1<<i for i,x in enumerate(action.vbm.layermask) if x]))
        
        bonedata = AnimData(action, rig)
        bonedata = {bname: curves for bname,curves in bonedata.items() if swing_collection.vbm.get_bone_layermask(bname) & bonemask}
        
        propcurves = [fc for fc in action.fcurves if "pose.bones" not in fc.data_path]
        propdata = {fc.data_path: [] for fc in propcurves}
        [propdata[fc.data_path].append([tuple(k.co) for k in fc.keyframe_points]) for fc in propcurves]
        propdata = { k.split("\"")[1] if "\"" in k else k :channels for k,channels in propdata.items() }
        
        curvedata = {name:channels for name,channels in list(bonedata.items())+list(propdata.items())}
        
        frame_start = int(action.frame_range[0])
        frame_end = int(action.frame_range[1])
        frame_step = int(action.vbm.frame_step)
        flags = (
            ( VBM_ANIMATIONFLAGS_CURVENAMES * 1 )  # Curve names
        )
        
        outaction = b''
        outaction += Pack('BBB', *[ord(c) for c in "ANI"])+Pack('B', 0)  # Version
        outaction += Pack('i', flags)  # Flags
        outaction += PackString(FixName(actionname))  # Name
        outaction += Pack('i', int((action.frame_end-action.frame_start+1)*frame_step))     # Duration
        outaction += Pack('i', 0*frame_step)     # Loop Point
        outaction += Pack('i', len(curvedata.values()))  # Curve Count
        outaction += Pack('i', sum([len(curve) for curve in curvedata.values()]))  # Channel Count
        outaction += Pack('i', sum([len(channel) for curve in curvedata.values() for channel in curve]))  # Keyframe Count
        outaction += Pack('i', len(bonedata.values()))  # Props View Index / Number of bone curves
        
        # Bone Curves + Property Curves 
        for curvename, channels in curvedata.items():
            if flags & VBM_ANIMATIONFLAGS_CURVENAMES:
                outaction += PackString(FixName(curvename))  # Curvename
            outaction += Pack('i', len(channels)) # Channel count
            for channel in channels:
                outaction += Pack('i', len(channel)) # Keyframe count
                for k in channel:
                    #print(action.name, k, [x*floatwidth for x in k])
                    outaction += Pack('f', k[0])    # Frame
                    outaction += Pack('f', k[1])    # Value
        
        modeldata['ANI'].append(outaction)
        collection.vbm.action_index = collection.vbm.action_index
    
    # Output ------------------------------------------------------------------------------
    Clean()
    
    context.view_layer.objects.active = last_active_object
    if rig and rig.animation_data:
        rig.animation_data.action = last_rig_action
        rig.data.pose_position = last_rig_position
    
    if len(netvb) == 0:
        print("! WARNING: Length of vertex buffer == 0")
    
    modeldata['NAM'] = PackString(FixName(collection.name))                 # Model Name
    modeldata['VTX'] = Pack('I', format_mask) + Pack('I', len(netvb)) + netvb    # Vertex Buffer
    modeldata['END'] = Pack('I', 0)  # End chunk
    
    print([", ".join([ (("%s[%d]" % (type, len(data)))) if isinstance(data, list) else "{%s}"%type for type,data in modeldata.items() if data])])
    
    modelchunks = {
        chunktype: (Pack('I', len(data)) + b''.join(data)) if isinstance(data, list) else data
        for chunktype, data in modeldata.items() if data
    }
    modelbin = b''.join([PackString(chunktype) + Pack('I', len(chunk)) + chunk for chunktype, chunk in modelchunks.items()])
    
    # Write to file
    if context.scene.vbm.data_path:
        filepath = bpy.path.abspath(context.scene.vbm.data_path)
    else:
        filepath = bpy.path.abspath("/")
    
    if filepath[-1] not in "/\\":
        filepath += "/"
    filepath = filepath + FixName(os.path.splitext(collection.vbm.get_name())[0]) + VBM_FILEEXT
    
    f = open(os.path.abspath(bpy.path.abspath(filepath)), "wb")
    f.write(modelbin)
    f.close()
    
    if len(modelbin)/1000000 > 0.01:
        print("< File written to \"%s\" (%4.4f MB)" % (filepath, len(modelbin)/1_000_000))
    else:
        print("< File written to \"%s\" (%4.4f MB)" % (filepath, len(modelbin)/1_000_000))
    print()

"======================================================================================================"
"REGISTER"
"======================================================================================================"

def register():
    [bpy.utils.register_class(c) for c in classlist]
    bpy.types.Collection.vbm = PointerProperty(name="DmrVBM", type=VBM_PG_Collection)
    bpy.types.Scene.vbm = PointerProperty(name="DmrVBM", type=VBM_PG_Scene)
    bpy.types.Material.vbm = PointerProperty(name="DmrVBM", type=VBM_PG_Material)
    bpy.types.Action.vbm = PointerProperty(name="DmrVBM", type=VBM_PG_Action)
    
    bpy.types.Object.vbm = PointerProperty(name="DmrVBM", type=VBM_PG_Object)
    bpy.types.Image.vbm = PointerProperty(name="DmrVBM", type=VBM_PG_Image)
    #bpy.types.SpaceView3D.draw_handler_add(vbm_draw_gpu, (), 'WINDOW', 'POST_VIEW')
    
def unregister():
    [bpy.utils.unregister_class(c) for c in classlist[::-1]]
    
if __name__ == "__main__":
    register()

for action in bpy.data.actions:
    action.vbm['MUTEX'] = 0

