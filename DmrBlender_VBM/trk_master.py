import bpy
import os
import struct
import zlib
import sys
import mathutils

from bpy_extras.io_utils import ExportHelper
from struct import pack as Pack

# Include
try:
    from .trk_bonesettings import *
except:
    from trk_bonesettings import *

TRKVERSION = 3

FL_TRK_SPARSE = 1<<1
FL_TRK_FLOAT16 = 1<<2
FL_TRK_FLOAT64 = 1<<3

classlist = []

# TRK format
'''
    'TRK' (3B)
    TRK Version (1B)
    
    flags (1B)
    
    fps (1f)
    framecount (1I)
    numtracks (1I)
    numcurves (1I)
    duration (1f)
    positionstep (1f)
    
    tracknames[numtracks]
        namelength (1B)
        namechars[namelength]
            char (1B)
    
    matrixspace (1B)
        0 = No Matrices
        1 = LOCAL
        2 = POSE
        3 = WORLD
        4 = EVALUATED
    matrixdata[framecount]
        framematrices[numtracks]
            mat4 (16f)
    
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
                
    
    curvenames[numcurves]
        namelength (1B)
        namechars[namelength]
            char (1B)
    
    curvedata[numcurves]
        curvefrequency (1B)
        curveentry[curvefrequency]
            numframes (1I)
            arrayindex (1I)
            framepositions[numframes]
                position (1f)
            framevectors[numframes]
                value (1f)
    
    nummarkers (1I)
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
    
'''

'# =========================================================================================================================='
'# FUNCTIONS'
'# =========================================================================================================================='

def Items_GetArmatureObjects(self, context):
    return [
        (a.name, a.name, '%s' % a.name, 'ARMATURE_DATA', i)
        for i, a in enumerate(bpy.data.objects) if a.type == 'ARMATURE'
    ]

Items_ExportSpace=[
    ('NONE', 'None', "Skip this data"),
    ('LOCAL', 'Local Space', "Bone matrices are relative to bone's parent"),
    ('POSE', 'Pose Space', 'Bone matrices are relative to armature origin'),
    ('WORLD', 'World Space', 'Bone matrices are relative to world origin'),
]

Items_ExportSpaceMatrix= Items_ExportSpace + [
    ('EVALUATED', 'Evaluated', 'Matrices are evaluated up to final transform ready for shader uniform')
]

SpaceID = {item[0]: i for i, item in enumerate(Items_ExportSpaceMatrix)}

Items_UpAxis = (
    ('+x', '+X Up', 'Export action with +X Up axis'),
    ('+y', '+Y Up', 'Export action with +Y Up axis'),
    ('+z', '+Z Up', 'Export action with +Z Up axis'),
    ('-x', '-X Up', 'Export action with -X Up axis'),
    ('-y', '-Y Up', 'Export action with -Y Up axis'),
    ('-z', '-Z Up', 'Export action with -Z Up axis'),
)

Items_ForwardAxis = (
    ('+x', '+X Forward', 'Export action with +X Forward axis'),
    ('+y', '+Y Forward', 'Export action with +Y Forward axis'),
    ('+z', '+Z Forward', 'Export action with +Z Forward axis'),
    ('-x', '-X Forward', 'Export action with -X Forward axis'),
    ('-y', '-Y Forward', 'Export action with -Y Forward axis'),
    ('-z', '-Z Forward', 'Export action with -Z Forward axis'),
)

Items_BoneSetSettings = (
    ('EXCLUDE', 'Exclude', 'Bones in list will be excluded form export'),
    ('INCLUDE', 'Include', 'Only bones in list will be included in export'),
)

# --------------------------------------------------------------------------------------

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
    #mattran = mathutils.Matrix.LocRotScale(None, None, self.scale) @ mattran
    
    return mattran

# --------------------------------------------------------------------------------------

def BoneFindParent(b, check_select, check_deform):
    if b.parent == None:
        return None
    
    while (
        b.parent != None and (
            ((check_select) and (b.parent.select == False)) or
            ((check_deform) and (b.parent.use_deform == False))
        )
        ):
        b = b.parent
    
    return b.parent

# --------------------------------------------------------------------------------------

# Returns dict of {bone: deform_parent}
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
    
    bonenames = [b.name for b in bonelist]
    sorted = list(outparents.items())
    sorted.sort(key=lambda x: bonenames.index(x[1]) if x[1] else 0)
    
    return outparents


'# =========================================================================================================================='
'# OPERATORS'
'# =========================================================================================================================='

