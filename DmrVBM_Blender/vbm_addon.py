import bpy
import os
import numpy as np
import zlib
import time
import gpu

from math import sin, cos, atan2
from mathutils import Vector, Color, Matrix, Euler, Quaternion
from bpy.props import BoolProperty, BoolVectorProperty, IntProperty, IntVectorProperty, FloatProperty, FloatVectorProperty, StringProperty, EnumProperty, PointerProperty, CollectionProperty
from struct import pack as Pack
from struct import unpack as Unpack
from gpu_extras.batch import batch_for_shader

# Blender 5.0 changed how fcurves are stored:
from bpy_extras import anim_utils

PackChars = lambda s: b''.join([Pack('B', ord(c)) for c in s])
PackString = lambda s: b''.join([Pack('B', ord(c)) for c in s]) + Pack('B', 0)
PackVector = lambda k,v: b''.join([Pack(k,x) for x in v])
PackMatrix = lambda m: b''.join([Pack('ffff', *tuple(v)) for v in m.copy().transposed().copy()])

HexString = lambda value,n=8: "".join("0123456789ABCDEF"[(value>>(i*4)) & 0xF] for i in range(0, n))[::-1]

I32toVec4 = lambda value: Vector([ ((int(value) >> i*8) & 0xFF) / 255.0 for i in range(0,4)])

classlist = []

def printd(*args):
    if bpy.context.scene.vbm.print_debug:
        print(" ".join([str(x) for x in args]))

def ObjIcon(objtype):
    return 'OUTLINER_DATA_'+objtype

"======================================================================================================"
"CONSTANTS"
"======================================================================================================"

BLENDER_5_0 = bpy.app.version >= (5,0,0)

VBM_MATERIALTEXTURECOUNT = 8

MODEL_NULLINDEX = 255

VBM_SHOWMODIFIERBAKE = False                # Default value for showing modifier bake options
VBM_SCRIPTISEXPORTING = 'VBM_EXPORTING'     # Set in active scene before running pre and post script mesh code

VBM_FILEEXT = ".vbm"

VBM_LAYERMASKSIZE = 32
VBM_LAYERMASKICON = 'INFO'
VBM_MESHTYPES = ('MESH', 'CURVE')

VBM_EXPORTENABLEDICONS = ('CHECKBOX_DEHLT', 'CHECKBOX_HLT', 'CHECKMARK')
VBM_ICON_SWING = 'CON_SPLINEIK'

VBM_ICON_BACKFACECULLING = 'ORIENTATION_NORMAL'
VBM_ICON_TRANSPARENT = 'IMAGE_ALPHA'
VBM_ICON_FLIPFACES = 'CUBE'
VBM_ICON_CASTSHADOW = 'LIGHT_HEMI'
VBM_ICON_SHADER = 'CONSOLE'
VBM_ICON_USEDEPTH = 'VIEW_PERSPECTIVE'
VBM_ICON_CLEARCHECKSUM = 'UNLINKED'

VBM_VTX_COMPRESSED = 1<<0

VBM_BONEPROP_STRING = 0
VBM_BONEPROP_INT = 1
VBM_BONEPROP_FLOAT = 2

VBM_BONEFLAGS_HIDDEN = (1<<0)
VBM_BONEFLAGS_SWINGBONE = (1<<1)
VBM_BONEFLAGS_HASPROPS = (1<<2)
VBM_BONEFLAGS_HASDATA = (1<<3)

VBM_TEXTUREFLAG_SRGB = (1<<0)
VBM_TEXTUREFLAG_COMPRESSED = (1<<7)

VBM_MATERIALFLAGS_TRANSPARENT = (1<<0)
VBM_MATERIALFLAGS_USECULLING = (1<<1)
VBM_MATERIALFLAGS_FLIPFACES = (1<<2)
VBM_MATERIALFLAGS_USEDEPTH = (1<<3)

VBM_MTLTEXFLAG_FILTERLINEAR = (1<<1)
VBM_MTLTEXFLAG_EXTEND = (1<<2)

VBM_ANIMATIONFLAGS_CURVENAMES = (1<<0)
VBM_ANIMATIONFLAGS_CURVELOOP = (1<<1)
VBM_ANIMATIONFLAGS_MARKERS = (1<<2)

VBM_NODEFLAGS_USETRANSFORMCOMPONENTS = (1<<1)