class TRK_OT_ExportTRK(bpy.types.Operator, ExportHelper):
    bl_idname = "trk.export_trk"
    bl_label = "Export TRK"
    bl_description = 'Exports action bone curves as tracks for Location, Rotation, Scale'
    bl_options = {'PRESET'}
    
    filename_ext = ".trk"
    filter_glob: bpy.props.StringProperty(default="*"+filename_ext, options={'HIDDEN'}, maxlen=255)
    
    bone_settings_dialog : bpy.props.PointerProperty(
        name='Format', type=TRK_BoneSettings)
    
    bone_settings : bpy.props.StringProperty(name="Bone List", default="")
    
    armature_name: bpy.props.EnumProperty(
        name='Armature Object', 
        description='Armature object to use for pose matrices',
        items=Items_GetArmatureObjects, 
        default=0,
    )
    
    action_name: bpy.props.StringProperty(
        name='Action',
        description='Action to export',
    )
    
    range_type: bpy.props.EnumProperty(
        name='Range Type',
        description="Method to determine range for action",
        items=(
            ('ACTION', 'Action Range', 'Export keyframes using set action range'),
            ('SCENE', 'Scene Range', 'Export keyframes from first marker to last'),
            ('KEYFRAME', 'Clamp To Keyframes', 'Export keyframes from starting keyframe to end keyframe'),
            ('MARKER', 'Clamp To Markers', 'Export keyframes from first marker to last'),
            ('CUSTOM', 'Custom Range', 'Define custom frame range'),
        ),
        default=0,
    )
    
    float_type: bpy.props.EnumProperty(
        name='Float Type', 
        description="Size of floats written to file. Anything not Float32 will take more time to read in GMS2",
        items=(
            ('f', "Float32", "Float32"),
            ('d', "Float64", "Float64"),
            ('e', "Float16", "Float16"),
        ),
        default=0,
    )
    
    marker_frames_only : bpy.props.BoolProperty(
        name='Marker Frames Only',
        description="Export pose marker frames only.\n(Good for pose libraries)",
        default=False,
        )
    
    frame_range: bpy.props.IntVectorProperty(
        name='Frame Range', 
        description='Range of keyframes to export',
        size=2, default=(1, 250),
    )
    
    bake_steps: bpy.props.IntProperty(
        name="Bake Steps",
        description="Sample curves so that every nth frame has a vector.\nSet to 0 for no baking."
        +"\nSet to -1 for all frames (Good for Pose Libraries)\nPositive value needed for constraints",
        default=1, min=-1,
    )
    
    clean_threshold: bpy.props.FloatProperty(
        name="Clean Threshold", 
        description="Threshold to use for cleaning keyframes after baking.\nReduces file size at the cost of quality",
        default=0.001, min=0.0, precision=4, step=1,
    )
    
    scale: bpy.props.FloatProperty(
        name="Action Scale", 
        description="Scales positions of keyframes.",
        default=1.0,
    )
    
    time_step: bpy.props.FloatProperty(
        name="Time Step", 
        description="Speed modifier for track playback.",
        default=1.0,
    )
    
    forward_axis: bpy.props.EnumProperty(
        name="Forward Axis", 
        description="Forward Axis to use when Exporting",
        items = Items_ForwardAxis, 
        default='+y',
    )
    
    up_axis: bpy.props.EnumProperty(
        name="Up Axis", 
        description="Up Axis to use when Exporting",
        items = Items_UpAxis, 
        default='+z',
    )
    
    compression_level: bpy.props.IntProperty(
        name="Compression Level", 
        description="Level of zlib compression to apply to export.\n0 for no compression. -1 for zlib default compression",
        default=-1, min=-1, max=9,
    )
    
    # Track
    track_space: bpy.props.EnumProperty(
        name='Track Space', 
        items=Items_ExportSpace,
        default='LOCAL',
    )
    
    # Matrix
    matrix_space: bpy.props.EnumProperty(
        name='Matrix Space', 
        items=Items_ExportSpaceMatrix,
        default='NONE', 
    )
    
    compress_matrices: bpy.props.BoolProperty(
        name="Compress Matrices", 
        description="Store only the non-zero values of matrices.\nSmaller file size but slightly longer read times",
        default=True,
    )
    
    compress_matrices_threshold: bpy.props.FloatProperty(
        name="Matrix Non-zero Threshold", 
        description="Amount to compare matrix values to when storing non-zeroes",
        default=0.0001,
    )
    
    # Curves
    write_curves: bpy.props.BoolProperty(
        name="Write Curves", 
        description="Export keyed properties to file",
        default=True,
    )
    
    write_markers: bpy.props.BoolProperty(
        name="Write Marker Names", 
        description="Write names of markers before track data",
        default=True,
    )
    
    lastsimplify = -1
    lastsimplifylevels = -1
    
    @classmethod
    def poll(self, context):
        return bpy.data.actions
    
    def invoke(self, context, event):
        sc = context.scene
        self.lastsimplify = sc.render.use_simplify
        self.lastsimplifylevels = sc.render.simplify_subdivision
        sc.render.use_simplify = True
        sc.render.simplify_subdivision = 0
        
        # Clear temporary data
        [bpy.data.objects.remove(x) for x in bpy.data.objects if '__temp' in x.name]
        [bpy.data.armatures.remove(x) for x in bpy.data.armatures if '__temp' in x.name]
        [bpy.data.actions.remove(x) for x in bpy.data.actions if '__temp' in x.name]
        
        # Pre-set armature and action
        objs = [x for x in context.selected_objects if x.type == 'ARMATURE']
        objs += [x.find_armature() for x in context.selected_objects if x and x.find_armature()]
        if objs:
            for o in objs:
                if o.animation_data and o.animation_data.action:
                    self.armature_name = o.name
                    self.action_name = o.animation_data.action.name
                    break
                elif o.pose_library:
                    self.armature_name = o.name
                    self.action_name = o.pose_library.name
            
        context.window_manager.fileselect_add(self)
        
        return {'RUNNING_MODAL'}
    
    def cancel(self, context):
        context.scene.render.use_simplify = self.lastsimplify
        context.scene.render.simplify_subdivision = self.lastsimplifylevels
    
    def draw(self, context):
        layout = self.layout
        
        c = layout.column()
        c.prop(self, 'armature_name')
        c.prop_search(self, 'action_name', bpy.data, 'actions')
        
        # Action Info
        b = c.box().column(align=1)
        r = b.row()
        r.alignment = 'CENTER'
        r.label(text="== Action ==")
        
        r = b.row()
        r.label(text="Range Type:")
        r.prop(self, 'range_type', text="")
        if self.range_type == 'CUSTOM':
            r = b.row()
            r.prop(self, 'frame_range')
        elif self.range_type == 'SCENE':
            r = b.row()
            r.label(text='Scene Frame Range')
            r = r.row(align=1)
            r.prop(context.scene, 'frame_start', text='')
            r.prop(context.scene, 'frame_end', text='')
        
        cc = b.column(align=1)
        
        r = cc.row(align=1)
        r.prop(self, 'bake_steps')
        r.prop(self, 'clean_threshold')
        r = cc.row(align=1)
        r.prop(self, 'scale', text='Scale')
        r.prop(self, 'time_step')
        
        # Export Data
        b = c.box().column(align=1)
        
        r = b.row()
        r.alignment = 'CENTER'
        r.label(text="== Data ==")
        
        cc = b.column(align=1)
        r = cc.row(align=1)
        r.label(text="Coordinates:")
        r.prop(self, 'up_axis', text='')
        r.prop(self, 'forward_axis', text='')
        
        r = cc.row()
        r.label(text='Track Space:')
        r.prop(self, 'track_space', text='')
        
        r = cc.row()
        r.label(text='Matrix Space:')
        r.prop(self, 'matrix_space', text='')
        
        cc = b.column(align=1)
        r = cc.row()
        r.active = self.matrix_space != 'NONE'
        r.prop(self, 'compress_matrices')
        cc.prop(self, 'write_markers')
        cc.prop(self, 'write_curves')
        cc.prop(self, 'marker_frames_only')
        cc.prop(self, 'compression_level')
        
        # Bone List
        b = layout.box()
        b = b.column_flow(align=1)
        
        r = b.row()
        r.alignment = 'CENTER'
        r.label(text="== Bones ==")
        
        r = b.row()
        activelist = context.scene.trk.bone_settings.FindItem(self.bone_settings, self.bone_settings_dialog)
        
        r = b.row(align=1)
        r.prop_search(self, 'bone_settings', context.scene.trk.bone_settings, 'items', text="Bone List", icon='ZOOM_SELECTED')
        
        activelist.DrawPanel(context, b, 3)
    
    def execute(self, context):
        path = os.path.realpath(bpy.path.abspath(self.filepath))
        
        if not os.path.exists(os.path.dirname(path)):
            self.report({'WARNING'}, 'Invalid path specified: "%s"' % path)
            return {'FINISHED'}
        
        if self.lastsimplify == -1:
            self.lastsimplify = context.scene.render.use_simplify
            self.lastsimplifylevels = context.scene.render.simplify_subdivision
            context.scene.render.use_simplify = True
            context.scene.render.simplify_subdivision = 0
        
        # Validation
        reset = False
        
        sourceobj = [x for x in bpy.data.objects if x.name == self.armature_name]
        if not sourceobj:
            self.report({'WARNING'}, 'No object with name "{}" found'.format(self.armature_name))
        
        sourceobj = sourceobj[0]
        if sourceobj.type != 'ARMATURE':
            self.report({'WARNING'}, '"{}" is not armature'.format(self.armature_name))
        
        sourceaction = [x for x in bpy.data.actions if x.name == self.action_name]
        if not sourceaction:
            self.report({'WARNING'}, 'No action with name "{}" found'.format(self.action_name))
        
        if reset:
            rd.use_simplify = self.lastsimplify
            rd.simplify_subdivision = self.lastsimplifylevels
            return {'FINISHED'}
        sourceaction = sourceaction[0]
        
        # Clear temporary data
        [bpy.data.objects.remove(x) for x in bpy.data.objects if '__temp' in x.name]
        [bpy.data.armatures.remove(x) for x in bpy.data.armatures if '__temp' in x.name]
        [bpy.data.actions.remove(x) for x in bpy.data.actions if '__temp' in x.name]
        
        # Gen TRK Data
        bone_settings = context.scene.trk.bone_settings.FindItem(self.bone_settings, self.bone_settings_dialog)
        
        context.scene.trk.ExportTRK(
            context, 
            sourceobj, 
            sourceaction, 
            path,
            
            float_type=self.float_type,
            compression_level=self.compression_level,
            
            range_type=self.range_type,
            frame_range=self.frame_range,
            bake_steps=self.bake_steps,
            clean_threshold=self.clean_threshold,
            scale=self.scale,
            time_step=self.time_step,
            marker_frames_only=self.marker_frames_only,
            
            matrix=GetCorrectiveMatrix(self, context),
            track_space=self.track_space,
            matrix_space=self.matrix_space,
            write_curves=self.write_curves,
            write_markers=self.write_markers,
            
            compress_matrices=self.compress_matrices,
            compress_matrices_threshold=self.compress_matrices_threshold,
            
            include_bones=[x.name for x in bone_settings.items] if bone_settings.type == 'INCLUDE' else [],
            exclude_bones=[x.name for x in bone_settings.items] if bone_settings.type == 'EXCLUDE' else [],
            deform_only=bone_settings.deform_only,
            selected_bones_only=bone_settings.selected_only,
        )
        
        # Free Temporary Data
        [bpy.data.objects.remove(x) for x in bpy.data.objects if '__temp' in x.name]
        [bpy.data.armatures.remove(x) for x in bpy.data.armatures if '__temp' in x.name]
        [bpy.data.actions.remove(x) for x in bpy.data.actions if '__temp' in x.name]
        
        context.scene.render.use_simplify = self.lastsimplify
        context.scene.render.simplify_subdivision = self.lastsimplifylevels
        
        print('> Complete')
        
        return {'FINISHED'}
classlist.append(TRK_OT_ExportTRK)

'# =========================================================================================================================='
'# PANELS'
'# =========================================================================================================================='

class TRK_PT_TRKExport(bpy.types.Panel):
    bl_label = 'TRK Export'
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = 'scene'
    #bl_parent_id = 'VBM_PT_Properties'
    
    def draw(self, context):
        layout = self.layout
        
        r = layout.row()
        split = r.split(factor=0.9)
        split.label(text='Animation:')
        r.operator("trk.export_trk", text='Export TRK', icon='ACTION')
classlist.append(TRK_PT_TRKExport)

# ---------------------------------------------------------------------------------

class TRK_PT_BoneSettings(bpy.types.Panel):
    bl_label = 'TRK Bone Settings'
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = 'scene'
    bl_parent_id = 'TRK_PT_TRKExport'
    
    def draw(self, context):
        layout = self.layout
        
        active = context.scene.trk.bone_settings
        active.DrawPanel(context, layout, 5)
classlist.append(TRK_PT_BoneSettings)

# ---------------------------------------------------------------------------------

class TRK_PT_BoneSettings_Active(bpy.types.Panel):
    bl_label = 'TRK Active Bone Settings'
    bl_space_type = 'PROPERTIES'
    bl_region_type = 'WINDOW'
    bl_context = 'scene'
    bl_parent_id = 'TRK_PT_BoneSettings'
    
    def draw(self, context):
        layout = self.layout
        
        itemlist = context.scene.trk.bone_settings
        active = itemlist.GetActive()
        
        if active:
            c = active.DrawPanel(context, layout)
            
            c.separator()
            c.operator('vbm.trk_bonesettings_add_selected_bones', text="", icon='RESTRICT_SELECT_OFF')
        else:
            layout.prop(itemlist, 'op_add_item', text="Add Bone List", toggle=True)