ATTRIBUTEDATA = (     # (name, size, space, icon)
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

ATTRIBUTE_MAX = len(ATTRIBUTEDATA)
ATTRIBUTE_NAME = [x[0] for x in ATTRIBUTEDATA]
ATTRIBUTE_LENGTH = [x[1] for x in ATTRIBUTEDATA]
ATTRIBUTE_ICON = [x[3] for x in ATTRIBUTEDATA]
ATTRIBUTE_INDEX = {k: i for i,k in enumerate(ATTRIBUTE_NAME)}

VBM_ICON_COLOR = ["STRIP_COLOR_%02d" % i for i in range(1, 10)]

VBM_COLOR_BONEGROUP = tuple([I32toVec4(x) for x in (
    0xff525ACC, # Red
    0xff488ACC, # Orange
    0xff3FA3B3, # Yellow
    0xff5C995C, # Green
    0xffCC9F51, # Aqua
    0xffDA598D, # Purple
    0xffB873C6, # Pink
    0xff526999, # Brown
    0xff808080, # Gray
)])

ATTRIBUTE_DEFAULTMASK = sum([
    ((1<<i) * (ATTRIBUTE_NAME[i] in 'POS COL UVS'.split())) | ((1<<(i+16)) * (ATTRIBUTE_NAME[i] in ['COL']))
    for i in range(0,10)
])

Items_Framerate = tuple([ (str(i),str(i)+" FPS",str(i)+" FPS", 'NONE', i) for i in range(1,61) if (60/i)==float(60//i) ])
Items_LayermaskSize = tuple([ (str(i),str(i),str(i), 'NONE', i) for i in (8,16,32) ])

Items_MeshJoinType = (
    ('NONE', 'None', "No changes to mesh objects", 'BLANK1', 0),
    ('NAME', 'Name', "Join meshes with matching evaluated name.\nEx: [PoppieWear.top, PoppieWear.shorts] => [PoppieWear]", 'SORTALPHA', 1),
    ('MATERIAL', 'Material', "Join meshes with matching materials", 'MATERIAL', 2),
)

"======================================================================================================"
"FUNCTIONS"
"======================================================================================================"

# Returns array of vec3 multiplied by matrix
def mul_v3n_v3nf_m4(vectors, w, matrix):
    return ((np.array(np.array(matrix)) @ np.concatenate((vectors.T,[w*np.ones(len(vectors))]))).T)[:,:3].astype(np.float32)

def CalcStride(format_mask):
    stride = 0
    for i in range(0, ATTRIBUTE_MAX):
        if format_mask & (1<<i):
            is_bytes = (format_mask & (1<<(i+16))) != 0
            stride += (4) if is_bytes else (ATTRIBUTE_LENGTH[i] * 4)
    return stride

def ActiveCollection():
    return bpy.context.collection

def ActiveCollectionMaterial():
    collection = ActiveCollection()
    mtl = None
    if collection.vbm.material_overrides:
        override = collection.vbm.material_overrides[collection.vbm.material_override_index]
        mtl = override.override if override.override else override.material
    if not mtl:
        mtl = ([obj.active_material for obj in collection.all_objects if obj.type=='MESH' and ValidName(obj.name)]+[None])[0]
    if not mtl and bpy.context.active_object:
        mtl = bpy.context.active_object.active_material
    return mtl

def CollectionRig(collection=None):
    if not collection:
        collection=ActiveCollection()
    return ([x for x in collection.all_objects if x.type=='ARMATURE' and x.children]+[None])[0]

def FindArmature(obj):
    return obj.parent if obj.parent and obj.parent.type=='ARMATURE' else None
def FindAllArmatures(obj):
    rig = FindArmature(obj)
    return (
        [x for x in [rig]+list(rig.children) if x.type=='ARMATURE'] if FindArmature(obj) else
        [m.object for m in obj.modifiers if m.type=='ARMATURE']
    )

def ClipName(name):
    return name.split("/")[-1].split(".")[0]

def FixName(name):
    return "".join([x if x.lower() in "qwertyuiopasdfghjklzxcvbnm1234567890" else "_" for x in name.replace('DEF-', "")])

def ValidName(name):
    return (
        name[0].lower() in "qwertyuiopasdfghjklzxcvbnm1234567890" and
        name[:4] != 'WGTS' and
        ClipName(name)[0].lower() in "qwertyuiopasdfghjklzxcvbnm1234567890"
    )

def MaskVectorStr(maskboolvector):
    return "0b"+"".join(["01"[x] for i,x in enumerate(maskboolvector[:int(bpy.context.scene.vbm.layer_mask_display_size)])])

def LayermaskToInt(maskboolvector):
    return sum([int(1<<i) for i,x in enumerate(maskboolvector[:int(bpy.context.scene.vbm.layer_mask_display_size)]) if x])
def IntToLayermask(layer_mask):
    return tuple([1 if (1<<i)&layer_mask else 0 for i in range(0, int(bpy.context.scene.vbm.layer_mask_display_size))])
def LayermaskText(layer_mask):
    n = int(bpy.context.scene.vbm.layer_mask_display_size)
    if isinstance(layer_mask, int):
        return "".join(["|" if (1<<i)&layer_mask else "`" for i in range(0, n)])
    else:
        return "".join(["|" if layer_mask[i] else "`" for i in range(0, n)])

LayerCollections = lambda c, outdict: (outdict.update({c.name: c}), [LayerCollections(child, outdict) for child in c.children], outdict)[-1] 
LayerCollection = lambda c: LayerCollections(bpy.context.view_layer.layer_collection, {})[c.name]
def SelectCollection(collection):
    bpy.context.view_layer.active_layer_collection = LayerCollections(bpy.context.view_layer.layer_collection, {})[collection.name]

def ActionChannels(action):
    # Grab curves from first action slot
    return action.layers[0].strips[0].channelbag(action.slots[0]).fcurves
# ..........................................................................
def EvaluateDeformParent(armature_object, bone):
    bones = armature_object.data.bones
    p = bone.parent
    usedparents = []
    if p and not p.use_deform:
        while p and not p.use_deform:
            usedparents.append(p)
            d = bones.get(p.name.replace('ORG-', 'DEF-'))
            p = d if (d and d != bone and (d.use_deform or d not in usedparents)) else p.parent
    return p
    
def EvaluateDeformOrder(armature_object, sort_by_depth=False):
    if not armature_object:
        return ([], {}, {})
    
    # All -> Deform Only
    deformmap = {}
    deformbones = [b for b in armature_object.data.bones if b.use_deform]
    for b in deformbones:
        p = EvaluateDeformParent(armature_object, b)
        deformmap[b.name] = p.name if p else None
    
    # Calculate order based on parents
    deformorder = []
    DeformWalk = lambda bname: (deformorder.append(bname), [DeformWalk(child) for child in [k for k,p in list(deformmap.items()) if p==bname]])
    [DeformWalk(bname) for bname,p in deformmap.items() if not p]
    
    # Sort by depth to minimize parent switches
    BoneDepth = lambda bname, deformmap: (1+BoneDepth(deformmap[bname], deformmap)) if deformmap[bname] else 0
    deformlist = list(deformorder)
    if sort_by_depth:
        deformlist.sort(key=lambda bname: BoneDepth(bname, deformmap))
    
    armature_object.vbm['DEFORM_MAP'] = {bname: (deformmap[bname] if deformmap.get(bname, None) else None) for bname in deformorder} # {bonename: parentname}
    armature_object.vbm['DEFORM_LIST'] = deformlist   # [0, first_bone, second_bone, ...]
    armature_object.vbm['DEFORM_ROUTE'] = {bname: bname for bname in deformorder}    # {sourcename: bonename}
    return (list(armature_object.vbm['DEFORM_LIST']), armature_object.vbm['DEFORM_MAP'], armature_object.vbm['DEFORM_ROUTE'])

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
    action: PointerProperty(name="Action", type=bpy.types.Action, description="Action")
    export_enabled: BoolProperty(name="Export Enabled", default=1, options=set(), description="Include action on export")
classlist.append(VBM_PG_ActionItem)

# ---------------------------------------------------------------------------------------------------------
class VBM_PG_Image(bpy.types.PropertyGroup):
    def get_image(self):
        return [x for x in bpy.data.images if x.vbm == self][0]
        
    def pad_pixels(self, save=False, alpha_threshold=0.99):
        # Modified image filtering code of IMB_filter_extend() from Blender source:
        # https://github.com/blender/blender/blob/main/source/blender/imbuf/intern/filter.cc#L200
        
        image = self.get_image()
        print("> Padding pixels for image \"%s\"" % image.name)
        exec_time = time.time_ns()
        w,h = image.size
        n = w*h
        iterations = 256
        clipping = 0
        irange = tuple(range(0, n))
        irange = tuple([w*y+x for y in range(1,h-1) for x in range(1,w-1)])
        
        print("> Staging...")
        outpixels = np.frombuffer( ((255.0*np.array(tuple(image.pixels))).astype(np.uint8)).tobytes(), dtype=np.uint32)
        
        print("%8x" % outpixels[0])
        
        use_alpha = sum([(x>>24) != 0xFF for x in outpixels]) > 0
        if use_alpha:
            threshold = int(0xFF * (1.0-alpha_threshold))
            clipping += bpy.context.scene.cycles.use_denoising
            print("> > Culling Alpha (T = %2.2f (%2x))..." % (alpha_threshold, threshold))
            outpixels = np.array([x if ((x>>24) > threshold) else 0 for x in outpixels], dtype=np.uint32)   # Cull Alpha
        elif outpixels[0] in (0xFFFF8080, 0xFFFF7F7F):
            print("> > Culling Normal...")
            outpixels = np.array([0 if (x==0xFFFF8080 or x==0xFFFF7F7F) else x for x in outpixels], dtype=np.uint32)   # Cull Normal
        else:
            print("> > Culling Black...")
            outpixels = np.array([x if (x & 0x00FFFFFF) != 0 else 0 for x in outpixels], dtype=np.uint32)   # Cull Black
        srcpixels = []
        assigned = np.array([x > 0 for x in outpixels], dtype=bool)    # Black Only
        tmp = 0
        
        if clipping:
            print("> Clipping Pass (C = %d)..." % clipping, end='')
            t = time.time_ns()
            for r in range(0, clipping):
                newassigned = np.array(assigned, dtype=bool)
                for index in irange:
                    if assigned[index]:
                        x = index % w
                        y = index // w
                        # Check if adjacent pixels have NOT been assigned
                        if (
                            (not assigned[y*w+(x-1)]) or
                            (not assigned[y*w+(x+1)]) or
                            (not assigned[(y-1)*w+x]) or
                            (not assigned[(y+1)*w+x])
                        ):
                            newassigned[index] = False
                assigned = newassigned
            outpixels = np.array([x if assigned[i] else 0 for i,x in enumerate(outpixels)], dtype=np.uint32)
            print(" | (%2.2f sec)" % ((time.time_ns()-t) / (1_000_000_000)) )
        
        print("> Padding Pass...")
        row_complete = np.array([False for y in range(0, h)], dtype=bool)
        for r in range(0, iterations):
            if (r % 10) == 0:
                print("> > Iteration %3d/%3d | Rows = %3d/%3d..." % (r, iterations, sum(row_complete), len(row_complete)))
            srcpixels = outpixels
            outpixels = np.array(srcpixels)
            
            for y in range(1, h-1):
                if row_complete[y]:
                    continue
                xhits = 0
                for x in range(1, w-1):
                    index = w*y+x
                    if assigned[index]:
                        xhits += 1
                    else:
                        # Check if adjacent pixels have been assigned
                        if (
                            (assigned[y*w+(x-1)]) or
                            (assigned[y*w+(x+1)]) or
                            (assigned[(y-1)*w+x]) or
                            (assigned[(y+1)*w+x])
                        ):
                            # Test around active pixel
                            for i,j in ( (-1,0), (1,0), (0,-1), (0,1) ):
                                tmpindex = (y+j)*w+(x+i)
                                if assigned[tmpindex]:
                                    tmp = srcpixels[tmpindex]
                            if tmp != 0:
                                outpixels[index] = tmp
                                assigned[index] = True
                                tmp = 0
                # Mark row as complete
                row_complete[y] = (xhits >= w-2)
            if sum(row_complete) >= h-2:
                break
        
        print("> Edge Pass...")
        for y in range(0, h):
            outpixels[w*y+0] = outpixels[w*y+1]
            outpixels[w*y+w-2] = outpixels[w*y+w-1]
        for x in range(0, w):
            outpixels[x] = outpixels[x+w]
            outpixels[n-x-1] = outpixels[n-x-1-w]
        
        print("> Exec time:", (time.time_ns()-exec_time) / (1_000_000_000))
        image.pixels = (np.frombuffer(np.array(outpixels, dtype=np.uint32).tobytes(), dtype=np.uint8).astype(np.float32)/255.0)
        
        if save:
            print("> Saving...")
            if image.packed_file:
                image.pack()
            elif image.filepath:
                image.save()
classlist.append(VBM_PG_Image)

class VBM_PG_Material(bpy.types.PropertyGroup):
    def get_material(self):
        return [mtl for mtl in bpy.data.materials if mtl.vbm==self][0]
    def get_shader(self):
        return self.shader if self.shader else bpy.context.scene.vbm.shader_default
    def get_imagenodes(self):
        mtl = self.get_material()
        imagenodes = [None]*VBM_MATERIALTEXTURECOUNT
        for i in range(0, VBM_MATERIALTEXTURECOUNT):
            nd = mtl.node_tree.nodes.get('TEXTURE%d'%i, None)
            if not nd:
                nd = mtl.node_tree.nodes.get('Image Texture' if i==0 else ('Image Texture.%03d'%i))
            imagenodes[i] = nd
        return imagenodes
    
    def update_shader(self, context):
        if self.shader != self.get('_lastshadername', ""):
            self['_lastshadername'] = self.shader
            context.scene.vbm.update_shadernames()
    
    shader: StringProperty(name="Shader", default="", description="Name of shader asset", update=update_shader)
    transparent: BoolProperty(name="Is Transparent", default=False, options=set(), description="Sets transparency flag on export")
    flip_faces: BoolProperty(name="Flip Faces", default=False, options=set(), description="Sets flip faces flag on export")
    use_depth: BoolProperty(name="Use Depth", default=True, options=set(), description="Enable depth when rendering")
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
        frame_rate = int(self.frame_rate)
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
    frame_rate: EnumProperty(items=Items_Framerate, default='60', update=update_action)
    
    clean_on_bake: BoolProperty(name="Clean On Bake", default=True, description="Cleans curves on bake to reduce frame count")
    
    layer_mask: BoolVectorProperty(
        name="Layer Mask", 
        size=VBM_LAYERMASKSIZE, 
        default=[True for i in range(0,VBM_LAYERMASKSIZE)],
        description="Bone curves in layer mask will be exported. Use 'Bone Groups' tab to set bone layer masks."
    )
    
    layermask: BoolVectorProperty(size=VBM_LAYERMASKSIZE, default=[i==0 for i in range(0,VBM_LAYERMASKSIZE)], description="old identifier for \"layer_mask\"")
classlist.append(VBM_PG_Action)

class VBM_PG_Object(bpy.types.PropertyGroup):
    export_enabled: BoolProperty(name="Export Enabled", default=True)
    script_id: StringProperty(name="Script ID", default="")
    is_collision: BoolProperty(name="Is Collision", default=False, options=set(), description="Export object as Prism type in file")
    layer_mask: BoolVectorProperty(name="Layer Mask", size=VBM_LAYERMASKSIZE, default=[i==0 for i in range(0,VBM_LAYERMASKSIZE)])
    
    layermask: BoolVectorProperty(size=VBM_LAYERMASKSIZE, default=[i==0 for i in range(0,VBM_LAYERMASKSIZE)], description="old identifier for \"layer_mask\"")
classlist.append(VBM_PG_Object)

# -----------------------------------------------------------------------------------------------------
class VBM_PG_SwingboneSegment(bpy.types.PropertyGroup):
    start_bone: StringProperty(name="Start Bone")
    end_bone: StringProperty(name="End Bone")
classlist.append(VBM_PG_SwingboneSegment)

class VBM_PG_Swingbone(bpy.types.PropertyGroup):
    def add_segment(self, start_bone, end_bone=""):
        usedbones = [x for s in self.segments for x in (s.start_bone+s.end_bone, s.end_bone+s.start_bone)]
        if start_bone+end_bone not in usedbones:
            segment = self.segments.add()
            segment.start_bone = start_bone
            segment.end_bone = end_bone
    
    def get_bone_count(self):
        return len(self.bones)
    
    name: StringProperty(default="s_bone")
    export_enabled: BoolProperty(name="Export Enabled", default=True)
    swing_enabled: BoolProperty(name="Swing Enabled", default=False)
    add_leaf_bones: BoolProperty(name="Add Leaf Bones", default=False, description="Add leaf bones to end of bone chains on export")
    stiffness: FloatProperty(name="Stiffness", default=0.1, min=0.0, max=1.0, subtype='FACTOR', description="Speed that bone approaches goal")
    damping: FloatProperty(name="Damping", default=0.3, min=0.0, max=1.0, subtype='FACTOR', description="Controls particle distance from goal")
    limit: FloatProperty(name="Limit", default=0.8, min=0.0, max=1.0, subtype='FACTOR', description="Limits maximum rotation")
    force_strength: FloatProperty(name="Force Strength", default=1.0, min=0.0, max=1.0, subtype='FACTOR', description="Amount of influence by forces such as gravity")
    radius: FloatProperty(name="Radius", default=0.0, min=0.0, subtype='DISTANCE')
    show_bones: BoolProperty(name="Show Bones", default=True, description="Show bone visuals")
    
    bones: CollectionProperty(name="Bones", type=VBM_PG_Label)
    segments: CollectionProperty(name="Segments", type=VBM_PG_SwingboneSegment)
    
    bone_index: IntProperty(name="Bone Index", min=0)
    segment_index: IntProperty(name="Bone Index", min=0)
    layer_mask: BoolVectorProperty(
        name="Layer Mask", 
        size=VBM_LAYERMASKSIZE, 
        default=[i==0 for i in range(0,VBM_LAYERMASKSIZE)]
    )
    collision_mask: BoolVectorProperty(
        name="Collision Mask", 
        size=VBM_LAYERMASKSIZE, 
        default=[i==0 for i in range(0,VBM_LAYERMASKSIZE)], 
        description="Layer of other bones that this group can collide with"
    )
    
    layermask: BoolVectorProperty(size=VBM_LAYERMASKSIZE, default=[i==0 for i in range(0,VBM_LAYERMASKSIZE)], description="old identifier for \"layer_mask\"")
classlist.append(VBM_PG_Swingbone)

# -----------------------------------------------------------------------------------------------------
class VBM_PG_Collection(bpy.types.PropertyGroup):
    def export(self):
        def Walk_ExportCollection(collection):
            hits = 0
            if collection.vbm.enabled:
                ExportModel(collection, report=False)
                hits += 1
            for c in collection.children:
                hits += Walk_ExportCollection(c)
            return hits
        
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
    def get_rig(self):
        return ([x for x in self.get_collection().all_objects if x.type=='ARMATURE' and x.children]+[None])[0]
    def get_file_count(self):
        return len([x for x in self.get_collection().children_recursive if x.vbm.enabled])
    
    def select_action(self, context):
        if self.actions:
            rig = self.get_rig()
            if rig:
                action = self.actions[self.action_index].action
                rig.animation_data.action = action
                rig.animation_data.action_slot = action.slots[0]
                action.vbm.update_action(context)
    def update_pose_action(self, context):
        if self.action_pose:
            rig = self.get_rig()
            if rig:
                rig.animation_data.action = self.action_pose
                rig.animation_data.action_slot = self.action_pose.slots[0]
    
    def sort_actions(self):
        order = [x.action for x in self.actions]
        order.sort(key=lambda x: x.name)
        [self.actions.move([x.action for x in self.actions].index(action), 0) for action in order[::-1]]
    
    def sort(self):
        collection = self.get_collection()
        objects = list(collection.objects)
        objects.sort(key=lambda obj: ("z" if not ValidName(obj.name[0]) else "") + obj.type + obj.name)
        [collection.objects.unlink(obj) for obj in objects]
        [collection.objects.link(obj) for obj in objects]
    
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
            imagenodes = mtl.vbm.get_imagenodes()
            for i,nd in enumerate(imagenodes):
                if nd:
                    nd.name = "TEXTURE%d" % i
    
    def get_materials(self):
        collection = self.get_collection()
        materials = list(set([mtl for obj in collection.all_objects if obj.type=='MESH' for mtl in obj.data.materials if mtl]))
        materials += [mtl for item in self.material_overrides for mtl in (item.material, item.override) if mtl]
        return list(set(materials))
    
    def get_material_override(self, material):
        for item in self.material_overrides:
            if item.material == material and item.override:
                return item.override
        return material
    
    def add_material_override(self, material, override=None):
        if material in [x.material for x in self.material_overrides]:
            return
        item = self.material_overrides.add()
        item.material = material
        item.override = override
    
    def find_bonegroup(self, bonename):
        for bone_group in self.bone_groups:
            if bonename in list(bone_group.bones.keys()):
                return bone_group
        return None
    
    def get_bone_layer_mask(self, bonename):
        layervector = self.bone_layer_mask_default
        bone_group = self.find_bonegroup(bonename)
        if bone_group:
            layervector = bone_group.layer_mask
        return LayermaskToInt(layervector)
        
    def get_format_mask(self):
        return sum([1<<i for i,x in enumerate(self.format) if x]) // 1
    
    def get_format_stride(self):
        format_mask = self.get_format_mask()
        return sum([ATTRIBUTE_LENGTH[a]*(4,1)[(1>>(a+16))!=0] for a in range(0, ATTRIBUTE_MAX) if 1<<a])
    
    def update_format(self, context):
        if sum(self.format[:16]) == 0:
            format = [0]*32
            collection = self.get_collection()
            format[ATTRIBUTE_INDEX['POS']] = 1
            format[ATTRIBUTE_INDEX['COL']] = 1
            format[ATTRIBUTE_INDEX['COL']+16] = 1
            format[ATTRIBUTE_INDEX['UVS']] = 1
            
            if self.get_rig():
                format[ATTRIBUTE_INDEX['BON']] = 1
                format[ATTRIBUTE_INDEX['BON']+16] = 1
                format[ATTRIBUTE_INDEX['WEI']] = 1
                format[ATTRIBUTE_INDEX['WEI']+16] = 1
            self.format = [x > 0 for x in format]
    
    
    def update_name(self, context):
        if not self.name:
            return
        if self.name[-1] in "/\"":
            self.name += self.get_collection().name
        
    name: StringProperty(default="", options=set(), subtype='FILE_PATH', update=update_name)
    
    format: BoolVectorProperty(
        name="Vertex Format", size=32, options=set(), default=tuple([((1<<i)&ATTRIBUTE_DEFAULTMASK) != 0 for i in range(0, 32)]), update=update_format,   # [0:15] = Attribute, [16:31] = Is byte
        description="Order of vertex attributes to write buffer with:\nPosition, Normal, Tangent, Bitangent, Color, UVs, UV2, Bone, Weight, Group\n[ F ]: Float, [ B ] = Bytes\nHighlight and press [Backspace] to reset to default"
    )
    
    enabled: BoolProperty(default=False, name="Export as File")
    object_index: IntProperty(name="Object Index", default=0, min=0, options=set(), description="Exported name is the text following the last \"/\" \nEx: \"Chara/body\" -> \"body\"")
    
    export_meshes: BoolProperty(name="Export Meshes", default=True, options=set(), description="Include meshes on export")
    export_skeleton: BoolProperty(name="Export Skeleton", default=True, options=set(), description="Include skeleton bones on export")
    export_materials: BoolProperty(name="Export Materials", default=True, options=set(), description="Include material data on export")
    export_textures: BoolProperty(name="Export Textures", default=True, options=set(), description="Include textures on export")
    export_animations: BoolProperty(name="Export Animations", default=True, options=set(), description="Include animations on export")
    
    clip_object_name: BoolProperty(name="Clip Object Names", default=True, options=set(), description="Splits object name on export \n\"Poppie/body.001\" -> \"body\"")
    clip_action_name: BoolProperty(name="Clip Action Names", default=True, options=set(), description="Splits action name on export \n\"Poppie/run.005\" -> \"run\"")
    
    actions: CollectionProperty(type=VBM_PG_ActionItem)
    action_index: IntProperty(name="Collection Action", min=0, update=select_action, options=set(), description="Select an Action to preview using the first compatible rig in Collection")
    action_pose: PointerProperty(name="Rest Pose", type=bpy.types.Action, update=update_pose_action, description="Base Pose to deform mesh with. Leave disabled if using animations")
    
    children: CollectionProperty(options={'HIDDEN'}, type=VBM_PG_CollectionItem)
    child_index: IntProperty(min=0, options=set())
    
    use_vtx_compression: BoolProperty(name="Compress Vertex Buffer", default=False, description="Write vertex buffer as indices to a value map, instead of a flat chunk of bytes. \nVERY SLOW.")
    use_compression: BoolProperty(name="Compress File", default=False, description="Compress file using zlib compression to reduce file size")
    
    use_material_names: BoolProperty(name="Use Mtl Names", default=False, description="Append material name to name of object on export")
    mesh_join_type: EnumProperty(name="Join Type", default='NONE', items=Items_MeshJoinType, description="Method to join meshes in collection")
    
    color_layer_name: StringProperty(name="VC Layer Name", default="", options=set(), description="Vertex color layer to use on export. Uses 'Color' if empty")
    color_layer_name2: StringProperty(name="VC Layer Name", default="", options=set(), description="Vertex color layer to use on export. Uses 'Color' if empty")
    color_layer_default: FloatVectorProperty(name="VC Layer Default", size=4, default=(1,1,1,1), min=0, max=1.0, subtype='COLOR_GAMMA', options=set(), description="Default vertex color if vc layer name is set but not found")
    color_layer_default2: FloatVectorProperty(name="VC Layer Default", size=4, default=(1,1,1,1), min=0, max=1.0, subtype='COLOR_GAMMA', options=set(), description="Default vertex color if vc layer name is set but not found")
    color_is_srgb: BoolProperty(name="VC sRGB", default=True, options=set(), description="Applies gamma correction to colors if true, otherwise leaves as is")
    color_is_srgb2: BoolProperty(name="VC sRGB", default=True, options=set(), description="Applies gamma correction to colors if true, otherwise leaves as is")
    
    uv_layer_name: StringProperty(name="UV Layer Name", default="", options=set(), description="UV layer to use on export. Uses 'UVMap' if empty")
    uv_layer_name2: StringProperty(name="UV Layer Name", default="", options=set(), description="UV layer to use on export. Uses 'UVMap' if empty")
    uv_layer_default: FloatVectorProperty(name="UV Layer Default", size=2, default=(1,1), options=set(), description="Default uv value if uv layer name is set but not found")
    uv_layer_default2: FloatVectorProperty(name="UV Layer Default", size=2, default=(1,1), options=set(), description="Default uv value if uv layer name is set but not found")
    
    normal_w_name: StringProperty(name="Normal.w Group", default="", options=set(), description="Vertex group to use as normal's w coordinate.")
    normal_w_value: StringProperty(name="Normal.w Value", default="", options=set(), description="Value to use as normal's w coordinate if group is not found.")
    
    object_script_pre: PointerProperty(name="Object Pre Script", type=bpy.types.Text, 
        description="Internal python script to run before applying modifiers. \ncontext.scene['%s'] is set as a mutex before executing" % VBM_SCRIPTISEXPORTING)
    object_script_post: PointerProperty(name="Object Post Script", type=bpy.types.Text, 
        description="Internal python script to run after applying modifiers. \ncontext.scene['%s'] is set as a mutex before executing" % VBM_SCRIPTISEXPORTING)
    object_add_root: BoolProperty(name="Add Root Object", default=False, options=set(), description="Add root object to node tree on export")
    object_flatten: BoolProperty(name="Flatten Hierarchy", default=False, options=set(), description="Flatten object hierarchy, applying all matrices")
    
    bone_groups: CollectionProperty(name="Bone Groups", type=VBM_PG_Swingbone, options=set())
    bone_group_index: IntProperty(min=0, options=set())
    bone_add_root: BoolProperty(name="Add Root Bone", default=False, options=set(), description="Add root bone to armature on export")
    
    material_overrides: CollectionProperty(name="Material Overrides", type=VBM_PG_MaterialOverride, options=set())
    material_override_index: IntProperty(min=0, options=set())
    
    texture_slot_index: IntProperty(name="Texture Slot Index", min=0, options=set())
    
    bone_layer_mask_default: BoolVectorProperty(
        name="Bone Layer Mask Default", 
        size=VBM_LAYERMASKSIZE, 
        default=[i==0 for i in range(0,VBM_LAYERMASKSIZE)], 
        options=set(),
        description="Default layer mask for bones not in a bone_group bone group"
    )
classlist.append(VBM_PG_Collection)

# ------------------------------------------------------------------------------
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
            printd("> VBM Collection Refresh")
            context.scene.collection.vbm.refresh()
            self['VBM_CHECKSUM'] = checksum
    
    def update_shadernames(self):
        [self.shader_names.remove(0) for x in self.shader_names]
        usednames = list(set([self.shader_default]+[mtl.vbm.shader for mtl in bpy.data.materials if not mtl.is_grease_pencil]))
        for x in usednames:
            if x:
                self.shader_names.add().name = x
    
    data_path: StringProperty(name="Data Path", default="", subtype='DIR_PATH', update=update_datapath)
    layer_mask_display_size: EnumProperty(name="Mask Display Size", items=Items_LayermaskSize, default='8', options=set(), description="Number of layer mask bits to display")
    layer_mask_display_reverse: BoolProperty(name="Mask Display Reversed", default=True, options=set(), description="Display layer mask bits reversed \n(Matches boolean constants like 0b1000_0000)")
    
    show_swing_viewport_panel: BoolProperty(name="Viewport Swing Panel", default=True, options=set(), description="Show Swing Panel in 3D Viewport")
    show_extra_info: BoolProperty(name="Extended Info", default=False, options=set(), description="Show extra info in item lists")
    show_swing_bones: BoolProperty(name="Show Swing Bones", default=True, options=set(), description="Show swing bone visuals as defined in Bone Groups panel")
    show_swing_segments: BoolProperty(name="Show Swing Segments", default=True, options=set(), description="Show swing bone visuals as defined in Bone Groups panel")
    show_modifier_bake: BoolProperty(name="Show Modifier Bake", default=VBM_SHOWMODIFIERBAKE, options=set(), 
        description="Show option to bake modifiers in modifier tab.\nToggle under Scene Properties > DmrVBM > Settings Panel (Cog Icon)")
    swing_tab: EnumProperty(name="Swing Tab", default='SWING', options=set(), items=tuple([
        ('SWING', "Parameters", "Swing Parameters"),
        ('BONE', "Bones", "Bones"),
        ('SEGMENT', "Segments", "Segments"),
    ]))
    
    shader_default: StringProperty(name="Default Shader", default="DEFAULT", options=set(), description="Default shader name for materials.")
    shader_names: CollectionProperty(name="Shader Names", type=VBM_PG_Label)
    
    panel_tab: EnumProperty(name="VBM Tab", default=1, update=refresh_collection, items=tuple([
        ('SCENE', "", "Scnene settings", 'PREFERENCES', 0),
        ('COLLECTION', "CLL", "Collection settings", 'OUTLINER_COLLECTION', 1),
        ('OBJECT', "OBJ", "Collection object settings", 'OBJECT_DATA', 2),
        ('MATERIAL', "MTL", "Material settings", 'MATERIAL_DATA', 3),
        ('ACTION', "ANI", "Action settings", 'ACTION', 4),
        ('SWING', "SWG", "Rig Bone settings", 'CON_SPLINEIK', 5),
    ]))
    express_export: BoolProperty(name="Express Export", default=False, options=set())
    compress_model_files: BoolProperty(name="Compress on Export", default=False, options=set())
    print_debug: BoolProperty(name="Print Debug Info", default=False, options=set(), description="Print debug info to console during operations")
classlist.append(VBM_PG_Scene)

"======================================================================================================"
"OPERATORS"
"======================================================================================================"

# -------------------------------------------------------------------------------------------------------
class VBM_OT_BakeForPlayback(bpy.types.Operator):
    bl_idname, bl_label, bl_options = ('vbm.bake_geometry_nodes', "Bake For Playback", {'REGISTER', 'UNDO'})
    bl_description = "Bake Modifiers up to Armature for selected objects to speed up animation playback.\nNon-destructive-- Disables and remembers visibility of modifiers when executed"
    revert: BoolProperty(name="Revert", default=False, description="Restore previous bake state")
    
    @classmethod
    def poll(self, context):
        return context.object and context.object.type in ['MESH']
    
    def execute(self, context):
        VBM_BAKESTATEKEY = 'VBM_BAKESTATE'
        VBM_BAKENODETAG = 'VBM_BAKETAG'
        
        mode = context.object.mode
        bpy.ops.object.mode_set(mode='OBJECT')
        objects = [obj for obj in context.selected_objects if obj.type=='MESH']
        
        IsBakeModifier = lambda m: m.type == 'NODES' and sum([VBM_BAKENODETAG in nd.name for nd in m.node_group.nodes])
        
        if len(objects) == 0:
            self.report({'WARNING'}, "> No objects selected")
            return {'FINISHED'}
        [print(obj.name) for obj in objects]
        
        # Generate Bake Node
        hits = 0
        hits_clear = 0
        for obj in objects:
            if obj.type != 'MESH':
                continue
            obj.data.update()
            
            # Clear Last Bake
            bakemod = ([m for m in obj.modifiers if m.type=='NODES' and sum([VBM_BAKENODETAG in nd.name for nd in m.node_group.nodes])]+[None])[0]
            if bakemod and bakemod.bakes:
                bakemod.show_viewport=True
                bakemod.show_in_editmode=True
                for bake in bakemod.bakes:
                    bpy.ops.object.geometry_node_bake_delete_single(
                        modifier_name=bakemod.name,
                        session_uid=bake.id_data.session_uid,
                        bake_id=bake.bake_id,
                    )
                bakemod.show_viewport=False
                hits_clear += 1
            
            # Restore Previous Bakestate State
            bakestate = obj.get(VBM_BAKESTATEKEY, {})
            for m in obj.modifiers:
                m.show_viewport = bakestate.get(str(m.persistent_uid), m.show_viewport)
            obj[VBM_BAKESTATEKEY] = {}
            
            lastbakegroups = [m.node_group for m in list(obj.modifiers) if IsBakeModifier(m)]
            [obj.modifiers.remove(m) for m in list(obj.modifiers)[::-1] if IsBakeModifier(m)]
            [bpy.data.node_groups.remove(x) for x in lastbakegroups]
            
            # Bake
            if not self.revert:
                # Create Node Group
                bakenodetree = bpy.data.node_groups.new(".VBM_BAKE-"+obj.name, 'GeometryNodeTree')
                [bakenodetree.nodes.remove(nd) for nd in list(bakenodetree.nodes)[::-1]]
                bakenodetree.interface.clear()
                
                bakenodetree.interface.new_socket(name="Geometry", in_out='INPUT', socket_type='NodeSocketGeometry')
                bakenodetree.interface.new_socket(name="Geometry", in_out='OUTPUT', socket_type='NodeSocketGeometry')
                ndbake = bakenodetree.nodes.new('GeometryNodeBake')
                ndbake.name = VBM_BAKENODETAG
                ndoutput = bakenodetree.nodes.new('NodeGroupOutput')
                ndinput = bakenodetree.nodes.new('NodeGroupInput')
                ndbake.location = (-300, 0)
                ndinput.location = (-600, 0)
                if BLENDER_5_0:
                    ndbake.bake_items.new('GEOMETRY', 'Bake')
                bakenodetree.links.new(ndbake.inputs[0], ndinput.outputs[0])
                bakenodetree.links.new(ndoutput.inputs[0], ndbake.outputs[0])
                
                # Add Node Group
                bakemod = obj.modifiers.new(name="~VBM_Bake", type='NODES')
                bakemod.node_group = bakenodetree
                for i,m in list(enumerate(obj.modifiers))[::-1]:
                    if m.type=='ARMATURE':
                        obj.modifiers.move(list(obj.modifiers).index(bakemod), i)
                
                modifier_index = list(obj.modifiers).index(bakemod)
                bakemod.show_viewport=True
                bakemod.show_in_editmode=True
                bakemod.show_expanded=False
                for bake in bakemod.bakes:
                    bpy.ops.object.geometry_node_bake_single(
                        modifier_name=bakemod.name,
                        session_uid=bake.id_data.session_uid,
                        bake_id=bake.bake_id,
                    )
                obj[VBM_BAKESTATEKEY] = {str(x.persistent_uid): x.show_viewport for x in list(obj.modifiers)[:modifier_index]}
                hits += 1
                for m in list(obj.modifiers)[:modifier_index]:
                    m.show_viewport=False
        
        if self.revert:
            self.report({'INFO'}, "Hits: %d" % hits_clear)
        else:
            self.report({'INFO'}, "Hits: %d" % hits)
            
        bpy.ops.object.mode_set(mode=mode)
        return {'FINISHED'}
classlist.append(VBM_OT_BakeForPlayback)

class VBM_OT_RestoreLayermask(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.restore_layer_mask', 'Fix Layer Masks', {'REGISTER', 'UNDO'}
    bl_description = "Fix layer mask values from previous VBM update"
    def execute(self, context):
        hits = 0
        for x in bpy.data.actions:
            if sum(x.vbm.layermask) != 0:
                hits += 1
                x.vbm.layer_mask = x.vbm.layermask
                x.vbm.layermask = tuple([False]*32)
        for x in bpy.data.objects:
            if sum(x.vbm.layermask) != 0:
                hits += 1
                x.vbm.layer_mask = x.vbm.layermask
                x.vbm.layermask = tuple([False]*32)
        for collection in bpy.data.collections:
            for x in collection.vbm.bone_groups:
                if sum(x.layermask) != 0:
                    hits += 1
                    x.layer_mask = x.layermask
                    x.layermask = tuple([False]*32)
        
        self.report({'INFO'}, "%d hits" % hits)
        return {'FINISHED'}
classlist.append(VBM_OT_RestoreLayermask)

def VBM_ClearChecksum(id_type, pattern='VBM_'):
    hit = 0
    for k in tuple(id_type.keys())[::-1]:
        if pattern in k:
            del id_type[k]
            hit = 1
    if getattr(id_type, 'vbm', None) != None:
        for k in tuple(id_type.vbm.keys())[::-1]:
            if pattern in k:
                del id_type.vbm[k]
                hit = 1
    return hit
    
class VBM_OT_ObjectClearChecksum(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.object_clear_checksum', 'VBM Clear Object Checksum', {'REGISTER', 'UNDO'}
    bl_description = "Clears cache for object"
    object: StringProperty(name="Object", default="") 
    def execute(self, context):
        obj = bpy.data.objects.get(self.object)
        if obj:
            VBM_ClearChecksum(obj)
            if obj.data:
                VBM_ClearChecksum(obj.data)
            self.report({'INFO'}, "> Checksum cleared for object \"%s\"" % obj.name)
        return {'FINISHED'}
classlist.append(VBM_OT_ObjectClearChecksum)

class VBM_OT_CollectionClearChecksum(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_clear_checksum', 'VBM Clear Collection Checksum', {'REGISTER', 'UNDO'}
    bl_description = "VBM Resets cache for group in collection"
    group: EnumProperty(default='NONE', items=tuple([(x,x,x) for x in 'NONE OBJECT ACTION IMAGE COLLECTION ALL'.split()])) 
    def execute(self, context):
        collection = ActiveCollection()
        hits = 0
        for item in (
            [collection] if self.group == 'COLLECTION' else
            [x for x in collection.all_objects] if self.group == 'OBJECT' else
            [x.action for x in collection.vbm.actions] if self.group == 'ACTION' else
            list(set([nd.image for obj in collection.all_objects if obj.type=='MESH' for mtl in obj.data.materials if mtl for nd in mtl.node_tree.nodes if nd.bl_idname=='ShaderNodeTexImage' and nd.image])) if self.group == 'IMAGE' else
            []
        ):
            hits += VBM_ClearChecksum(item)
        self.report({'INFO'}, "%d hits" % hits)
        SelectCollection(collection)
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionClearChecksum)

class VBM_OT_CollectionSortObjects(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.sort_objects', "VBM Sort Objects", {'REGISTER', 'UNDO'}
    def execute(self, context):
        ActiveCollection().vbm.sort()
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionSortObjects)

class VBM_OT_CollectionRenameObjects(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.rename_objects', "VBM Rename Objects", {'REGISTER', 'UNDO'}
    bl_description = "Renames objects to \"<collectionname>/<objectname>\" and trims chars after \".\""
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
    bl_description = "Moves object up or down in collection"
    direction: EnumProperty(name="Direction", items=tuple([(x,x,x) for x in 'UP DOWN'.split()]))
    def execute(self, context):
        collection = ActiveCollection()
        objects = list(collection.objects)
        index = collection.vbm.object_index
        if self.direction == 'UP' and index > 0:
            order = [objects[(i-1) if i==index else (i+1) if i==index-1 else i] for i in range(0,len(objects))]
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
    bl_idname, bl_label, bl_options = 'vbm.collection_action_add', 'Add Action', {'REGISTER', 'UNDO'}
    bl_description = "Adds action item to action list"
    def execute(self, context):
        collection = ActiveCollection()
        collection.vbm.actions.add().action
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionAddAction)

class VBM_OT_CollectionPushAction(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_action_push', 'Push Action', {'REGISTER', 'UNDO'}
    bl_description = "Pushes action from active rig to action list"
    def execute(self, context):
        collection = ActiveCollection()
        rig = collection.vbm.get_rig()
        action = rig.animation_data.action
        if action not in [x.action for x in collection.vbm.actions]:
            collection.vbm.actions.add().action = action
            collection.vbm.action_index = len(collection.vbm.actions)-1
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionPushAction)

class VBM_OT_CollectionRemoveAction(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_action_remove', 'Remove Action', {'REGISTER', 'UNDO'}
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
    bl_idname, bl_label, bl_options = 'vbm.collection_action_sort', 'Sort Actions', {'REGISTER', 'UNDO'}
    def execute(self, context):
        collection = ActiveCollection()
        collection.vbm.sort_actions()
        SelectCollection(collection)
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionActionSort)

class VBM_OT_CollectionMaterialFix(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_material_fix', 'Fix Materials', {'REGISTER', 'UNDO'}
    bl_description = "Aligns material nodes to output node and renames texture nodes to their index on export"
    def execute(self, context):
        collection = ActiveCollection()
        collection.vbm.fix_materials()
        SelectCollection(collection)
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionMaterialFix)

# -----------------------------------------------------------------------------
class VBM_OT_CollectionAddBonegroup(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_bonegroup_add', 'Add Bone Group', {'REGISTER', 'UNDO'}
    def execute(self, context):
        collection = ActiveCollection()
        bone_group = collection.vbm.bone_groups.add()
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionAddBonegroup)

class VBM_OT_CollectionRemoveBonegroup(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_bonegroup_remove', 'Remove Bone Group', {'REGISTER', 'UNDO'}
    def execute(self, context):
        collection = ActiveCollection()
        collection.vbm.bone_groups.remove(collection.vbm.bone_group_index)
        collection.vbm.bone_group_index = max(0, min(collection.vbm.bone_group_index, len(collection.vbm.bone_groups)-1))
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionRemoveBonegroup)

class VBM_OT_CollectionMoveBonegroup(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_bonegroup_move', 'Move Bone Group', {'REGISTER', 'UNDO'}
    direction: EnumProperty(name="Direction", items=tuple([(x,x,x) for x in 'UP DOWN'.split()]))
    def execute(self, context):
        collection = ActiveCollection()
        if self.direction == 'UP':
            collection.vbm.bone_groups.move(collection.vbm.bone_group_index, collection.vbm.bone_group_index-1)
            collection.vbm.bone_group_index -= 1
        if self.direction == 'DOWN':
            collection.vbm.bone_groups.move(collection.vbm.bone_group_index, collection.vbm.bone_group_index+1)
            collection.vbm.bone_group_index += 1
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionMoveBonegroup)

class VBM_OT_CollectionAddBonegroupSelectedBones(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_bonegroup_bones_from_selected', 'Add Selected Bones to Group', {'REGISTER', 'UNDO'}
    @classmethod
    def poll(self, context):
        return context.active_object and context.active_object.type=='ARMATURE' and context.object.mode == 'POSE'
    
    def execute(self, context):
        collection = ActiveCollection()
        bone_group = collection.vbm.bone_groups[collection.vbm.bone_group_index]
        
        rig = context.object; rig = (rig if rig.type=='ARMATURE' else FindArmature(rig)) if rig else None
        bonenames = tuple(rig.data.bones.keys())
        for pb in context.selected_pose_bones:
            bname = pb.name
            if "DEF-"+bname.split("-")[-1] in bonenames:
                bname = "DEF-"+bname.split("-")[-1]
            elif "DEF-"+bname.split("-")[-1].replace("_ik","") in bonenames:
                bname = "DEF-"+bname.split("-")[-1].replace("_ik","")
            elif "DEF-"+bname.split("-")[-1].replace("_fk","") in bonenames:
                bname = "DEF-"+bname.split("-")[-1].replace("_fk","")
            if not ValidName(bname) or bname in list(bone_group.bones.keys()):
                continue
            b = rig.data.bones[bname]
            if b.use_deform:
                bone_group.bones.add().name = bname
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionAddBonegroupSelectedBones)

class VBM_OT_CollectionAddBonegroupSegment(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_bonegroup_segment_add', 'Add Selected Segments to Group', {'REGISTER', 'UNDO'}
    mode: EnumProperty(name="Mode", items=tuple([(x,x,x) for x in 'BONE SEGMENT SKIRT'.split()]))
    @classmethod
    def poll(self, context):
        return context.active_object and context.active_object.type=='ARMATURE' and context.object.mode == 'POSE'
    
    def execute(self, context):
        collection = ActiveCollection()
        bone_group = collection.vbm.bone_groups[collection.vbm.bone_group_index]
        
        FixDeformName = lambda bname: bname.replace("ORG-","DEF-").replace("MCH-","DEF-").replace("_ik","").replace("_fk","")
        
        for rig in FindAllArmatures(context.object):
            bonenames = tuple(rig.data.bones.keys())
            bonehits = []
            for pb in context.selected_pose_bones:
                bname = FixDeformName(pb.name)
                if not ValidName(bname):
                    continue
                b = rig.data.bones.get(bname)
                if b and b.use_deform:
                    bonehits.append(b)
            bonenames = [x.name for x in bonehits]
            
            _,deformmap,_ = EvaluateDeformOrder(rig)
            roots = [b for b in bonehits if deformmap.get(b.name, "") not in bonenames]
            chains = [[] for r in roots]
            if roots:
                print("Roots:", [b.name for b in roots])
                for c,root in enumerate(roots):
                    chain = [root]
                    hit = 1
                    while hit:
                        hit = 0
                        for b in bonehits:
                            if deformmap.get(b.name, "") == chain[-1].name:
                                hit = 1
                                chain.append(b)
                                break
                    chains[c] = chain
            
            if self.mode == 'SEGMENT':
                for c in chains:
                    for i in range(0, len(c)-1):
                        bone_group.add_segment(c[i].name, c[i+1].name)
            elif self.mode == 'SKIRT':
                for root_index in range(0, len(roots)):
                    n = min(len(c1), len(c2))
                    for i in range(0, n):
                        printd((c1[i].name, c2[i].name))
                        bone_group.add_segment(c1[i].name, c2[i].name)
                    
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionAddBonegroupSegment)

class VBM_OT_CollectionRemoveBonegroupBone(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_bonegroup_remove_bone', 'Remove Bone Group Bone', {'REGISTER', 'UNDO'}
    index: IntProperty(name="Index")
    def execute(self, context):
        collection = ActiveCollection()
        bone_group = collection.vbm.bone_groups[collection.vbm.bone_group_index]
        bone_group.bones.remove(self.index)
        bone_group.bone_index = max(0, min(self.index, len(bone_group.bones)-1))
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionRemoveBonegroupBone)

class VBM_OT_CollectionRemoveBonegroupSegment(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_bonegroup_remove_segment', 'Remove Bone Group Segment', {'REGISTER', 'UNDO'}
    index: IntProperty(name="Index")
    def execute(self, context):
        collection = ActiveCollection()
        bone_group = collection.vbm.bone_groups[collection.vbm.bone_group_index]
        bone_group.segments.remove(self.index)
        bone_group.segment_index = max(0, min(self.index, len(bone_group.segments)-1))
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionRemoveBonegroupSegment)

class VBM_OT_CollectionClearBonegroupBones(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_bonegroup_bones_clear', 'Clear Swing Bones', {'REGISTER', 'UNDO'}
    index: IntProperty(name="Index")
    type: EnumProperty(name="Type", items=tuple([(x,x,x) for x in 'BONE SEGMENT'.split()]))
    def execute(self, context):
        collection = ActiveCollection()
        bone_group = collection.vbm.bone_groups[collection.vbm.bone_group_index]
        if self.type == 'BONE':
            for i in range(0, len(bone_group.bones)):
                bone_group.bones.remove(0)
            bone_group.bone_index = 0
        elif self.type == 'SEGMENT':
            for i in range(0, len(bone_group.segments)):
                bone_group.segments.remove(0)
            bone_group.segment_index = 0
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionClearBonegroupBones)

class VBM_OT_CollectionBonegroupSelect(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_bonegroup_select', 'Select Bones in Group', {'REGISTER', 'UNDO'}
    index: IntProperty(name="Index")
    def execute(self, context):
        collection = ActiveCollection()
        bone_group = collection.vbm.bone_groups[self.index]
        rig = collection.vbm.get_rig()
        for b in bone_group.bones:
            pb = rig.pose.bones.get(b.name)
            if pb:
                pb.bone.select = True
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionBonegroupSelect)

# -----------------------------------------------------------------------------
class VBM_OT_CollectionMaterialOverrideFromObjects(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_material_override_from_objects', 'Material Overrides from Collection Objects', {'REGISTER', 'UNDO'}
    def execute(self, context):
        collection = ActiveCollection()
        for mtl in [mtl for obj in collection.all_objects if obj.type=='MESH' for mtl in obj.data.materials if mtl]:
            collection.vbm.add_material_override(mtl)
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionMaterialOverrideFromObjects)

class VBM_OT_CollectionMaterialOverrideAdd(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_material_override_add', 'Add Material Override', {'REGISTER', 'UNDO'}
    def execute(self, context):
        collection = ActiveCollection()
        collection.vbm.material_overrides.add()
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionMaterialOverrideAdd)

class VBM_OT_CollectionMaterialOverrideRemove(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_material_override_remove', 'Remove Material Override', {'REGISTER', 'UNDO'}
    index: IntProperty(name="Index", min=0)
    def execute(self, context):
        collection = ActiveCollection()
        collection.vbm.material_overrides.remove(self.index)
        collection.vbm.material_override_index = max(0, min(collection.vbm.material_override_index, len(collection.vbm.material_overrides)-1))
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionMaterialOverrideRemove)

class VBM_OT_CollectionSelectTextureSlot(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_select_texture_slot', 'Select Texture', {'REGISTER', 'UNDO_GROUPED'}
    bl_description = "Select texture slot for editing"
    slot: IntProperty(name="Slot", min=0)
    def execute(self, context):
        collection = ActiveCollection()
        collection.vbm.texture_slot_index = self.slot
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionSelectTextureSlot)

class VBM_OT_CollectionMaterialAddTexture(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_material_add_texture', 'Add Texture', {'REGISTER', 'UNDO_GROUPED'}
    bl_description = "Add texture to material for texture slot"
    slot: IntProperty(name="Slot", min=0)
    def execute(self, context):
        mtl = ActiveCollectionMaterial()
        if mtl:
            nd = mtl.node_tree.nodes.new('ShaderNodeTexImage')
            nd.name = "TEXTURE%d" % self.slot
            nd.label = nd.name
            nd.hide = True
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionMaterialAddTexture)

class VBM_OT_CollectionMaterialMoveTextureSlot(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.collection_material_move_texture', 'Move Texture', {'REGISTER', 'UNDO'}
    bl_description = "Add texture to material for texture slot"
    direction: EnumProperty(name="Direction", items=tuple([(x,x,x) for x in 'UP DOWN'.split()]))
    def execute(self, context):
        mtl = ActiveCollectionMaterial()
        if mtl:
            collection = ActiveCollection()
            imagenodes = mtl.vbm.get_imagenodes()
            oldslot = collection.vbm.texture_slot_index
            newslot = (oldslot + (-1 if self.direction=='UP' else 1)) % len(imagenodes)
            if imagenodes[oldslot] and imagenodes[newslot]:
                oldname = imagenodes[oldslot]
                newname = imagenodes[newslot]
                imagenodes[oldslot].name += "."
                imagenodes[newslot].name += "."
                imagenodes[oldslot] = newname
                imagenodes[newslot] = oldname
            else:
                nd = imagenodes[oldslot]
                print(nd)
                nd.name = "TEXTURE%d"%newslot
                collection.vbm.texture_slot_index = newslot
        return {'FINISHED'}
classlist.append(VBM_OT_CollectionMaterialMoveTextureSlot)

# ===================================================================================================
Clean = lambda: [data.remove(x) for data in (bpy.data.meshes, bpy.data.objects, bpy.data.armatures, bpy.data.images, bpy.data.actions) for x in list(data)[::-1] if x.get('TEMP', False)]

class VBM_OT_ExportCollection(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.export_collection', 'Export Collection', {'REGISTER', 'UNDO'}
    bl_description = "Exports active collection"
    def execute(self, context):
        collection = ActiveCollection()
        t = time.time_ns()
        hits = collection.vbm.export()
        SelectCollection(collection)
        if hits == 0:
            self.report({'WARNING'}, "> No collections exported. (Active collection not marked for export?)")
        else:
            self.report({'INFO'}, "> Export Complete \"%s\" (%d hit(s), %2.2f sec)" % (collection.name, hits, (time.time_ns()-t)/1_000_000_000 ))
        return {'FINISHED'}
classlist.append(VBM_OT_ExportCollection)

class VBM_OT_ExportCollectionAll(bpy.types.Operator):
    bl_idname, bl_label, bl_options = 'vbm.export_collection_all', 'Export Scene Collections', {'REGISTER', 'UNDO'}
    bl_description = "Export all collections in scene"
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
    bl_description = "Extend edges of pixels on texture to fill in alpha"
    
    image : bpy.props.StringProperty(name="Image", default="")
    
    def invoke(self, context, event):
        if 1 or self.image == "":
            for a in [a for a in context.screen.areas if (a.type == 'IMAGE_EDITOR' or a.type == 'UV_EDIT') and a.spaces[0].image and a.spaces[0].image.name[0].lower() in 'qwertyuiopasdfghjklzxcvbnm1234567890'][:1]:
                self.image = a.spaces[0].image.name
        return context.window_manager.invoke_props_dialog(self)
    
    def draw(self, context):
        self.layout.prop_search(self, 'image', bpy.data, 'images')
    
    def execute(self, context):
        image = bpy.data.images.get(self.image, None)
        if image:
            image.vbm.pad_pixels()
        return {'FINISHED'}
classlist.append(VBM_OT_TexturePadding)

class VBM_OT_RigClearPose(bpy.types.Operator):
    bl_idname, bl_label, bl_options = ('vbm.rig_clear_pose', 'VBM Rig Clear Pose', {'REGISTER', 'UNDO'})
    bl_description = "Resets transforms of pose bones"
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

class VBM_OT_ArmatureSyncSubarmatures(bpy.types.Operator):
    bl_idname, bl_label, bl_options = ('vbm.armature_sync_sub_armatures', 'VBM Sync Sub Armatures', {'REGISTER', 'UNDO'})
    bl_description = "Updates positions of merge bones (bones starting with \"^\") of sub amratures to root armature"
    use_constraint: BoolProperty(name="Use Constraint", default=False)
    def execute(self, context):
        active = context.active_object
        rig = CollectionRig()
        if not rig:
            self.report({'INFO'}, "> No rig found")
        else:
            hits = 0
            root_bones = {
                "^"+b.name: (tuple(b.head_local), tuple(b.tail_local), (b.AxisRollFromMatrix(b.matrix_local.to_3x3())[1])) 
                for b in rig.data.bones
            }
            for sub in rig.children:
                if sub.type=='ARMATURE':
                    bpy.ops.object.select_all(action='DESELECT')
                    context.view_layer.objects.active = sub
                    sub.select_set(True)
                    bpy.ops.object.mode_set(mode='EDIT')
                    for b in sub.data.edit_bones:
                        if b.name in root_bones.keys():
                            print(b.name)
                            hits += 1
                            b.head, b.tail, b.roll = root_bones[b.name]
                    bpy.ops.object.mode_set(mode='OBJECT')
                    if self.use_constraint:
                        for pb in sub.pose.bones:
                            if pb.name in root_bones.keys():
                                if not [c for c in pb.constraints if c.name=='VBM_BONECOPY']:
                                    c = pb.constraints.new(type='COPY_TRANSFORMS')
                                    c.name='VBM_BONECOPY'
                                c = pb.constraints['VBM_BONECOPY']
                                c.target = rig
                                c.subtarget = pb.name[1:]
            if hits == 0:
                self.report({'INFO'}, "> No sub armatures found")
            else:
                self.report({'INFO'}, "> Hits: %d" % hits)
        bpy.ops.object.select_all(action='DESELECT')
        context.view_layer.objects.active = active
        active.select_set(True)
        
        
        return {'FINISHED'}
classlist.append(VBM_OT_ArmatureSyncSubarmatures)

"======================================================================================================"
"UILIST"
"======================================================================================================"

def VBMDrawMaskVector(layout, id, prop, cap=0):
    r = layout.row(align=1)
    r.alignment = 'RIGHT'
    r.ui_units_x = 2.5
    for i in list(range(0, cap if cap > 0 else int(bpy.context.scene.vbm.layer_mask_display_size)))[::(1,-1)[bpy.context.scene.vbm.layer_mask_display_reverse]]:
        r.prop(id, prop, index=i, text="", toggle=True)

# ------------------------------------------------------------------------------------------------
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
            for i in range(0, item.depth):
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
                rr = r.row()
                rr.alignment='RIGHT'
                rr.prop(obj.vbm, 'is_collision', text="", icon='PHYSICS')
                VBMDrawMaskVector(rr, obj.vbm, 'layer_mask', 8)
                r.operator('vbm.object_clear_checksum', text="", icon=VBM_ICON_CLEARCHECKSUM).object = obj.name
        else:
            rr = r.row(align=1)
            rr.label(text="", icon='MESH_PLANE')
            rr.scale_x = 0.09
            r.label(text="( %s )"%obj.name, icon=icon)
        
        if obj.type == 'ARMATURE':
            rr = r.row()
            rr.alignment='RIGHT'
            rr.label(text="%d" % len(obj.vbm['DEFORM_LIST'] if obj.vbm.get('DEFORM_LIST',None) else [b for b in obj.data.bones if b.use_deform]), icon='BONE_DATA')
        
        if context.scene.vbm.show_extra_info:
            r = layout.row(align=1)
            r.alignment='RIGHT'
            r.label(text="Mask: " + MaskVectorStr(obj.vbm.layer_mask))
classlist.append(VBM_UL_CollectionObjects)

# -------------------------------------------------------------------------------------
class VBM_UL_CollectionActions(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        action = item.action
        layout = layout.row(align=0)
        if not action:
            r = layout.row(align=1)
            r.prop(item, 'export_enabled', text="", icon=VBM_EXPORTENABLEDICONS[item.export_enabled], emboss=False)
            r.prop(item, 'action')
            r = layout.row(align=1)
            r.label()
            r.label(text="(Action Missing)")
        else:
            r = layout.row(align=1)
            r.prop(item, 'export_enabled', text="", icon=VBM_EXPORTENABLEDICONS[item.export_enabled], emboss=False)
            rr = r.row(align=1)
            rr.active = item.export_enabled
            rr.scale_x = 1.5
            rr.prop(action, 'name', text="", emboss=False)
            # Frame Range
            if context.region.width > 400:
                rr = r.row(align=1)
                rr.alignment='RIGHT'
                rr.enabled = action.use_frame_range
                rr.label(text="%02d:%03d" % (action.frame_range[0], action.frame_range[1]))
            # Layer Mask
            if context.region.width > 450:
                VBMDrawMaskVector(r, action.vbm, 'layer_mask', 8)
            # Booleans
            r = layout.row(align=1)
            r.prop(action.vbm, 'clean_on_bake', text="", icon='MOD_SMOOTH')
            r.separator()
            r.prop(action, 'use_frame_range', text="", icon='PREVIEW_RANGE')
            r.prop(action, 'use_cyclic', text="", icon='FILE_REFRESH')
classlist.append(VBM_UL_CollectionActions)

# -------------------------------------------------------------------------------------
class VBM_UL_CollectionBonegroup(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=1)
        rr = r.row(align=1)
        rr.scale_x = 0.3
        rr.label(text="", icon=VBM_ICON_COLOR[index%len(VBM_ICON_COLOR)])
        r.operator('vbm.collection_bonegroup_select', text="", icon='GROUP_BONE', emboss=False).index=index
        r.prop(item, 'name', text="", emboss=False)
        if context.region.width > 320:
            VBMDrawMaskVector(r, item, 'layer_mask', 8)
        rr = r.row(align=1)
        rr.alignment = 'RIGHT'
        n = item.get_bone_count()
        rr.label(text="%s%2d Bones" % (" " if n < 10 else "", n) )
        
        rr = r.row(align=1)
        rr.alignment = 'RIGHT'
        rr.active = item.swing_enabled
        rr.prop(item, 'swing_enabled', text="", icon=VBM_ICON_SWING, emboss=False)
        rr = r.row(align=1)
        rr.active = item.show_bones
        r.prop(item, 'show_bones', text="", icon='HIDE_OFF' if item.show_bones else 'HIDE_ON', emboss=False)
classlist.append(VBM_UL_CollectionBonegroup)

class VBM_UL_CollectionBonegroupBones(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=1)
        r.label(text=item.name, icon='BONE_DATA')
        r.operator('vbm.collection_bonegroup_remove_bone', text="", icon='X', emboss=False).index=index
classlist.append(VBM_UL_CollectionBonegroupBones)

class VBM_UL_CollectionBonegroupSegments(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=1)
        r.label(text="", icon='MOD_SIMPLIFY')
        r.prop(item, 'start_bone', text="", emboss=item.start_bone=="")
        r.prop(item, 'end_bone', text="", emboss=item.end_bone=="")
        r.operator('vbm.collection_bonegroup_remove_segment', text="", icon='X', emboss=False).index=index
classlist.append(VBM_UL_CollectionBonegroupSegments)

# -------------------------------------------------------------------------------------
class VBM_UL_CollectionMaterialoverride(bpy.types.UIList):
    def draw_item(self, context, layout, data, item, icon, active_data, active_propname, index):
        r = layout.row(align=0)
        #r.prop(item, 'enabled', text="", icon='CHECKBOX_HLT' if item.enabled else 'CHECKBOX_DEHLT', emboss=False)
        r.prop(item, 'material', text="")
        r.prop(item, 'override', text="->")
        r.operator('vbm.collection_material_override_remove', text="", icon='X', emboss=False).index = index
classlist.append(VBM_UL_CollectionMaterialoverride)

"======================================================================================================"
"PANELS"
"======================================================================================================"

# ---------------------------------------------------------------------------------------
def VBMDrawLayermask(layout, id, propname, text=""):
    n = int(bpy.context.scene.vbm.layer_mask_display_size)
    w = bpy.context.region.width
    b = layout.row(align=1)
    step = -1 if bpy.context.scene.vbm.layer_mask_display_reverse else 1
    if text:
        r = b.row(align=1)
        r.label(text=text+":")
        r = r.row(align=1)
        
        c = b.column(align=1)
        if n <= 8:
            c.ui_units_x = 8
            r = c.row(align=1)
            r.alignment = 'RIGHT'
            [r.prop(id, propname, text="%02d"%i, index=i, toggle=1) for i in list(range(0,8))[::step]]
        else:
            c.ui_units_x = 10
            for i in list(range(0, n))[::step]:
                if i%16 == 0:
                    r = c.row(align=1)
                    r.alignment = 'RIGHT'
                r.prop(id, propname, text="%01d"%(i%10), index=i, toggle=1)

# ---------------------------------------------------------------------------------------
def VBMActionPanel(layout, collection):
    context = bpy.context
    
    rig = collection.vbm.get_rig()
    if rig and rig.animation_data:
        r = layout.row()
        r.label(text=rig.name, icon='ARMATURE_DATA')
        r.operator('vbm.rig_clear_pose', text="", icon='MOD_ARMATURE')
        layout.template_ID(rig.animation_data, 'action')
        
    r = layout.box().row()
    rr = r.row(align=1)
    rr.scale_x = 0.7
    rr.prop(collection.vbm, 'clip_action_name', text="Clip Names")
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
    c.template_list('VBM_UL_CollectionActions', "", collection.vbm, 'actions', collection.vbm, 'action_index', rows=9)
    c = r.column(align=1)
    c.scale_y = 0.8
    c.prop(context.scene.vbm, 'show_extra_info', text="", icon=VBM_LAYERMASKICON)
    c.separator()
    c.operator('vbm.collection_action_push', text="", icon='NLA_PUSHDOWN')
    c.operator('vbm.collection_action_add', text="", icon='ADD')
    c.operator('vbm.collection_action_remove', text="", icon='REMOVE')
    c.separator()
    c.operator('vbm.collection_action_move', text="", icon='TRIA_UP').direction='UP'
    c.operator('vbm.collection_action_move', text="", icon='TRIA_DOWN').direction='DOWN'
    c.separator()
    c.operator('vbm.collection_action_sort', text="", icon='SORTSIZE')
    c.operator('vbm.collection_clear_checksum', text="", icon=VBM_ICON_CLEARCHECKSUM).group='ACTION'
    
    if collection.vbm.actions:
        actionitem = collection.vbm.actions[collection.vbm.action_index]
        action = actionitem.action
        c = layout.column(align=0)
        if not action:
            c.prop(actionitem, 'action', text="Action")
        else:
            VBMDrawLayermask(c, action.vbm, 'layer_mask', "Bone Mask")
            
            r = c.row(align=0)
            r.prop(action, 'use_frame_range', text="", icon='PREVIEW_RANGE')
            r.prop(action, 'use_cyclic', text="", icon='FILE_REFRESH')
            r = r.row(align=1)
            r.enabled = action.use_frame_range
            r.prop(action.vbm, 'frame_start', text="Start")
            r.prop(action.vbm, 'frame_end', text="End")
            rr = r.row(align=0)
            rr.scale_x = 0.85
            #rr.prop(action.vbm, 'frame_rate', text="")

# --------------------------------------------------------------------------------------
def VBMSwingPanel(layout, collection):
    context = bpy.context
    rig = collection.vbm.get_rig()
    
    if not rig:
        r = layout.row()
        r.alert=True
        r.alignment='CENTER'
        r.label(text="(No valid Rig found in collection!)")
    else:
        deformbones = rig.get('DEFORM_LIST', None)
        if not deformbones:
            deformbones = [b for b in rig.data.bones if b.use_deform]
        
        r = layout.row(align=1)
        r.prop(collection, 'name', text="", icon='GROUP', emboss=False)
        r.prop(rig, 'name', text="", icon='ARMATURE_DATA', emboss=False)
        
        c = layout.column(align=1)
        r = c.row(align=1)
        r.label(text="Default Layer Mask:")
        r = r.row(align=1)
        r.alignment='RIGHT'
        r.label(text="(%3d) Bones" % (len(deformbones)))
        VBMDrawLayermask(c, collection.vbm, 'bone_layer_mask_default', text="")
        
        r = layout.row(align=1)
        c = r.column(align=1)
        c.scale_y = 0.9
        c.template_list('VBM_UL_CollectionBonegroup', "", collection.vbm, 'bone_groups', collection.vbm, 'bone_group_index', rows=6)
        c = r.column(align=1)
        c.scale_y = 1.0
        c.operator('vbm.collection_bonegroup_add', text="", icon='ADD')
        c.operator('vbm.collection_bonegroup_remove', text="", icon='REMOVE')
        c.separator()
        c.operator('vbm.collection_bonegroup_move', text="", icon='TRIA_UP').direction='UP'
        c.operator('vbm.collection_bonegroup_move', text="", icon='TRIA_DOWN').direction='DOWN'
        c.separator()
        #c.prop(context.scene.vbm, 'show_extra_info', text="", icon=VBM_LAYERMASKICON)
        
        bone_group = collection.vbm.bone_groups[collection.vbm.bone_group_index] if collection.vbm.bone_groups else None
        if bone_group:
            b = layout.box().column(align=0)
            b.active = bone_group.export_enabled
            
            VBMDrawLayermask(b, bone_group, 'layer_mask', text="Layer Mask")
            VBMDrawLayermask(b, bone_group, 'collision_mask', text="Collision Mask")
            
            bb = b.box().column(align=1)
            bb.row(align=1).prop(context.scene.vbm, 'swing_tab', expand=True)
            
            if context.scene.vbm.swing_tab == 'SWING':
                c = bb.box().column(align=1)
                c.use_property_split = True
                c.prop(bone_group, 'swing_enabled')
                c.prop(bone_group, 'add_leaf_bones')
                c = c.column(align=1)
                c.active = bone_group.swing_enabled
                c.scale_y = 0.9
                c.use_property_split = True
                c.prop(bone_group, 'radius')
                c.separator()
                c.prop(bone_group, 'stiffness')
                c.prop(bone_group, 'damping')
                c.prop(bone_group, 'limit')
                c.prop(bone_group, 'force_strength')
            elif context.scene.vbm.swing_tab == 'BONE':
                r = bb.row(align=1)
                c = r.column(align=1)
                c.scale_y = 0.7
                c.template_list('VBM_UL_CollectionBonegroupBones', "", bone_group, 'bones', bone_group, 'bone_index', rows=6)
                c = r.column(align=1)
                c.scale_y = 1.0
                c.separator()
                c.operator('vbm.collection_bonegroup_bones_from_selected', text="", icon='RESTRICT_SELECT_OFF')
                c.operator('vbm.collection_bonegroup_bones_clear', text="", icon='X').type='BONE'
            elif context.scene.vbm.swing_tab == 'SEGMENT':
                r = bb.row(align=1)
                c = r.column(align=1)
                c.scale_y = 0.7
                c.template_list('VBM_UL_CollectionBonegroupSegments', "", bone_group, 'segments', bone_group, 'segment_index', rows=6)
                c = r.column(align=1)
                c.scale_y = 1.0
                c.separator()
                c.operator('vbm.collection_bonegroup_segment_add', text="", icon='CON_TRACKTO').mode='SEGMENT'
                c.operator('vbm.collection_bonegroup_segment_add', text="", icon='CONE').mode='SKIRT'
                c.separator()
                c.operator('vbm.collection_bonegroup_bones_clear', text="", icon='X').type='SEGMENT'

# ------------------------------------------------------------------------------------
class VBM_PT_Rig3DView(bpy.types.Panel):
    bl_label, bl_space_type, bl_region_type = ("DmrVBM Rig", 'VIEW_3D', 'UI')
    bl_category = "DmrVBM"
    
    @classmethod
    def poll(self, context):
        return context.scene.vbm.show_swing_viewport_panel
    
    def draw(self, context):
        layout = self.layout
        
        r = layout.row(align=1)
        r.prop(context.scene.vbm, 'show_swing_bones')
        r.prop(context.scene.vbm, 'show_swing_segments')
        
        collection = ActiveCollection()
        rig = collection.vbm.get_rig()
        
        if not rig:
            layout.label(text=collection.name, icon='GROUP')
            layout.label(text="(No Armature Selected)")
        else:
            c = layout.column(align=1)
            c.scale_y = 0.8
            c.label(text=collection.name, icon='GROUP')
            r = c.row(align=1)
            r.label(text=rig.name, icon='ARMATURE_DATA')
            r = layout.row()
            r.prop(rig.data, 'pose_position', expand=True)
            r = layout.row(align=1)
            r.operator('vbm.armature_sync_sub_armatures', text="Sync Sub Armatures", icon='AUTOMERGE_ON').use_constraint=False
            r.operator('vbm.armature_sync_sub_armatures', text="", icon='CONSTRAINT_BONE').use_constraint=True
classlist.append(VBM_PT_Rig3DView)

class VBM_PT_Rig3DView_Actions(bpy.types.Panel):
    bl_label, bl_space_type, bl_region_type = ("Actions", 'VIEW_3D', 'UI')
    bl_parent_id = 'VBM_PT_Rig3DView'
    #bl_category = "DmrVBM"
    
    def draw(self, context):
        VBMActionPanel(self.layout, ActiveCollection())
classlist.append(VBM_PT_Rig3DView_Actions)

class VBM_PT_Rig3DView_Swingbones(bpy.types.Panel):
    bl_label, bl_space_type, bl_region_type, bl_options = ("Bone Groups", 'VIEW_3D', 'UI', {'DEFAULT_CLOSED'})
    bl_parent_id = 'VBM_PT_Rig3DView'
    #bl_category = "DmrVBM"
    
    def draw(self, context):
        layout = self.layout
        collection = ActiveCollection()
        VBMSwingPanel(layout, collection)
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
        
        # Collection .......................................................
        r = layout.row(align=1)
        r.prop(vbm, 'data_path', placeholder="(.blend folder)")
        
        r = layout.row(align=1)
        r.prop(collection.vbm, 'enabled', text="")
        r.label(text=collection.name, icon='GROUP')
        rr = r.row(align=1)
        rr.alignment = 'RIGHT'
        rr.label(text="%d File(s)" % (collection.vbm.enabled + collection.vbm.get_file_count()) )
        
        r = layout.row(align=0)
        r.operator('vbm.export_collection', text="Export Collection" if collection.vbm.enabled else "Export Collection Files", icon='EXPORT')
        r = r.row()
        r.scale_x = 0.8
        r.operator('vbm.export_collection_all', text="Export All", icon='EXPORT')
        
        # Tab -------------------------------------------------------------
        layout = layout.box().column(align=1)
        layout.row(align=1).prop(context.scene.vbm, 'panel_tab', expand=True)
        layout = layout.box().column(align=0)
        export_enabled = collection.vbm.enabled
        
        # Settings --------------------------------------------------------
        if context.scene.vbm.panel_tab == 'SCENE':
            c = layout.column(align=1)
            c.use_property_split = 1
            c.scale_y = 0.9
            c.prop(context.scene.vbm, 'shader_default')
            c.prop(context.scene.vbm, 'layer_mask_display_size', text="Layer Mask Size")
            c.prop(context.scene.vbm, 'layer_mask_display_reverse', text="Layer Mask Reversed")
            r = c.row()
            r.prop(context.scene.vbm, 'show_modifier_bake')
            r.label(text="", icon='MODIFIER')
            c.prop(context.scene.vbm, 'show_extra_info', text="Extended List Display")
            c.prop(context.scene.vbm, 'show_swing_viewport_panel')
            c.prop(context.scene.vbm, 'show_swing_bones')
            c.prop(context.scene.vbm, 'show_swing_segments')
            c.prop(context.scene.vbm, 'print_debug')
            
            r = layout.row(align=1)
            r.label(text="Clear Checksum:", icon='UNLINKED')
            rr = r.row(align=1)
            rr.scale_x = 0.6
            rr.operator('vbm.collection_clear_checksum', text="CLL").group='COLLECTION'
            rr.operator('vbm.collection_clear_checksum', text="OBJ").group='OBJECT'
            rr.operator('vbm.collection_clear_checksum', text="ANI").group='ACTION'
            rr.operator('vbm.collection_clear_checksum', text="TEX").group='IMAGE'
            layout.operator('vbm.restore_layer_mask', icon='MODIFIER')
            
            layout.separator()
            c = layout.column(align=1)
            c.scale_y = 0.7
            c.template_list('VBM_UL_CollectionChildren', "", sc.collection.vbm, 'children', sc.collection.vbm, 'child_index', rows=6 if sc.collection.children else 2)
        # Collection -----------------------------------------------------
        elif context.scene.vbm.panel_tab == 'COLLECTION':
            # Active Collection
            layout.active = collection.vbm.enabled
            
            r = layout.row(align=1)
            r.prop(collection.vbm, 'enabled', text="")
            r.prop(collection.vbm, 'name', text="", icon='GROUP', placeholder=collection.name+".vbm")
            rr = r.row(align=1)
            rr.alignment = 'RIGHT'
            rr.label(text="%d File(s)" % (collection.vbm.enabled + len([1 for c in collection.children_recursive if c.vbm.enabled])) )
            
            r = layout.row(align=1)
            r.prop(collection.vbm, 'use_compression')
            
            # File Include
            r = layout.row(align=1)
            r.prop(collection.vbm, 'export_meshes', text="MSH", toggle=1, icon='OUTLINER_DATA_MESH')
            r.prop(collection.vbm, 'export_skeleton', text="SKE", toggle=1, icon='BONE_DATA')
            r.prop(collection.vbm, 'export_animations', text="ANI", toggle=1, icon='ACTION')
            r.prop(collection.vbm, 'export_materials', text="MTL", toggle=1, icon='MATERIAL')
            r.prop(collection.vbm, 'export_textures', text="TEX", toggle=1, icon='IMAGE_DATA')
            
            # Format
            format = collection.vbm.format
            b = layout.row(align=1)
            b.label(text="Format:")
            c = b.column(align=1)
            
            r = c.row(align=1)
            for i,attribute_name in enumerate(ATTRIBUTE_NAME):
                p = r.column(align=1)
                active = format[i]
                isbyte = format[i+16]
                p.prop(collection.vbm, 'format', text="", index=i, icon=ATTRIBUTE_ICON[i], emboss=active, invert_checkbox=0)
                p.prop(collection.vbm, 'format', text="", index=i+16, icon=('EVENT_B' if isbyte else 'EVENT_F'), emboss=active, invert_checkbox=0)
            
            r = layout.row(align=1)
            r.scale_y = 0.9
            c = [r.column(align=1) for i in range(0,4)]     # [icon, prop, default, flag]
            c[1].scale_x = 1.5
            c[2].scale_x = 0.6
            
            # Color Defaults
            for i,label in enumerate(["Color"]):
                enabled = format[4]
                e = [x.row(align=1) for x in c]
                for x in e:
                    x.enabled = enabled
                e[0].label(text=label, icon=ATTRIBUTE_ICON[ATTRIBUTE_INDEX['COL']])
                if obj and obj.type=='MESH':
                    e[1].prop_search(collection.vbm, 'color_layer_name', obj.data, 'color_attributes', text="", results_are_suggestions=True)
                else:
                    e[1].prop(collection.vbm, 'color_layer_name', text="", placeholder="<Active VC Layer>")
                e[2].prop(collection.vbm, 'color_layer_default', text="")
                e[3].prop(collection.vbm, 'color_is_srgb', text="", icon='MOD_THICKNESS')
            [x.separator() for x in c]
            
            # UV Defaults
            for i,label in enumerate(("UV", "UV2")):
                enabled = format[5 if i==0 else 6]
                e = [x.row(align=1) for x in c]
                for x in e:
                    x.enabled = enabled
                e[0].label(text=label, icon=ATTRIBUTE_ICON[ATTRIBUTE_INDEX['UVS']])
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
            if context.active_object and context.active_object.type=='MESH' and sum(context.active_object.vbm.layermask):
                layout.operator('vbm.restore_layer_mask', icon='MODIFIER')
            
            r = layout.row()
            r.label(text="", icon='TEXT')
            r.prop(collection.vbm, 'object_script_pre', text="Pre")
            r.prop(collection.vbm, 'object_script_post', text="Post")
            
            r = layout.row(align=0)
            r.active = export_enabled
            rr = r.row(align=1)
            rr.scale_x = 1.2
            rr.alignment = 'LEFT'
            rr.prop(collection.vbm, 'mesh_join_type')
            rr = r.row(align=1)
            rr.alignment = 'RIGHT'
            rr.prop(collection.vbm, 'object_flatten')
            
            r = layout.row()
            r.prop(collection.vbm, 'object_add_root')
            r.prop(collection.vbm, 'clip_object_name', text="Clip Names")
            r.prop(collection.vbm, 'use_vtx_compression', text="Compress VB")
            
            r = layout.row(align=1)
            c = r.column()
            c.active = export_enabled
            c.scale_y = 0.7
            c.template_list('VBM_UL_CollectionObjects', "", collection, 'all_objects', collection.vbm, 'object_index', rows=8)
            c = r.column(align=1)
            c.prop(context.scene.vbm, 'show_extra_info', text="", icon=VBM_LAYERMASKICON)
            c.separator()
            c.operator('vbm.collection_object_move', text="", icon='TRIA_UP').direction='UP'
            c.operator('vbm.collection_object_move', text="", icon='TRIA_DOWN').direction='DOWN'
            c.separator()
            c.operator('vbm.sort_objects', text="", icon='SORTSIZE')
            c.operator('vbm.collection_clear_checksum', text="", icon='UNLINKED').group='OBJECT'
            
            if collection.all_objects:
                obj = collection.all_objects[collection.vbm.object_index]
                b = layout.column(align=1)
                b.label(text=obj.name, icon=ObjIcon(obj.type))
                VBMDrawLayermask(b, obj.vbm, 'layer_mask', "Object Layer Mask")
                
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
            c.scale_y = 0.9
            c.operator('vbm.collection_material_override_from_objects', text="", icon='NLA_PUSHDOWN')
            c.separator()
            c.operator('vbm.collection_material_override_add', text="", icon='ADD')
            c.operator('vbm.collection_material_override_remove', text="", icon='REMOVE').index = collection.vbm.material_override_index
            c.separator()
            c.operator('vbm.collection_clear_checksum', text="", icon='UNLINKED').group='IMAGE'
            
            # Active Material
            mtl = ActiveCollectionMaterial()
            imagenodes = mtl.vbm.get_imagenodes() if mtl else ([None]*16)
            if mtl:
                b = layout.box().column(align=1)
                r = b.row()
                r.prop(mtl, 'name', text="", icon='MATERIAL', emboss=1)
                r.prop_search(mtl.vbm, 'shader', context.scene.vbm, 'shader_names', text="", icon=VBM_ICON_SHADER, results_are_suggestions=True)
                
                c = b.row(align=1)
                r = c.row(align=1)
                r.prop(mtl.vbm, 'transparent')
                r = c.row(align=1)
                r.prop(mtl, 'use_backface_culling')
                
                # Material Textures
                bb = b.box().column()
                r = bb.row()
                r.alignment = 'CENTER'
                r.label(text="==Texture Slots==")
                br = bb.row(align=1)
                br.scale_y = 0.9
                texture_slot_index = collection.vbm.texture_slot_index
                activeimagenode = None
                for i,nd in enumerate(imagenodes):
                    texname = 'TEXTURE%d' % i
                    if (i%(VBM_MATERIALTEXTURECOUNT//2)) == 0:
                        c = br.column(align=1)
                    r = c.row(align=1)
                    r.alignment = 'LEFT'
                    rr = r.row(align=1)
                    rr.scale_x = 0.3
                    rr.label(text='[%d]'%i)
                    if nd:
                        imagename = (nd.image.name if nd.image else texname)
                        rr = r.row(align=1)
                        rr.operator('vbm.collection_select_texture_slot', text=imagename+" "*(20-len(imagename)), icon='IMAGE_DATA' if nd.image else 'SHADING_BBOX', emboss=i==texture_slot_index).slot=i
                        rr.active = 1
                        if i==texture_slot_index:
                            activeimagenode = nd
                            cc = r.column(align=1)
                            cc.scale_y = 0.5
                            op = cc.operator('vbm.collection_material_move_texture', text="", icon='TRIA_UP'  ); op.direction = ('UP')
                            op = cc.operator('vbm.collection_material_move_texture', text="", icon='TRIA_DOWN'); op.direction = ('DOWN')
                    else:
                        x = r.row(align=1)
                        x.active = i==texture_slot_index
                        x.operator('vbm.collection_select_texture_slot', text=texname+" "*(20-len(texname)), icon='SHADING_BBOX', emboss=i==texture_slot_index).slot=i
                
                # Active Image Slot
                if activeimagenode:
                    r = bb.row(align=1)
                    if not activeimagenode:
                        r.prop(activeimagenode, 'image')
                    else:
                        c = bb.column(align=1)
                        c.scale_y = 0.9
                        c.use_property_split = 1
                        c.prop(activeimagenode, 'image')
                        if activeimagenode.image:
                            c.prop(activeimagenode, 'interpolation', text="Interpolation")
                            c.prop(activeimagenode.image.colorspace_settings, 'name', text="Color Space")
                        #c.prop(activeimagenode, 'extension', text="Extension")
                else:
                    bb.operator('vbm.collection_material_add_texture', text="Create TEXTURE%d"%texture_slot_index, icon='ADD').slot = texture_slot_index
            
            # Object Materials
            b = layout.row(align=0)
            r = b.row(align=1)
            r.scale_y=0.8
            c = [r.column(align=1) for i in (0,1,2,3,4,5,6)]
            c[0].scale_x = 1.1
            c[1].scale_x = 0.8
            c[2].scale_x = 1.2
            c[0].label(text="MTL", icon='MATERIAL')
            c[1].label(text="SHD", icon=VBM_ICON_SHADER)
            c[2].label(text="TEXTURE0", icon='NODE_TEXTURE')
            c[3].label(text="", icon=VBM_ICON_TRANSPARENT)
            c[4].label(text="", icon=VBM_ICON_BACKFACECULLING)
            c[5].label(text="", icon=VBM_ICON_FLIPFACES)
            c[6].label(text="", icon=VBM_ICON_USEDEPTH)
            for mtl in materials:
                c[0].prop(mtl, 'name', text="")
                c[1].prop_search(mtl.vbm, 'shader', context.scene.vbm, 'shader_names', text="", results_are_suggestions=True)
                ndimage = mtl.vbm.get_imagenodes()[0]
                if ndimage:
                    c[2].prop(ndimage, 'image', text="")
                else:
                    c[2].label(text="(No Image)")
                c[3].prop(mtl.vbm, 'transparent', text="", icon='CHECKBOX_HLT' if mtl.vbm.transparent else 'CHECKBOX_DEHLT', emboss=True)
                c[4].prop(mtl, 'use_backface_culling', text="", icon='CHECKBOX_HLT' if mtl.use_backface_culling else 'CHECKBOX_DEHLT', emboss=True)
                l = c[5].column(align=1)
                l.active = mtl.use_backface_culling
                l.prop(mtl.vbm, 'flip_faces', text="", icon='CHECKBOX_HLT' if mtl.vbm.flip_faces else 'CHECKBOX_DEHLT', emboss=True)
                c[6].prop(mtl.vbm, 'use_depth', text="", icon='CHECKBOX_HLT' if mtl.vbm.use_depth else 'CHECKBOX_DEHLT', emboss=True)
        # Action
        elif context.scene.vbm.panel_tab == 'ACTION':
            VBMActionPanel(layout, collection)
        # Swing
        elif context.scene.vbm.panel_tab == 'SWING':
            VBMSwingPanel(layout, collection)
classlist.append(VBM_PT_Asset)

# -----------------------------------------------------------------------------------------------------------
class VBM_PT_ModifierBake(bpy.types.Panel):
    bl_label, bl_space_type, bl_region_type = ("( VBM Bake )", 'PROPERTIES', 'WINDOW')
    bl_context = "modifier"
    bl_options = {'HIDE_HEADER'}
    
    @classmethod
    def poll(self, context):
        return context.scene.vbm.show_modifier_bake
    
    def draw(self, context):
        layout = self.layout.row(align=0)
        layout.prop(context.scene.vbm, 'show_modifier_bake', icon='X', text="", emboss=False)
        r = layout.row(align=1)
        r.scale_x = 1
        r.operator('vbm.bake_geometry_nodes', text="Bake For Playback", icon='FREEZE').revert=False
        r = r.row(align=0)
        r.scale_x = 0.7
        r.operator('vbm.bake_geometry_nodes', text="Revert", icon='REW').revert=True
        
classlist.append(VBM_PT_ModifierBake)

"================================================================================================================================================="
"EXPORT"
"================================================================================================================================================="

def MeshData(src, apply_transform=False, rig=None, deformorder=[], action_pose=None, object_script_pre=None, object_script_post=None):
    checksum_key = (
        (action_pose.name if action_pose else "") + 
        (("%4d" % sum("".join(deformorder).encode('utf-8'))) if deformorder else "") + 
        (("%4d" % len(rig.data.bones)) if rig else "") + 
        (object_script_pre.name if object_script_pre else "") + 
        (object_script_post.name if object_script_post else "")
    )
    
    psum = sum
    #psum = lambda x: (print(sum(x), sum(x) % 0xFFFFFF), sum(x))[-1] % 0xFFFFFF
    checksum = int(psum([
        # Attributes
        (
            psum( [x for s in src.data.splines for p in s.points for x in p.co] ) if src.type=='CURVE' else
            (
                psum([x for v in src.matrix_local for x in v]) +
                psum([x for v in src.data.vertices for x in v.co]) +
                psum([x for l in src.data.loops for x in l.normal]) +
                psum([vge.weight for v in src.data.vertices for vge in v.groups]) +
                psum([psum(mtl.name.encode('utf-8')) for mtl in src.data.materials if mtl]) +
                psum([
                    sum(v.vector) if lyr.data_type in('FLOAT_VECTOR','FLOAT2') else 
                    sum(v.value) if lyr.data_type in('INT16_2D', 'INT32_2D') else 
                    sum(v.color) if 'COLOR' in lyr.data_type else 
                    v.value
                    for lyr in src.data.attributes for v in tuple(lyr.data)
                ])
            ) if src.type == 'MESH' else 0
        )
        # Modifiers
        + psum([
                psum(m.name.encode('utf-8')) +
                psum([x for x in [getattr(m,p.identifier) for p in m.bl_rna.properties if not p.is_readonly and not p.identifier in ('show_viewport','show_render')] if isinstance(x, (bool,int,float)) ]) +
                psum([
                    x if isinstance(x,(bool,int,float)) else sum(x.encode('utf-8')) if isinstance(x, str) else sum(v.name.encode('utf-8')) if x is bpy.types.ID else 0
                    for x in [m[k] for k in list(m.keys()) if 'Socket_' in k]
                    ] if m.type=='NODES' else []
                )
                for m in src.modifiers if ValidName(m.name)
        ]) 
        # Armatures + Actions
        + (
            psum([i*psum(bname.encode('utf-8')) for i,bname in enumerate(EvaluateDeformOrder( FindArmature(src) )[0])] if FindArmature(src) else [0])+
            psum([x for fc in ActionChannels(action_pose) for k in fc.keyframe_points for x in k.co] if action_pose else [0])
        )
        # Other
        + (
            psum([psum(line.body.encode('utf-8')) for script in [object_script_pre, object_script_post] if script for line in script.lines for c in line.body]) +
            apply_transform +
            13
        )
    ]))
    
    checksum_last = src.vbm.get('VBM_CHECKSUM'+checksum_key, -1)
    if int(checksum_last) != checksum or not src.vbm.get('VBM_DATA'+checksum_key, {}):
        printd("> Building mesh \"%s\"..." % src.name, action_pose.name if action_pose else "",  "(Checksum = %8d (%8d))" % (checksum, checksum_last))
        
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
        
        use_skinning = rig != None
        
        # Action Pose
        if rig:
            if action_pose:
                if not rig.animation_data:
                    rig.animation_data_create()
                rig.data.pose_position = 'POSE'
                rig.animation_data.action = action_pose
                rig.animation_data.action_slot = action_pose.slots[0]
                context.scene.frame_set(context.scene.frame_current)
        
        if apply_transform:
            bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
        
        def MeshScript(script, errortext):
            if script:
                context.scene[VBM_SCRIPTISEXPORTING] = True
                obj.data.update()
                err = ""
                try:
                    exec(script.as_string(), {})
                except SyntaxError as err:
                    print(errortext)
                    print(err.lineno, err.args[0])
                context.scene[VBM_SCRIPTISEXPORTING] = False
                context.view_layer.objects.active = obj
                obj.select_set(True)
        
        # Pre Script
        MeshScript(object_script_pre, "> VBM: Error executing object Pre Script (%s)" % str(object_script_pre))
        
        # Apply modifiers
        use_skinning = use_skinning and not action_pose
        for m in list(obj.modifiers):
            if not ValidName(m.name) or (m.type=='ARMATURE' and use_skinning):
                bpy.ops.object.modifier_remove(modifier=m.name)
            else:
                try:
                    bpy.ops.object.modifier_apply(modifier=m.name)
                except:
                    printd(src.name, m.type, m.name)
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
        MeshScript(object_script_post, "> VBM: Error executing object Post Script (%s)" % str(object_script_post))
        
        # Data .........................................................................................................
        def ColorAttributeLoopData(attribute):
            if attribute.domain == 'POINT':
                if attribute.data_type == 'BYTE_COLOR':
                    return np.array([attribute.data[l.vertex_index].color for l in tuple(obj.data.loops)], dtype=np.float32).reshape(-1,4)
                else:
                    return np.array([attribute.data[l.vertex_index].color for l in tuple(obj.data.loops)], dtype=np.float32).reshape(-1,4)
            else:
                attribute_data = np.empty(len(obj.data.loops)*4, dtype=np.float32)
                attribute.data.foreach_get('color', attribute_data)
                return attribute_data.reshape(-1,4)
        
        uvlyr = obj.data.uv_layers.get("UVMap", obj.data.uv_layers[0])
        vclyr = obj.data.color_attributes[obj.data.color_attributes.render_color_index]
        uvdata = [tuple((uv.vector[0], 1-uv.vector[1])) for uv in uvlyr.uv]
        vcdata = ColorAttributeLoopData(vclyr)
        if sum([x for v in vcdata for x in v]) == 0:
            vcdata = [(1,1,1,1) for v in vcdata]
        
        bonemap = {vg.index: deformorder.index(vg.name) for vg in obj.vertex_groups if vg.name in deformorder}
        skinning = [ [ (bonemap[vge.group], vge.weight) for vge in v.groups if vge.weight > 0.0 and vge.group in bonemap.keys()] for v in obj.data.vertices ]
        [v.sort(key=lambda x: -x[1]) for v in skinning]  # Sort by weight
        skinning = [ (x+[(0,0.0), (0,0.0), (0,0.0), (0,0.0)])[:4] for x in skinning ]    # Add padding, Clamp to 4
        skinning = [ [(b,w/s) for b,w in v[:4]] for v in skinning for s in [sum([w for b,w in v[:4]])+0.00000001] ] # Normalize weights
        
        # Compose ..............................................................................................................
        verts, loops, tris = tuple(obj.data.vertices), tuple(obj.data.loops), tuple(obj.data.loop_triangles)
        vgoutline = obj.vertex_groups.get('OUTLINEWEIGHT', None).index if 'OUTLINEWEIGHT' in list(obj.vertex_groups.keys()) else -1
        otdata = (np.array([([vge.weight for vge in v.groups if vge.group == vgoutline]+[1.0])[0] for v in verts])*255.0).astype(np.uint8)
        
        mtlvbs = {}
        material_count = len(obj.data.materials)
        material_indices = list(range(0, material_count)) if material_count > 0 else [0]
        for material_index in material_indices:
            mtl = obj.data.materials[material_index] if material_count > 0 else None
            mtlloops = [int(l) for p in tris if p.material_index == material_index for l in p.loops]
            if mtlloops:
                mtlname = mtl.name if mtl else ""
                if mtlname not in mtlvbs:
                    mtlvbs[mtlname] = {k:b'' for k in ATTRIBUTE_NAME}
                
                mtlvbs[mtlname]['POS'] += b''.join([Pack('fff', *verts[loops[l].vertex_index].co) for l in mtlloops])
                mtlvbs[mtlname]['COL'] += b''.join([Pack('ffff', *vcdata[l]) for l in mtlloops])
                mtlvbs[mtlname]['UVS'] += b''.join([Pack('ff', *uvdata[l]) for l in mtlloops])
                mtlvbs[mtlname]['NOR'] += b''.join([Pack('fff', *loops[l].normal) for l in mtlloops])
                mtlvbs[mtlname]['TAN'] += b''.join([Pack('fff', *loops[l].tangent) for l in mtlloops])
                #mtlvbs[mtlname]['BTN'] += b''.join([PackVector('f', loops[l].bitangent) for l in mtlloops])
                mtlvbs[mtlname]['BON'] += b''.join([Pack('ffff', *[b for b,w in skinning[loops[l].vertex_index]]) for l in mtlloops])
                mtlvbs[mtlname]['WEI'] += b''.join([Pack('ffff', *[w for b,w in skinning[loops[l].vertex_index]]) for l in mtlloops])
                
                for vclyr in obj.data.color_attributes:
                    if vclyr.name not in mtlvbs[mtlname].keys():
                        mtlvbs[mtlname][vclyr.name] = b''
                    attribute_data = ColorAttributeLoopData(vclyr)
                    mtlvbs[mtlname][vclyr.name] += b''.join([Pack('ffff', *attribute_data[l]) for l in mtlloops])
                for uvlyr in obj.data.uv_layers:
                    if uvlyr.name not in mtlvbs[mtlname].keys():
                        mtlvbs[mtlname][uvlyr.name] = b''
                    mtlvbs[mtlname][uvlyr.name] += b''.join([PackVector('f', uvlyr.uv[l].vector) for l in mtlloops])
                
        if src.vbm.get('VBM_DATA'+checksum_key, None):
            del src.vbm['VBM_DATA'+checksum_key]
        src.vbm['VBM_DATA'+checksum_key] = {mtlname: {streamkey: zlib.compress(stream) for streamkey,stream in streams.items()} for mtlname,streams in mtlvbs.items()}
        src.vbm['VBM_CHECKSUM'+checksum_key] = checksum
    return {mtlname: {streamkey: zlib.decompress(streamcompressed) for streamkey,streamcompressed in mtlstreams.items()} for mtlname,mtlstreams in src.vbm['VBM_DATA'+checksum_key].items()}

def ActionFcurves(action):
    return (
        anim_utils.action_get_channelbag_for_slot(action, action.slots[0]).fcurves if BLENDER_5_0 else
        action.fcurves
    )
def AnimData(action, rig):
    if not rig:
        return {}
    
    checksum = sum(np.array([x for x in (
        [action.vbm.clean_on_bake] +
        ([x for b in rig.data.bones for v in (b.head_local, b.tail_local) for x in v] if rig else []) +
        ([i*ord(x) for i,bname in enumerate(EvaluateDeformOrder(rig)[0]) for x in bname] if rig else []) +
        [x for fc in ActionFcurves(action) for k in fc.keyframe_points for x in k.co] +
        [len(fc.modifiers) for fc in ActionFcurves(action)]
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
        printd("> Baking animation", action.name)
        
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
            frame_start=int(action.curve_frame_range[0]), frame_end=int(action.curve_frame_range[1]+1), step=1, 
            only_selected=False, visual_keying=True, clear_constraints=True, clear_parents=False, 
            use_current_action=True, clean_curves=action.vbm.clean_on_bake, 
            bake_types={'POSE'}, channel_types={'LOCATION', 'ROTATION', 'SCALE'}
        )
        
        fcurves = ActionFcurves(proxy.animation_data.action)
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
    if image.has_data:
        checksum = sum(tuple(image.pixels)) + palette_max + image.size[0] + image.size[1]
        if 1 or image.vbm.get('VBM_CHECKSUM', -1) != checksum:
            srcpixels = np.frombuffer((np.array(image.pixels)*255).astype(np.uint8).tobytes(), dtype=np.uint32)
            w,h = image.size
            srcpixels = srcpixels.reshape(-1,w)[::-1].flatten()     # Flip image pixels
            pixels = srcpixels[:]
            palette = list(set(pixels))
            
            # Reduce number of colors while palette count is higher than max
            n1 = len(palette)
            if n1 > 0:
                # Old Method
                if w*h >= 1024*1024:
                    p = 1
                    pbytes = np.array(tuple(pixels.tobytes()), dtype=np.uint8)
                    if image.alpha_mode == 'NONE':
                        pbytes |= 0xFF000000
                    while len(palette) >= palette_max:
                        p += 1
                        pixels = np.frombuffer((pbytes // p) * p, dtype=np.uint32)
                        palette = list(set(pixels))
                    printd(image.name, "| Palette ", n1, "->", len(palette), "| P =", p)
                # Palette Map, maintaining colors used in image
                elif len(palette) < palette_max:
                    newpixels = pixels
                    srcpalette = np.unique(pixels)
                    for pmask in (0xf7f7f7f7, 0xf0f0f0f0, 0xaaaaaaaa, 0xa2a2a2a2, 0x88888888):
                        palette_map = { x&pmask: i for i,x in enumerate(srcpalette) }
                        newpixels = tuple([srcpalette[ palette_map[x&pmask] ] for x in pixels])
                        palette = list(set(newpixels))
                        if len(palette) < palette_max:
                            break
                    pixels = newpixels
                    
            palette.sort()
            palette = tuple(palette)
            indices = [palette.index(x) for x in pixels]
            
            image.vbm['VBM_DATA'] = (zlib.compress(np.array(palette, dtype=np.uint32)), zlib.compress(np.array(indices, dtype=np.uint32)), tuple(image.size))
            image.vbm['VBM_CHECKSUM'] = checksum
    else:
        printd("! Image \"%s\" had no data!" % (image.name if image else "(None)"), len(image.vbm.get('VBM_DATA', [None, None])))
    
    if image.vbm.get('VBM_DATA', None):
        palette = np.frombuffer( zlib.decompress(image.vbm['VBM_DATA'][0]), dtype=np.uint32 )
        indices = np.frombuffer( zlib.decompress(image.vbm['VBM_DATA'][1]), dtype=np.uint32 )
        width, height = image.vbm.get('VBM_DATA', [0,0,image.size])[2] if len(image.vbm['VBM_DATA']) >= 3 else image.size
    else:
        palette = [0]
        indices = [0]*image.size[0]*image.size[1]
        width, height = image.vbm.get('VBM_DATA', [0,0,image.size])[2]
    
    if ( image.alpha_mode.upper() == 'NONE' ):
        palette = palette | 0xFF000000
    return (palette, indices, (width, height))

# ===================================================================================================================
class VBMMesh:
    def __init__(self, name, material=None, streams={}):
        self.name = name
        self.material = material
        self.streams = {k: v[:] for k,v in streams.items()}
        self.layer_mask = ~0
        self.node_index = -1
    
    def transform(self, matrix):
        self.streams['POS'] = mul_v3n_v3nf_m4(np.frombuffer(self.streams['POS'], dtype=np.float32).reshape(-1,3), 1.0, matrix).tobytes()
        self.streams['NOR'] = mul_v3n_v3nf_m4(np.frombuffer(self.streams['NOR'], dtype=np.float32).reshape(-1,3), 0.0, matrix).tobytes()
    def join(self, mesh):
        if len(self.streams.keys()) == 0:
            self.streams = {k: v[:] for k,v in mesh.streams.items()}
        else:
            for k,v in mesh.streams.items():
                if k in self.streams:
                    self.streams[k] += v
    def map_stream(self, dest_key, src_key, default_vector):
        if src_key == "":
            return
        # Copy src to destination
        if src_key in self.streams.keys():
            self.streams[dest_key] = self.streams[src_key][:]
        # Fill destination with default
        else:
            loop_count = len(self.streams['POS']) // 12
            self.streams[dest_key] = np.array(default_vector, np.float32).tobytes()*loop_count

class VBMNode:
    def __init__(self, parent, name, layer_mask, matrix, data_type="000", data_index=-1, dissolve=False):
        self.name = name
        self.parent = parent
        self.flags = 0
        self.layer_mask = layer_mask if layer_mask is int else LayermaskToInt(layer_mask)
        self.collision_mask = 0
        self.matrix = matrix
        self.depth = 0
        self.data_type = data_type
        self.data_index = data_index
        self.data = {}
        self.mesh = None    # VBMMesh
        self.prism = None   # VBMMesh
        self.dissolve = dissolve
        self.collection = None
    
    def transform(self, matrix):
        if self.mesh:
            self.mesh.transform(matrix)
        if self.prism:
            self.prism.transform(matrix)
        self.matrix = self.matrix @ matrix
    
    def get_matrix_bind(self):
        return (self.parent.get_matrix_bind() @ self.matrix) if self.parent else self.matrix

class VBMBone:
    def __init__(self, root, parent, name="", matrix_bind=None, length=0.0, dissolve=False):
        self.root = root if root else self
        
        self.parent = parent
        self.name = name
        self.matrix = matrix_bind if matrix_bind else Matrix.Identity(4)
        self.dissolve = dissolve
        self.is_dirty = False
        self.index = None
        self.length = length
        
        if root:
            self.tree = root.tree
            self.tree.append(self)
        else:
            self.tree = [self]
            self.dissolve = True
    
    def update(self):
        tree = self.root.tree
        for b in tree:
            if isinstance(b.parent, str):
                pstr = b.parent
                b.parent = None
                for p in tree:
                    if p.name==pstr:
                        b.parent = p
                        break
    
    def calc_parent(self):
        return (self.parent if not self.parent.dissolve else self.parent.calc_parent()) if self.parent else None
    def calc_depth(self):
        return (1+self.calc_parent().calc_depth()) if self.calc_parent() else 0
    def calc_children(self):
        return [b for b in self.root.tree if b.parent==self]
    
    def print(self, include_dissolved=False):
        usedbones,_,_ = self.evaluate()
        print("+++ Deform Bones: %-3d" % len(usedbones), "+"*70)
        [print(("[%03d] " % b.index) + "| "*b.calc_depth() + b.name) for b in usedbones]
        print("+++ Deform Bones: %-3d" % len(usedbones), "+"*70)
    
    def evaluate(self):
        tree = self.root.tree
        outbones = []
        walk = lambda outbones, b: (outbones.append(b), [walk(outbones, c) for c in tree if c.calc_parent()==b])
        [walk(outbones, b) for b in [b for b in tree if not b.calc_parent() and not b.dissolve]]
        for b in outbones:
            b.index = outbones.index(b)
        return (outbones, [b.name for b in outbones], {b.name: b.calc_parent().name if b.calc_parent() else None for b in outbones})
    
    def build_from_rig(source_rig, collection=None):
        if not source_rig:
            return ([], {}, {})
        root = VBMBone(None, None)
        usednames = []
        for rig in FindAllArmatures(source_rig.children[0]):
            for b in rig.data.bones:
                if b.use_deform:
                    if b.name[0] == '^':
                        continue
                    if b.name not in usednames:
                        p = EvaluateDeformParent(rig, b)
                        b = VBMBone(root, p.name.replace("^", "") if p else None, b.name, matrix_bind=b.matrix_local, length=b.length)
                        usednames.append(b.name)
        
        if collection:
            root.update()
            leafgroups = [b.name for g in collection.vbm.bone_groups if g.add_leaf_bones for b in g.bones]
            for b in root.tree:
                if b.name in leafgroups and not b.calc_children():
                    p = b.parent
                    v = b.matrix.decompose()[0] - p.matrix.decompose()[0]
                    bname = b.name[:b.name.rfind(".00")] if ".00" in b.name else bname
                    b = VBMBone(root, b, bname+"_end", matrix_bind=Matrix.Translation(list(v)+[1.0]) @ b.matrix, length=v.length)
        
        root.update()
        return root.evaluate()

# =================================================================================================================================
def ExportModel(collection, report=True):
    printd("> Exporting model \"%s\" ***********************************************************************" % collection.name)
    
    context = bpy.context
    Clean()
    
    collectionobjects = [x for x in collection.objects]
    meshobjects = [x for x in collection.objects if x.type=='MESH' and ValidName(x.name)]
    
    action_pose = collection.vbm.action_pose
    rig = ([obj for obj in collection.all_objects if obj.type=='ARMATURE' and len(obj.children) > 0]+[None])[0]
    vbmbones, deformorder, deformmap = VBMBone.build_from_rig(rig, collection=collection)
    
    last_active_object = context.active_object
    last_rig_action = rig.animation_data.action if rig and rig.animation_data else None
    last_rig_position = rig.data.pose_position if rig else None
    
    format_mask = collection.vbm.get_format_mask()
    stride = CalcStride(format_mask)
    
    apply_transform = rig != None
    
    bone_group_source_collection = collection
    if rig and len(collection.vbm.bone_groups) == 0:
        bone_group_source_collection = rig.users_collection[0]
    bone_groups = bone_group_source_collection.vbm.bone_groups
    
    palette_max = 1024
    compress_texture = False
    
    printd("\t%02dB:"%stride, [ATTRIBUTE_NAME[i] for i in range(0,ATTRIBUTE_MAX) if format_mask&(1<<i)])
    
    meshitems = []
    collisionitems = []
    boneitems = []
    materialitems = []
    textureitems = []
    animationitems = []
    node_names = []
    
    modeldata = {k: [] for k in 'NAM VTX MTL MSH TEX PSM SWG SKE ANI OBJ'.split()}
    chunkversionmap = {}
    
    chunkversionmap['VTX'] = 1
    chunkversionmap['SKE'] = 2
    chunkversionmap['TEX'] = 2
    chunkversionmap['SWG'] = 1
    chunkversionmap['MTL'] = 1
    chunkversionmap['ANI'] = 1
    
    # Build Tree -------------------------------------------------------------------------------
    def ExportVBM_WalkCollection(filecollection, outnodes, parent, collection=None, objects=None):
        # Collection ......................................................
        if collection:
            for c in collection.children:
                if not ValidName(c.name):
                    continue
                ExportVBM_WalkCollection(filecollection, outnodes, parent, collection=c)
            objects = [obj for obj in collection.objects if not obj.parent]
        # Objects .........................................................
        if objects:
            script_pre = filecollection.vbm.object_script_pre
            script_post = filecollection.vbm.object_script_post
            usedobjects = []
            for obj in objects:
                if obj in usedobjects:
                    continue
                node = None
                dissolve = (not obj.vbm.export_enabled) or not ValidName(obj.name)
                basename = obj.name.split(".")[0]
                suffix = obj.name[obj.name.rfind("."):] if "." in obj.name else ""
                
                # Type Split
                if ValidName(obj.name):
                    # Mesh
                    if obj.type=='MESH':
                        mesh_material_groups = MeshData(obj, False, rig, deformorder, action_pose, script_pre, script_post)
                        pnode = parent
                        for mtlname,mtlstreams in mesh_material_groups.items():
                            nodename = basename+suffix
                            if obj.vbm.is_collision:
                                node = VBMNode(pnode, nodename, obj.vbm.layer_mask, obj.matrix_local, 'PSM', dissolve=dissolve)
                                node.prism = VBMMesh(obj.name+"_"+mtlname, None, mtlstreams)
                            else:
                                node = VBMNode(pnode, nodename, obj.vbm.layer_mask, obj.matrix_local, 'MSH', dissolve=dissolve)
                                node.mesh = VBMMesh(obj.name+"_"+mtlname, bpy.data.materials.get(mtlname), mtlstreams)
                            outnodes.append(node)
                    # Armature
                    elif obj.type == 'ARMATURE':
                        node = VBMNode(parent, basename+suffix, obj.vbm.layer_mask, obj.matrix_local, 'SKE', dissolve=dissolve)
                        outnodes.append(node)
                # Empty
                if obj.type=='EMPTY':
                    if obj.instance_collection:
                        node = VBMNode(parent, basename+suffix, obj.vbm.layer_mask, obj.matrix_local, dissolve=True)
                        outnodes.append(node)
                        ExportVBM_WalkCollection(filecollection, outnodes, node, collection=obj.instance_collection)
                    else:
                        node = VBMNode(parent, basename+suffix, obj.vbm.layer_mask, obj.matrix_local, dissolve=dissolve)
                        outnodes.append(node)
                # Child Objects
                if obj.children:
                    ExportVBM_WalkCollection(filecollection, outnodes, node, objects=obj.children)
                    usedobjects += list(obj.children_recursive)
                usedobjects.append(obj)
                
        return outnodes
    Clean()
    
    nodes = []
    rootnode = None
    if collection.vbm.object_add_root:
        rootnode = VBMNode(None, collection.vbm.get_name(), ~0, Matrix.Identity(4))
        nodes.append(rootnode)
    
    nodes = ExportVBM_WalkCollection(collection, nodes, rootnode, collection=collection)
    NodeDepth = lambda nd: (1+NodeDepth(nd.parent)) if nd.parent else 0
    NodeChildren = lambda nd: [x for x in nodes if x.parent == nd]
    NodeSiblings = lambda nd: [x for x in nodes if x.parent == nd.parent]
    
    # Fix Meshes
    for nd in nodes:
        # Remap streams based on names specified in collection format
        if nd.mesh:
            nd.mesh.map_stream('COL', collection.vbm.color_layer_name, collection.vbm.color_layer_default)
            nd.mesh.map_stream('UVS', collection.vbm.uv_layer_name, collection.vbm.uv_layer_default)
            nd.mesh.map_stream('UV2', collection.vbm.uv_layer_name2, collection.vbm.uv_layer_default2)
    
    # Dissolve Nodes
    for nd in nodes[::-1]:
        if nd.dissolve:
            children = NodeChildren(nd)
            if len(children) <= 1:
                for cd in NodeChildren(nd):
                    cd.parent = nd.parent
                    cd.matrix = cd.matrix @ nd.matrix
                del nodes[nodes.index(nd)]
    
    # Flatten
    if collection.vbm.object_flatten:
        for nd in nodes[::-1]:
            nd.transform(nd.get_matrix_bind())
            nd.matrix = Matrix.Identity(4)
            if nd != rootnode:
                nd.parent = rootnode
    
    # Merge Meshes
    mesh_join_type = collection.vbm.mesh_join_type
    if mesh_join_type != 'NONE':
        printd("> Joining by", mesh_join_type)
        hit = 1
        while hit:
            hit = 0
            for ndstart in nodes[::-1]:
                if ndstart.mesh:
                    similar_nodes = []
                    if mesh_join_type == 'MATERIAL':
                        material = ndstart.mesh.material
                        similar_nodes = [x for x in NodeSiblings(ndstart) if x.mesh and x.mesh.material == material]
                    elif mesh_join_type == 'NAME':
                        name = ClipName(ndstart.name)
                        similar_nodes = [x for x in NodeSiblings(ndstart) if x.mesh and ClipName(x.name) == name]
                    
                    if len(similar_nodes) > 1:
                        prefix = os.path.commonprefix([x.name for x in similar_nodes])[:-1]
                        prefix_len = len(prefix)
                        printd("Joining", "\""+prefix+"\"", "["+", ".join([x.name[prefix_len:] for x in similar_nodes])+"]", "...")
                        hit = 1
                        ndroot = similar_nodes[0]
                        for nd in similar_nodes:
                            nd.mesh.transform(nd.matrix)
                        ndroot.matrix = Matrix.Identity(4)
                        for nd in similar_nodes[1:]:
                            ndroot.mesh.join(nd.mesh)
                        for nd in similar_nodes[1:][::-1]:
                            del nodes[nodes.index(nd)]
                        break # <- Start over since nodes were deleted-- List is invalid
    
    # Final node params
    for node_index,nd in enumerate(nodes):
        if nd.mesh:
            nd.mesh.layer_mask = nd.layer_mask
            nd.mesh.node_index = node_index
        if nd.prism:
            nd.prism.layer_mask = nd.layer_mask
            nd.prism.node_index = node_index
    
    # Nodes ------------------------------------------------------------------------------
    nodemeshes = [nd.mesh for nd in nodes if nd.mesh]
    nodeprisms = [nd.prism for nd in nodes if nd.prism]
    nodematerials = []
    [nodematerials.append(mesh.material) for mesh in nodemeshes if mesh.material not in nodematerials]
    [nodematerials.append(mtl) for item in collection.vbm.material_overrides for mtl in [item.override if item.override else item.material] if mtl not in nodematerials]
    nodematerials = [x for x in nodematerials if x]
    
    printd("Nodes: %d | Meshes: %d" % (len(nodes), len(nodemeshes)))
    ndlast = None
    ndlasthits = 0
    for nd in nodes:
        nodename = nd.name
        if collection.vbm.clip_object_name:
            nodename = ClipName(nodename)
        nodename= FixName(nodename)
        
        # Debug Print
        if nd.name[:-3]==ndlast:
            ndlasthits += 1
        else:
            if ndlasthits > 1:
                printd("...+%d" % ndlasthits)
            printd( ("[%3d]"%nodes.index(nd)) + (" |"*(NodeDepth(nd))), nodename, [nd.mesh.material.name if nd.mesh.material else "(None)"] if nd.mesh else "", nd.data_type, nd.data_index)
            ndlasthits = 0
        ndlast = nd.name[:-3]
        
        # Apply transform to rig
        if nd.mesh and rig:
            nd.mesh.transform(nd.matrix)
            nd.mesh.node_index = nodes.index(nd)
            nd.matrix = Matrix.Identity(4)
        
        if nd.mesh:
            nd.data_index = nodemeshes.index(nd.mesh)
        
        nd.flags |= VBM_NODEFLAGS_USETRANSFORMCOMPONENTS
        objbin = b''
        objbin += Pack('i', nd.flags)          # Flags
        objbin += Pack('i', nd.layer_mask)     # Layermask
        objbin += Pack('i', 0)                 # Collisionmask
        if nd.flags & VBM_NODEFLAGS_USETRANSFORMCOMPONENTS:
            loc, quat, scale = nd.matrix.decompose()
            objbin += Pack('fff',*loc)+Pack('ffff',*quat)+Pack('fff',*scale) + b'\0\0\0\0'*6        # Relative Transform + padding
        else:
            objbin += PackMatrix(nd.matrix)        # Relative Matrix
        objbin += Pack('i', nodes.index(nd.parent) if nd.parent else -1)   # Parent Index
        objbin += Pack('BBBB', *(bytes(nd.data_type[:3], 'utf-8')+b'\0'))      # Data Type
        objbin += Pack('i', nd.data_index)      # Data Index
        objbin += PackString(nodename)          # Name
        modeldata['OBJ'].append(objbin)
    
    # Vertex Buffer ----------------------------------------------------------------------
    
    # Build contiguous attribute streams of all meshes
    netstreams = {k: b'' for k in ATTRIBUTE_NAME}
    for mesh in nodemeshes:
        streams = mesh.streams
        for k in ATTRIBUTE_NAME:
            netstreams[k] += streams[k]
    
    # Convert stream data (normalize, floats->bytes, etc.)
    vtx_streams = []
    vtx_spaces = []
    stride = 0
    for a,k in enumerate(ATTRIBUTE_NAME):
        if format_mask & (1<<a):
            isbyte = (format_mask & (1<<(a+16))) != 0
            stream = netstreams[k]
            space = 4*ATTRIBUTE_LENGTH[a]
            # Normalize Normals
            if k == 'NOR':
                vectors = np.frombuffer(stream, dtype=np.float32).reshape(-1,3)
                norms = np.linalg.norm(vectors, axis=1, keepdims=True)
                
                if isbyte:
                    stream_w = np.zeros(len(vectors), dtype=np.float32)     # W channel = 0.0 for normals
                    stream = (np.hstack([((vectors / norms)*0.5+0.5).reshape(-1,3), stream_w.reshape(-1,1)])*255.0).astype(dtype=np.uint8).tobytes()
                    space = 4
                else:
                    stream = (vectors / norms).tobytes()    # Raw float stream
            # Convert Float to Byte
            elif k == 'COL' and isbyte:
                vectors = np.frombuffer(stream, dtype=np.float32).reshape(-1, 4)
                
                gamma = 0.4545 if collection.vbm.color_is_srgb else 0.0
                if gamma != 0.0:
                    vectors = vectors ** (gamma, gamma, gamma, 1.0)
                
                if isbyte:
                    stream = (vectors*255.0).astype(dtype=np.uint8).tobytes()   # Multiply by 255, then convert to uint8
                else:
                    stream = vectors.tobytes()  # Raw float stream
                space = 4
            elif k == 'BON' and isbyte:
                stream = (np.frombuffer(stream, dtype=np.float32).reshape(-1, 4)).astype(dtype=np.uint8).tobytes()
                space = 4
            elif k == 'WEI' and isbyte:
                stream = (np.frombuffer(stream, dtype=np.float32).reshape(-1, 4)*255.0).astype(dtype=np.uint8).tobytes()
                space = 4
            
            vtx_streams.append(np.array(tuple(stream), dtype=np.uint8).reshape(-1, space))
            stride += int(space)
    vtx_interleaved = np.hstack(vtx_streams).flatten().tobytes()    # Stack attribute streams per vertex (PPPCCCCUU, PPPCCCCUU, ...)
    
    if len(vtx_interleaved) == 0:
        print("! WARNING: Length of vertex buffer == 0")
    
    # Compose output
    compress_vertex_buffer = collection.vbm.use_vtx_compression != 0
    
    buffer_size = len(vtx_interleaved)
    loop_count = len(vtx_interleaved) // stride
    
    flags = (
        (VBM_VTX_COMPRESSED * compress_vertex_buffer)
    )
    
    outvtx = b''
    outvtx += Pack('I', flags)
    outvtx += Pack('I', format_mask)
    outvtx += Pack('I', buffer_size)
    
    if not compress_vertex_buffer:
        outvtx += vtx_interleaved
    else:
        print("! TODO: Redo VTX compression")
    modeldata['VTX'] = outvtx
    
    # Meshes ------------------------------------------------------------------------------
    if collection.vbm.export_meshes:
        loop_offset = 0
        for mesh_index, mesh in enumerate(nodemeshes):
            streams = mesh.streams
            positions = np.frombuffer(streams['POS'], dtype=np.float32).reshape(-1, 3)
            position_channels = positions.T
            bounds = ( [position_channels[i].min() for i in (0,1,2)] , [position_channels[i].max() for i in (0,1,2)])
            loop_count = len(positions)
            flags = 0
            
            meshbin = b''
            meshbin += Pack('i', flags)     # Flags
            meshbin += Pack('i', mesh.layer_mask)     # Layermask
            meshbin += PackString(FixName(mesh.name))     # Mesh name
            meshbin += Pack('i', -1)    # Node Index
            meshbin += Pack('i', nodematerials.index(mesh.material) if mesh.material else -1)     # Material Index
            meshbin += Pack('i', loop_offset)     # Loop Start
            meshbin += Pack('i', loop_count)     # Loop Count
            meshbin += PackVector('f', bounds[0]) + PackVector('f', bounds[1])     # Bounds
            modeldata['MSH'].append(meshbin)
            loop_offset += loop_count
    
    # Prisms ------------------------------------------------------------------------------
    if collection.vbm.export_meshes:
        for prism_index, prism in enumerate(nodeprisms):
            streams = prism.streams
            positions = np.frombuffer(streams['POS'], dtype=np.float32).reshape(-1, 3)
            loop_count = len(positions)
            flags = 0
            
            prismbin = b''
            prismbin += Pack('i', flags)     # Flags
            prismbin += Pack('i', prism.node_index)    # Node Index
            prismbin += Pack('i', loop_count)    # Loop Count
            prismbin += positions.tobytes()    # Vertices
            modeldata['PSM'].append(prismbin)
    
    # Materials --------------------------------------------------------------------------
    texturenames = []
    if collection.vbm.export_materials:
        for mtl in nodematerials:
            mtl = collection.vbm.get_material_override(mtl)
            flags = (
                VBM_MATERIALFLAGS_TRANSPARENT * (mtl.vbm.transparent) |
                VBM_MATERIALFLAGS_USECULLING * (mtl.use_backface_culling) |
                VBM_MATERIALFLAGS_FLIPFACES * (mtl.vbm.flip_faces) |
                VBM_MATERIALFLAGS_USEDEPTH * (mtl.vbm.use_depth)
            )
            
            texturenodes = mtl.vbm.get_imagenodes()
            texturenodes = [nd if nd and nd.image else None for nd in texturenodes]
            for nd in texturenodes:
                if nd and nd.image and nd.image.name not in texturenames:
                    texturenames.append(nd.image.name)
            
            mtlbin = b''
            mtlbin += Pack('i', flags)
            mtlbin += PackString(FixName(mtl.name))  # Material Name
            mtlbin += PackString(mtl.vbm.shader if mtl.vbm.shader else context.scene.vbm.shader_default)  # Shader Name
            
            # 8(?) Textures max
            mtlbin += Pack('i', len(texturenodes))
            for texturenode in texturenodes:
                if texturenode:
                    texflags = (
                        (VBM_MTLTEXFLAG_FILTERLINEAR * (texturenode.interpolation.upper() != 'CLOSEST')) |
                        (VBM_MTLTEXFLAG_EXTEND * (texturenode.extension=='EXTEND'))
                    )
                else:
                    texflags = 0
                mtlbin += Pack('i', texflags)  # Texture Flags
                mtlbin += Pack('i', texturenames.index(texturenode.image.name) if texturenode else -1)   # Texture Index
                mtlbin += PackString(texturenode.image.name if texturenode else "")  # Texture Name
            modeldata['MTL'].append(mtlbin)
    
    # Images --------------------------------------------------------------------------------
    if collection.vbm.export_textures:
        for texturename in texturenames:
            image = bpy.data.images.get(texturename)
            
            if image:
                w,h = image.size
                is_compressed = w*h >= 256
                flags = (
                    (VBM_TEXTUREFLAG_SRGB * (image.colorspace_settings.name.upper()=='SRGB')) |
                    (VBM_TEXTUREFLAG_COMPRESSED * is_compressed) |
                    0
                )
                
                imagebin = b''
                imagebin += Pack('i', flags)
                imagebin += PackString(image.name)
                
                if 1:
                    rowstep = -1 if BLENDER_5_0 else -1
                    if image.source=='GENERATED':
                        pixeldata = np.array(list(image.generated_color)*w*h, dtype=np.float32).flatten()
                    else:
                        if not image.pixels:
                            print("! Image \"%s\" has no data!" % image.name)
                            pixeldata = np.ones(w*h)
                        else:
                            pixeldata = (np.array(image.pixels, dtype=np.float32)*255.0).astype(np.uint8).reshape(-1, w*4)[::rowstep].flatten()
                    if is_compressed:
                        pixels_compressed = zlib.compress(pixeldata)
                    else:
                        pixels_compressed = bytes(pixeldata)
                    imagebin += Pack('IIII', w, h, 0, len(pixels_compressed))
                    imagebin += pixels_compressed
                else:
                    palette, indices, size = ImageData(image, palette_max)
                    w,h = size
                    index_dtype = 'H' if len(palette) >= 256 else 'B'
                    
                    imagebin += Pack('III', w, h, len(palette))
                    imagebin += PackVector('I', palette)
                    imagebin += PackVector(index_dtype, indices)    # Switch data type based on palette count
                modeldata['TEX'].append(imagebin)
    
    # Bones -------------------------------------------------------------------------------
    if rig and collection.vbm.export_skeleton:
        modeldata['SKE'] = []
        
        for bone_index, b in enumerate(vbmbones):
            bname = b.name
            bone_group = bone_group_source_collection.vbm.find_bonegroup(bname)
            layer_mask = LayermaskToInt(bone_group.layer_mask if bone_group else bone_group_source_collection.vbm.bone_layer_mask_default)
            collisionmask = LayermaskToInt(bone_group.collision_mask) if bone_group else layer_mask
            flags = (
                (VBM_BONEFLAGS_SWINGBONE if bone_group and bone_group.swing_enabled else 0)
            )
            parent_index = deformorder.index(deformmap[bname]) if deformmap[bname] else -1
            
            bonebin = b''
            bonebin += Pack('i', flags)             # Flags
            bonebin += Pack('i', layer_mask)         # Layermask
            bonebin += Pack('i', collisionmask)         # Collisionmask
            bonebin += PackMatrix(b.matrix)  # Bind Matrix
            bonebin += Pack('i', parent_index)    # Parent Node Index
            bonebin += Pack('f', b.length)          # Bone Length
            bonebin += Pack('f', bone_group.radius if bone_group else 0.0) # Bone Radius
            bonebin += PackString(FixName(bname))   # Node Name
            
            if flags & VBM_BONEFLAGS_SWINGBONE:
                bonebin += Pack('f', bone_group.stiffness)
                bonebin += Pack('f', bone_group.damping)
                bonebin += Pack('f', bone_group.limit)
                bonebin += Pack('f', bone_group.force_strength)
            
            modeldata['SKE'].append(bonebin)
        
        for group_index, g in enumerate(bone_group_source_collection.vbm.bone_groups):
            bonenames = [b.name for b in g.bones if b.name in deformorder]
            boneindexmap = {bname: deformorder.index(bname) for bname in bonenames}
            segments = [s for s in g.segments if s.start_bone in bonenames or s.end_bone in bonenames] if g.swing_enabled else []
            
            groupbin = b''
            groupbin += PackString(g.name)                          # Group Name
            groupbin += Pack('i', LayermaskToInt(g.layer_mask))     # Layer Mask
            groupbin += Pack('i', LayermaskToInt(g.collision_mask)) # Collision Mask
            groupbin += Pack('i', len(bonenames))                   # Bone Count
            groupbin += Pack('i', len(segments))                    # Segments Count
            for bname in bonenames:
                groupbin += Pack('i', deformorder.index(bname))     # Bone Index
            for s in segments:
                groupbin += Pack('i', boneindexmap.get(s.start_bone, -1))  # Start Bone
                groupbin += Pack('i', boneindexmap.get(s.end_bone, -1))  # End Bone
            modeldata['SWG'].append(groupbin)
    
    # Actions -----------------------------------------------------------------------------
    Clean()
    if collection.vbm.export_animations:
        for actionitem in collection.vbm.actions:
            if not actionitem.export_enabled:
                continue
            
            action = actionitem.action
            actionname = action.name
            if collection.vbm.clip_action_name:
                actionname = ClipName(actionname)
            
            bonemask = int(sum([1<<i for i,x in enumerate(action.vbm.layer_mask) if x]))
            
            bonedata = AnimData(action, rig)
            bonedata = {bname: curves for bname,curves in bonedata.items() if bone_group_source_collection.vbm.get_bone_layer_mask(bname) & bonemask}
            
            propcurves = [fc for fc in ActionFcurves(action) if "pose.bones" not in fc.data_path]
            propdata = {fc.data_path: [] for fc in propcurves}
            [propdata[fc.data_path].append([tuple(k.co) for k in fc.keyframe_points]) for fc in propcurves]
            propdata = { k.split("\"")[1] if "\"" in k else k :channels for k,channels in propdata.items() }
            
            curvedata = {name:channels for name,channels in list(bonedata.items())+list(propdata.items())}
            
            frame_start = int(action.frame_range[0])
            frame_end = int(action.frame_range[1])
            frame_rate = int(action.vbm.frame_rate)
            flags = (
                ( VBM_ANIMATIONFLAGS_CURVENAMES * 1 ) | # Curve names
                ( VBM_ANIMATIONFLAGS_CURVELOOP * action.use_cyclic ) |  # Curve Loop
                ( VBM_ANIMATIONFLAGS_MARKERS * (len(action.pose_markers) > 0) )  # Curve Markers
            )
            
            outaction = b''
            outaction += Pack('i', flags)  # Flags
            outaction += PackString(FixName(actionname))  # Name
            outaction += Pack('i', int((action.frame_end-action.frame_start+1)))     # Duration
            outaction += Pack('i', context.scene.render.fps)     # FPS
            outaction += Pack('i', 0)     # Loop Point
            outaction += Pack('i', len(curvedata.values()))  # Curve Count
            outaction += Pack('i', sum([len(curve) for curve in curvedata.values()]))  # Channel Count
            outaction += Pack('i', sum([len(channel) for curve in curvedata.values() for channel in curve]))  # Keyframe Count
            outaction += Pack('i', len(bonedata.values()))  # Props View Index / Number of bone curves
            
            # Pose Markers
            if ( flags & VBM_ANIMATIONFLAGS_MARKERS ):
                outaction += Pack('i', len(action.pose_markers))
                for m in action.pose_markers:
                    outaction += PackString(m.name)     # Marker Name
                    outaction += Pack('f', m.frame)     # Marker Frame
            
            # Curve Names
            if flags & VBM_ANIMATIONFLAGS_CURVENAMES:
                for curvename, channels in curvedata.items():
                    outaction += PackString(FixName(curvename))  # Curvename
            
            # Bone Curves + Property Curves 
            curveviewbin = b''
            channelviewbin = b''
            keyframebin = b''
            
            curve_index = 0
            channel_offset = 0
            keyframe_offset = 0
            for curvename, channels in curvedata.items():
                # Adding to total bytearray in chunks is faster than by value:
                channelchunk = b''
                keyframechunk = b''
                curveviewbin += Pack('ii', channel_offset, len(channels))    # <Channel Offset, Count>
                for channel in channels:
                    channelchunk += Pack('ii', keyframe_offset, len(channel))    # <Keyframe Offset, Count>
                    for k in channel:
                        keyframechunk += Pack('ff', k[0], k[1])    # <Frame, Value>
                    keyframe_offset += len(channel)
                    channel_offset += 1
                
                channelviewbin += channelchunk
                keyframebin += keyframechunk
                curve_index += 1
            
            outaction += curveviewbin
            outaction += channelviewbin
            outaction += keyframebin
            
            modeldata['ANI'].append(outaction)
            collection.vbm.action_index = collection.vbm.action_index
    
    # Cleanup ------------------------------------------------------------------------------
    Clean()
    
    context.view_layer.objects.active = last_active_object
    if rig and rig.animation_data:
        rig.animation_data.action = last_rig_action
        rig.data.pose_position = last_rig_position
    
    # Output ------------------------------------------------------------------------------
    modeldata['NAM'] = PackString(FixName(collection.name))                 # Model Name
    modeldata['END'] = Pack('I', 0)  # End chunk
    
    printd([", ".join([ (("%s[%d]" % (type, len(data)))) if isinstance(data, list) else "{%s}"%type for type,data in modeldata.items() if data])])
    
    modelchunks = {
        chunktype: ((Pack('I', len(data)) + b''.join(data)) if isinstance(data, list) else data)
        for chunktype, data in modeldata.items() if data
    }
    
    modelbin = PackChars("VBM") + Pack('B', 5) + b''.join([
        PackString(chunktype)[:3] +             # Type
        Pack('B',chunkversionmap.get(chunktype, 0)) +  # Version
        Pack('I', len(chunk)) +                 # Length
        chunk                                   # Data
        for chunktype, chunk in modelchunks.items() 
    ])
    
    # Compress
    if collection.vbm.use_compression:
        modelbin = zlib.compress(modelbin)
    
    # Write to file -----------------------------------------------------------------------
    filepath = collection.vbm.get_name()
    
    # Filepath is full path
    if "/" in filepath and os.path.isdir(os.path.split(filepath)[0]):
        fname = FixName(os.path.split(filepath)[1])
        filepath = os.path.split(filepath)[0]+"/" + fname + VBM_FILEEXT
    # Prepend data path to filepath
    else:
        if context.scene.vbm.data_path:
            datapath = bpy.path.abspath(context.scene.vbm.data_path)
        else:
            datapath = bpy.path.abspath("/")
        if datapath[-1] not in "/\\":
            datapath += "/"
        filepath = datapath + FixName(os.path.splitext(collection.vbm.get_name())[0]) + VBM_FILEEXT
    
    filepath = filepath.replace("\\", "/")  # Causes issues on Linux if slashes aren't consistent
    f = open(os.path.abspath(bpy.path.abspath(filepath)), "wb")
    f.write(modelbin)
    f.close()
    
    #print("< File written to \"%s\" (%4.4f MB)" % (("..." if len(filepath) > 64 else "")+filepath[-64:], len(modelbin)/1_000_000))
    print("< File written to \"%s\" (%4.4f MB)" % (filepath, len(modelbin)/1_000_000))

"======================================================================================================"
"GPU"
"======================================================================================================"

PI = 3.141592653589793

VBM_SWINGCIRCLEPRECISION = 16
VBM_SWINGLIMITN = 5
VBM_SWINGLIMITSEP = 0.25*PI / VBM_SWINGLIMITN

vbm_shader = gpu.shader.from_builtin('UNIFORM_COLOR')
ringverts = [(x,y) for j in range(0, VBM_SWINGCIRCLEPRECISION) for i in [j,j+1] for a in [(i/VBM_SWINGCIRCLEPRECISION)*PI*2] for x,y in [(cos(a), sin(a))]]
batch_ring_y = batch_for_shader(vbm_shader, 'LINES', {"pos": [(x,0,y) for x,y in ringverts] + [(.1,1,0), (0,1.2,0), (0,1.2,0), (-.1,1,0)] })
batch_ring_y1 = batch_for_shader(vbm_shader, 'LINES', {"pos": [(x,1,y) for x,y in ringverts] + [(.1,1,0), (0,1.2,0), (0,1.2,0), (-.1,1,0)] })
batch_swing_limit_x = batch_for_shader(vbm_shader, 'LINES', {"pos": [(0,0,0), (0,1,0), (0,1,0), (0,cos(VBM_SWINGLIMITSEP),sin(VBM_SWINGLIMITSEP)), (0,cos(VBM_SWINGLIMITSEP),sin(VBM_SWINGLIMITSEP)), (0,0,0)] })
batch_swing_limit_z = batch_for_shader(vbm_shader, 'LINES', {"pos": [(0,0,0), (0,1,0), (0,1,0), (sin(VBM_SWINGLIMITSEP),cos(VBM_SWINGLIMITSEP),0), (sin(VBM_SWINGLIMITSEP),cos(VBM_SWINGLIMITSEP),0), (0,0,0)] })
batch_sphere = batch_for_shader(vbm_shader, 'LINES', {"pos": [(x,y,0) for x,y in ringverts] + [(x,0,y) for x,y in ringverts] + [(0,x,y) for x,y in ringverts]})
batch_capsule_head = batch_for_shader(vbm_shader, 'LINES', {"pos": [(x,0,y) for x,y in ringverts] + [(0,-y,x) for x,y in ringverts[:len(ringverts)//2]] + [(x,-y,0) for x,y in ringverts[:len(ringverts)//2]]})
batch_capsule_tail = batch_for_shader(vbm_shader, 'LINES', {"pos": [(x,0,y) for x,y in ringverts] + [(0,y,x) for x,y in ringverts[:len(ringverts)//2]] + [(x,y,0) for x,y in ringverts[:len(ringverts)//2]]})
batch_capsule_shell = batch_for_shader(vbm_shader, 'LINES', {"pos": [(1,0,0),(1,1,0), (-1,0,0),(-1,1,0), (0,0,1),(0,1,1), (0,0,-1),(0,1,-1)]})
batch_cone = batch_for_shader(vbm_shader, 'TRIS', {"pos": [ v for i in range(0, 16) for v in [ (0,0,0), (cos(PI*i/8), 1, sin(PI*i/8)), (cos(PI*(i+1)/8), 1, sin(PI*(i+1)/8)) ] ]})
batch_line = batch_for_shader(vbm_shader, 'LINES', {"pos": [(0,0,0),(0,1,0)]})

VBM_COLOR_SWINGAXIS = (Vector((1,0,.5,0.5)), Vector((.5,1,0,0.5)), Vector((0,.5,1,0.5)))
VBM_COLOR_SWINGLIMIT = ( Vector((.5, .4, .4, 0.1)), Vector((.4, .4, .5, 0.1)) )
VBM_COLOR_SWINGCONE = Vector((.5, .5, 1, 0.01))
VBM_COLOR_COLLIDER = Vector((1, .7, .4, 1))
VBM_COLOR_PARTICLE = ( Vector((.9, .4, .4, 0.5)), Vector((.1, .5, .1, 0.1)), Vector((.1, .1, .5, 0.1)), Vector((.4, .4, .4, 0.5)) )

VBM_GPUSWING_HDLKEY = int(time.time())
def vbm_draw_gpu():
    context = bpy.context
    # Early Exits ....................................................................
    if not context.space_data.overlay.show_overlays:
        return
    if not getattr(context.scene, 'vbm', None):
        return
    scenevbm = context.scene.vbm
    
    if scenevbm.get('VBM_GPUSWING_HDLKEY', 0) < VBM_GPUSWING_HDLKEY:
        scenevbm['VBM_GPUSWING_HDLKEY'] = VBM_GPUSWING_HDLKEY
        printd("> Updating handle key...")
    if scenevbm.get('VBM_GPUSWING_HDLKEY', 0) != VBM_GPUSWING_HDLKEY:
        return
    
    collection = ActiveCollection()
    if not getattr(collection, 'vbm', None):
        return
    collectionvbm = collection.vbm
    
    rig = context.active_object
    if rig == None or rig.type != 'ARMATURE' or rig.hide_get() or rig.mode not in ('POSE', 'OBJECT'):
        return
    
    # Staging .......................................................................
    r = context.region.data
    viewpos = r.view_location + (r.view_rotation.to_matrix() @ Vector((0,0,-1))) * r.view_distance
    
    drawqueue = [] # [ (batch, color, matrix) ]
    pbones = rig.pose.bones
    usedbones = []
    
    for group_index, bone_group in enumerate(collectionvbm.bone_groups):
        if not bone_group.show_bones:
            continue
        if scenevbm.show_swing_bones:
            color = VBM_COLOR_BONEGROUP[group_index%len(VBM_COLOR_BONEGROUP)] * Vector((.9,.9,.9,0.01))
            for bone_item in bone_group.bones:
                bname = bone_item.name
                if bname in usedbones:
                    continue
                usedbones.append(bname)
                pb = pbones.get(bname)
                if not pb:
                    continue
                if bone_group.radius > 0.0:
                    r = bone_group.radius
                    d = pb.bone.length
                    drawqueue.append( (batch_capsule_head, color, pb.matrix @ Matrix.Scale(r, 4)) )
                    drawqueue.append( (batch_capsule_tail, color, pb.matrix @ Matrix.LocRotScale((0,d,0), None, (r,r,r))) )
                    drawqueue.append( (batch_capsule_shell, color, pb.matrix @ Matrix.LocRotScale((0,0,0), None, (r,d,r))) )
        if scenevbm.show_swing_segments:
            r = 0.004
            for segment_index, segment in enumerate(bone_group.segments):
                color = Vector((1,1,1,0.5)) if segment_index == bone_group.segment_index else VBM_COLOR_BONEGROUP[group_index%len(VBM_COLOR_BONEGROUP)]
                e1 = pbones.get(segment.start_bone)
                e2 = pbones.get(segment.end_bone)
                if e1 and e2:
                    p1 = e1.matrix.decompose()[0]
                    p2 = e2.matrix.decompose()[0]
                    v = p2-p1
                    d = v.length
                    q = v.to_track_quat('Y', 'Z')
                    drawqueue.append( (batch_sphere, color, e1.matrix @ Matrix.Scale(r, 4)) )
                    drawqueue.append( (batch_sphere, color, e2.matrix @ Matrix.Scale(r, 4)) )
                    drawqueue.append( (batch_line, color, Matrix.LocRotScale(p1, q, (r,d,r))) )
                elif e1 and not e2:
                    d = pb.bone.length
                    drawqueue.append( (batch_sphere, color, e1.matrix @ Matrix.Scale(r, 4)) )
                    drawqueue.append( (batch_sphere, color, e1.matrix @ Matrix.LocRotScale((0,d,0), None, (r,r,r))) )
                    drawqueue.append( (batch_line, color, e1.matrix @ Matrix.LocRotScale((0,0,0), None, (r,d,r))) )
    
    # Render ......................................................................
    if len(drawqueue) == 0:
        return
    
    gpu.matrix.load_projection_matrix(bpy.context.region_data.perspective_matrix)
    
    colorlast = Vector((0,0,0,0))
    matrixlast = Matrix.Identity(4)
    for batch, color, matrix in drawqueue:
        if matrix != matrixlast:
            gpu.matrix.load_matrix(matrix)
            matrix = matrixlast
        if matrix != colorlast:
            vbm_shader.uniform_float("color", color)
            color = colorlast
        batch.draw(vbm_shader)
    
    gpu.matrix.load_matrix(Matrix.Identity(4)) # Reset matrix for Gizmo drawing

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
    
    bpy.types.SpaceView3D.draw_handler_add(vbm_draw_gpu, (), 'WINDOW', 'POST_VIEW')
    
def unregister():
    [bpy.utils.unregister_class(c) for c in classlist[::-1]]
    VBM_GPUSWING_HDLKEY = 1
    
if __name__ == "__main__":
    register()