classlist.append(TRK_PT_BoneSettings_Active)

'# =========================================================================================================================='
'# MASTER'
'# =========================================================================================================================='

def ExportTRK(
    self,
    context, 
    object, 
    action, 
    filepath,
    
    float_type='f',
    compression_level=-1,
    
    range_type='ACTION',
    frame_range=(1,250),
    bake_steps=0,
    clean_threshold=0.0001,
    scale=1,
    time_step=1,
    marker_frames_only=False,
    
    matrix=mathutils.Matrix.Identity(4),
    track_space='LOCAL',
    matrix_space='NONE',
    write_curves=True,
    write_markers=True,
    
    compress_matrices=True,
    compress_matrices_threshold=0.0001,
    
    bone_settings=None,
    include_bones=[],
    exclude_bones=[],
    deform_only=True,
    selected_bones_only=False,
):
    
    # Settings --------------------------------------------------------------------------
    compress_matrices_threshold *= compress_matrices_threshold
    sourceobj = object
    
    if bone_settings:
        if bone_settings.type == 'INTERNAL':
            include_bones += [x for x in bone_settings.items]
        elif bone_settings.type == 'EXTERNAL':
            exclude_bones += [x for x in bone_settings.items]
        deform_only = bone_settings.deform_only
        selected_bones_only_only = bone_settings.selected_only
    
    vl = context.view_layer
    sc = context.scene
    rd = sc.render
    
    # Determine action range
    if range_type == 'CUSTOM':
        actionrange = frame_range
    elif range_type == 'KEYFRAME':
        positions = [int(k.co[0]) for fc in action.fcurves for k in fc.keyframe_points]
        actionrange = (min(positions), max(positions))
    elif range_type == 'MARKER' and action.pose_markers:
        positions = [m.frame for m in action.pose_markers]
        actionrange = (min(positions), max(positions))
    elif range_type == 'ACTION':
        actionrange = (int(action.frame_start), int(action.frame_end))
    else:
        actionrange = (sc.frame_start, sc.frame_end)
    
    if range_type == 'MARKER' and not action.pose_markers:
        print('> WARNING: No markers found for action "%s". Defaulting to scene range.' % action.name)
    
    if marker_frames_only:
        actionrange = (
            max(actionrange[0], min([m.frame for m in action.pose_markers])),
            min(actionrange[1], max([m.frame for m in action.pose_markers]))
            )
    
    # Store last state
    lastpose = {pb: pb.matrix_basis for pb in sourceobj.pose.bones}
    lastaction = sourceobj.animation_data.action if sourceobj.animation_data else None
    lastsceneframe = sc.frame_current
    
    # Create working data --------------------------------------------------------------------------
    print('> Beginning export for "{}"...'.format(action.name));
    
    workingarmature = bpy.data.armatures.new(name=sourceobj.data.name + '__temp')
    workingobj = bpy.data.objects.new(sourceobj.name + '__temp', workingarmature)
    sc.collection.objects.link(workingobj)
    
    sourceobj.select_set(False)
    workingobj.select_set(True)
    vl.objects.active = workingobj
    bpy.ops.object.mode_set(mode='OBJECT')
    
    workingaction = action
    if not sourceobj.animation_data:
        sourceobj.animation_data_create()
    
    if not workingobj.animation_data:
        workingobj.animation_data_create()
    
    sourceobj.animation_data.action = workingaction
    workingobj.animation_data.action = workingaction
    sc.frame_set(sc.frame_current)
    vl.update()
    
    sourceobj.data.pose_position = 'POSE'
    workingobj.data.pose_position = 'POSE'
    
    # Create armature that copy source's transforms -------------------------------------------------
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Get bone transforms
    rigbonemeta = {
        b.name: (
            b.head_local.copy(), 
            b.tail_local.copy(), 
            b.AxisRollFromMatrix(b.matrix_local.to_3x3())[1],
            b.use_connect
            )
            for b in sourceobj.data.bones if (not deform_only or b.use_deform)
    }
    
    if deform_only:
        boneparents = {b: p if p else None for b,p in ParseDeformParents(sourceobj).items()}
    else:
        boneparents = {b.name: b.parent.name if b.parent else None for b in sourceobj.data.bones}
    
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
        b.head, b.tail, b.roll, b.use_connect = meta
        
    for b in editbones:
        if boneparents[b.name]:
            b.parent = editbones[boneparents[b.name]]
    
    # Make constraints to copy transforms
    bpy.ops.object.mode_set(mode='POSE')
    
    for b in workingobj.pose.bones:
        [b.constraints.remove(c) for c in list(b.constraints)[::-1]]
        c = b.constraints.new(type='COPY_TRANSFORMS')
        c.target = sourceobj
        c.subtarget = b.name
    
    bpy.ops.object.mode_set(mode='OBJECT')
    
    # Find Target Bones ---------------------------------------------------------------------
    bones = {b.name: b for b in workingobj.data.bones}
    
    boneparents = {b: b.parent for b in bones.values()}
    pbonesmap = { b.name: workingobj.pose.bones[b.name] for b in bones.values() }
    pbones = pbonesmap.values()
    pboneparents = {pbonesmap[b.name]: pbonesmap[boneparents[b].name] if boneparents[b] else None for b in bones.values()}
    pbonestarget = [x for x in pbonesmap.values()]
    
    if exclude_bones:
        pbonestarget = [pb for pb in pbonestarget if pb.name not in exclude_bones]
    elif include_bones:
        pbonestarget = [pb for pb in pbonestarget if pb.name in include_bones]
    
    if selected_bones_only:
        pbonestarget = [ pb for pb in pbonestarget if sourceobj.data.bones[pb.name].select ]
    
    pbonesnames = [x.name for x in pbonestarget]
    
    # Action Details ----------------------------------------------------------------------------
    outputframes = list(range(0, (actionrange[1]+1)-actionrange[0]) )
    
    # Only Markers' Frames
    if marker_frames_only:
        outputframes = tuple([
            m.frame for m in workingaction.pose_markers 
            if (m.frame >= actionrange[0] and m.frame <= actionrange[1])
            ])
    
    if len(outputframes) == 0:
        outputframes = [actionrange[0]]
    
    duration = len(outputframes) * scale
    frames2position = 1.0/max(1, (actionrange[1]+1)-actionrange[0] )
    framecount = len(outputframes)
    
    # Data =========================================================================================
    
    # Matrices ----------------------------------------------------------------------
    outtrk_matrices = Pack('B', SpaceID[matrix_space])
    
    if matrix_space != 'NONE':
        print('> Compositing Matrix Data...');
        
        # Use convert_space() --------------------------------------------------------------------
        if matrix_space != 'EVALUATED':
            evalbones = [x for x in workingobj.pose.bones]
            pbonesenumerated = enumerate(pbonestarget)
            pbonesrange = range(0, len(pbonestarget))
            outtrkchunk = b''
            
            for f in outputframes:
                sc.frame_set(f)
                
                if compress_matrices:
                    outtrkchunk += b''.join(
                        Pack('B', (len([x for vec in m for x in vec if x*x > compress_matrices_threshold]) << 4) | int(c*4+r) )+Pack(float_type, x)
                        
                        for i, pb in enumerate(pbones) if pb in pbonestarget
                        for m in tuple(workingobj.convert_space(
                            pose_bone=evalbones[i], matrix=matrix @ evalbones[i].matrix, from_space='WORLD', to_space=matrix_space
                            ))
                        for r, vec in enumerate(m)
                        for c, x in enumerate(vec) if x*x > compress_matrices_threshold
                        )
                else:
                    outtrkchunk += b''.join(
                        Pack(float_type, x)
                        
                        for i in pbonesrange
                        for vec in workingobj.convert_space(
                            pose_bone=evalbones[i], matrix=matrix @ evalbones[i].matrix, from_space='WORLD', to_space=matrix_space
                            ).transposed()
                        for x in vec
                        )
            outtrk_matrices += outtrkchunk
        
        # Evaluate final transforms --------------------------------------------------------------------
        else:
            bmatrix = {b: (matrix @ b.matrix_local.copy()) for b in bones.values()}
            bmatlocal = {
                pbonesmap[b.name]: (bmatrix[boneparents[b]].inverted() @ bmatrix[b] if boneparents[b] else bmatrix[b])
                for b in bones.values() if b.name in pbonesmap.keys()
            }
            bmatinverse = {
                pbonesmap[b.name]: bmatrix[b].inverted()
                for b in bones.values() if b.name in pbonesmap.keys()
            }
            
            for f in outputframes:
                outtrkchunk = b''
                
                sc.frame_set(f)
                dg = context.evaluated_depsgraph_get()
                evaluatedobj = workingobj.evaluated_get(dg)
                evalbones = [x for x in evaluatedobj.pose.bones]
                
                localtransforms = {
                    pb: bmatlocal[pb] @ workingobj.convert_space(
                        pose_bone=evalbones[i], matrix=evalbones[i].matrix, from_space='WORLD', to_space='LOCAL'
                        )
                    for i, pb in enumerate(pbones)
                }
                
                bonetransforms = {}
                for pb in pbones:
                    bonetransforms[pb] = (
                        bonetransforms[pboneparents[pb]]@localtransforms[pb] 
                        if pboneparents[pb] else localtransforms[pb]
                        )
                
                finaltransforms = {
                    pb: bonetransforms[pb] @ bmatinverse[pb]
                    for pb in pbones
                }
                
                if compress_matrices:
                    outtrk_matrices += b''.join(
                        Pack('B', (len([x for vec in m for x in vec if x*x > compress_matrices_threshold]) << 4) | int(c*4+r) )+Pack(float_type, x)
                        
                        for pb in pbonestarget
                        for m in [finaltransforms[pb]]
                        for r,vec in enumerate(m)
                        for c,x in enumerate(vec) if x*x > compress_matrices_threshold
                        )
                else:
                    outtrk_matrices += b''.join(
                        Pack(float_type, x)
                        
                        for pb in pbonestarget
                        for v in (finaltransforms[pb]).transposed()
                        for x in v
                        )
    
    # Tracks -------------------------------------------------------------------
    outtrk_tracks = Pack('B', SpaceID[track_space])
    
    if track_space != 'NONE':
        print('> Compositing Track Data...');
        
        # Get final transforms of all pose bones for each frame
        bonefinaltransforms = tuple([
            tuple(
                tuple(
                    workingobj.convert_space(
                        pose_bone=update[-1].pose.bones[pb.name], 
                        matrix=update[-1].pose.bones[pb.name].matrix, 
                        from_space='WORLD', 
                        to_space=track_space
                    ).decompose()
                )
                for i,pb in enumerate(pbonestarget)
            )
            for frame in outputframes
            for update in [(sc.frame_set(frame), vl.update(), workingobj.evaluated_get( context.evaluated_depsgraph_get() ))]
        ])
        
        transformthresh = [
            clean_threshold,
            clean_threshold * clean_threshold,
            clean_threshold,
        ]
        
        # Write tracks for each bone
        for pbindex, pb in enumerate(pbonestarget):
            outtrkchunk = b''
            
            # Location ------------------------------------------------------------------------
            frames = outputframes[:]
            vectors = [
                bonefinaltransforms[f][pbindex][0]
                for f in frames
                ]
            
            dist = 0
            v1 = vectors[0]
            poplist = []
            thresh = transformthresh[0]
            
            # Parse vectors for close values
            for i, v2 in list(enumerate(vectors))[1:-1]:
                dist += (v2-v1).length
                if dist <= thresh:
                    poplist.append(i)
                else:
                    if len(poplist) > 2 and (vectors[poplist[-1]]-v1).length == 0.0:
                        poplist = poplist[:-1]
                    v1 = v2
                    dist = 0
            
            # Remove frames with close values
            for i in poplist[::-1]:
                del frames[i]
                del vectors[i]
            
            outtrkchunk += Pack('I', len(frames)) # Num Frames
            outtrkchunk += b''.join( [Pack(float_type, f/duration) for f in frames] ) # Frame Positions 
            outtrkchunk += b''.join( [Pack(float_type, f) for v in vectors for f in v] ) # Vectors 
            
            # Rotation ------------------------------------------------------------------------
            frames = outputframes[:]
            vectors = [
                bonefinaltransforms[f][pbindex][1]
                for f in frames
                ]
            
            dist = 0
            v1 = vectors[0]
            poplist = []
            thresh = transformthresh[1]
            
            # Parse vectors for close values
            for i, v2 in list(enumerate(vectors))[1:-1]:
                dist += 1.0-(1.0+v2.dot(v1))*0.5
                if dist <= thresh:
                    poplist.append(i)
                else:
                    if len(poplist) > 2 and (vectors[poplist[-1]].dot(v1)) == 0.0:
                        poplist = poplist[:-1]
                    v1 = v2
                    dist = 0
            
            # Remove frames with close values
            for i in poplist[::-1]:
                del frames[i]
                del vectors[i]
            
            outtrkchunk += Pack('I', len(frames)) # Num Frames
            outtrkchunk += b''.join( [Pack(float_type, f/duration) for f in frames] ) # Frame Positions 
            outtrkchunk += b''.join( [Pack(float_type, f) for v in vectors for f in v] ) # Vectors 
            
            # Scale ------------------------------------------------------------------------
            frames = outputframes[:]
            vectors = [
                bonefinaltransforms[f][pbindex][2]
                for f in frames
                ]
            
            dist = 0
            v1 = vectors[0]
            poplist = []
            thresh = transformthresh[2]
            
            # Parse vectors for close values
            for i, v2 in list(enumerate(vectors))[1:-1]:
                dist += (v2-v1).length
                if dist <= thresh:
                    poplist.append(i)
                else:
                    if len(poplist) > 2 and (vectors[poplist[-1]]-v1).length == 0.0:
                        poplist = poplist[:-1]
                    v1 = v2
                    dist = 0
            
            # Remove frames with close values
            for i in poplist[::-1]:
                del frames[i]
                del vectors[i]
            
            outtrkchunk += Pack('I', len(frames)) # Num Frames
            outtrkchunk += b''.join( [Pack(float_type, f/duration) for f in frames] ) # Frame Positions 
            outtrkchunk += b''.join( [Pack(float_type, f) for v in vectors for f in v] ) # Vectors 
            
            outtrk_tracks += outtrkchunk
    
    # Curves -----------------------------------------------------------------------
    outtrk_curves = b''
    if write_curves:
        print('> Compositing Curve Data...');
        
        # Prepare property curves
        curvebundles = {}
        for fc in workingaction.fcurves:
            if 'pose.bones' not in fc.data_path:
                dpath = fc.data_path
                name = dpath[dpath.rfind('"', 0, dpath.rfind('"')-1) +1 :dpath.rfind('"')] if '"' in dpath else dpath
                curvebundles[name] = curvebundles.get(name, [])
                curvebundles[name].append(fc)
        
        # Curve Names
        outtrk_curves += b''.join([Pack('B', len(x)) + Pack('B'*len(x), *[ord(c) for c in x]) for x in curvebundles.keys()]) # Names
        
        for name, bundle in curvebundles.items():
            outtrk_curves += Pack('B', len(bundle)) # Frequency
            
            for fcindex, fc in enumerate(bundle):
                kframes = tuple(fc.keyframe_points)
                outtrk_curves += Pack('I', fc.array_index) # Array Index
                outtrk_curves += Pack('I', len(kframes))   # Number of Frames
                outtrk_curves += b''.join([Pack(float_type, (k.co[0]-actionrange[0])*scale*frames2position) for k in kframes]) # Positions
                outtrk_curves += b''.join([Pack(float_type, k.co[1]) for k in kframes]) # Values
        
    # Markers ----------------------------------------------------------------
    outtrk_markers = b''
    if write_markers:
        print('> Compositing Marker Data...');
        
        if marker_frames_only:
            markers = [(x.name, i/max(1, duration)) for i,x in enumerate(workingaction.pose_markers)]
        else:
            markers = [(x.name, (x.frame-actionrange[0])*scale*frames2position) for x in workingaction.pose_markers]
        
        outtrk_markers += Pack('I', len(markers))
        outtrk_markers += b''.join([Pack('B', len(x[0])) + Pack('B'*len(x[0]), *[ord(c) for c in x[0]]) for x in markers]) # Names
        outtrk_markers += b''.join([Pack(float_type, x[1]) for x in markers]) # Frames
    else:
        outtrk_markers += Pack('I', 0)
    
    # Output =========================================================================================
    print('> Writing to file...');
    
    outtrk = b''
    
    # Header
    outtrk += b'TRK' + Pack('B', TRKVERSION)    # Signature
    
    flags = 0
    if compress_matrices:
        flags |= FL_TRK_SPARSE
    if float_type == 'e':
        flags |= FL_TRK_FLOAT16
    elif float_type == 'd':
        flags |= FL_TRK_FLOAT64
    
    outtrk += Pack('B', flags)     # Flags
    
    outtrk += Pack('f', rd.fps)     # fps
    outtrk += Pack('I', len(outputframes) ) # Frame Count
    outtrk += Pack('I', len(pbonestarget) ) # Num tracks
    outtrk += Pack('I', len(curvebundles) ) # Num curve bundles
    outtrk += Pack('f', duration*scale ) # Duration
    outtrk += Pack('f', time_step/(max(1, duration)*scale) ) # Position Step
    
    outtrk += b''.join([Pack('B', len(x)) + Pack('B'*len(x), *[ord(c) for c in x]) for x in pbonesnames]) # Bone Names
    
    outtrk += outtrk_matrices
    outtrk += outtrk_tracks
    outtrk += outtrk_curves
    outtrk += outtrk_markers
    
    # Output to File
    oldlen = len(outtrk)
    
    if compression_level != 0:
        outtrk = zlib.compress(outtrk, level=compression_level)
    
    file = open(filepath, 'wb')
    file.write(outtrk)
    file.close()
    
    report = (
        'Data written to "%s". (%.2fKB -> %.2fKB) %.2f%%' %
        (filepath, oldlen / 1000, len(outtrk) / 1000, 100 * len(outtrk) / oldlen)
        )
    print(report)
    
    # Restore State
    if lastaction:
        sourceobj.animation_data.action = lastaction
    
    sc.frame_set(lastsceneframe)
    
    for pb, mat in lastpose.items():
        pb.matrix_basis = mat
    
    return outtrk;

# ---------------------------------------------------------------------------------

class TRK_Master(bpy.types.PropertyGroup):
    bone_settings : bpy.props.PointerProperty(type=TRK_BoneSettingsList)
    
    bonenames : bpy.props.CollectionProperty(type=TRK_BoneSettings_String)
    
    op_refresh_strings : bpy.props.BoolProperty(
        name="Reload Bone Names",
        description="Parse all bone names in file. Run to update string fields for bone settings",
        default=False,
        update=lambda s,c: s.Update(c)
        )
    
    def Update(self, context):
        if self.op_refresh_strings:
            self.op_refresh_strings = False
            self.RefreshStringLists()
    
    def RefreshStringLists(self):
        self.bonenames.clear()
        
        namelist = [(i, b.name) for obj in bpy.data.objects if obj.type == 'ARMATURE' for i,b in enumerate(obj.data.bones)]
        namelist.sort(key=lambda x: x[0])
        namelist.sort(key=lambda x: x[1][:3] != 'DEF')
        namelist.sort(key=lambda x: x[1][:3] == 'ORG')
        namelist.sort(key=lambda x: x[1][:3] == 'MCH')
        namelist.sort(key=lambda x: x[1][:3] == 'VIS')
        
        for i,x in namelist:
            item = self.bonenames.add()
            item.name = x
    
    ExportTRK = ExportTRK
classlist.append(TRK_Master)

'# =========================================================================================================================='
'# REGISTER'
'# =========================================================================================================================='

def register():
    for c in classlist:
        bpy.utils.register_class(c)
    
    bpy.types.Scene.trk = bpy.props.PointerProperty(name="TRK Class", type=TRK_Master)

def unregister():
    for c in classlist[::-1]:
        bpy.utils.unregister_class(c)
    #del bpy.types.Scene.vbm_formats
    
