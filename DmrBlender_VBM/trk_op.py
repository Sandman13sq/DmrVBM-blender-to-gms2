import bpy
import os
import struct
import zlib
import sys
import mathutils

from bpy_extras.io_utils import ExportHelper
from struct import pack as Pack

try:
    from .trk_func import *
except:
    from trk_func import *


# ==========================================================================================================================
# FUNCTIONS
# ==========================================================================================================================

def ChooseAction(self, context):
    action = bpy.data.actions[self.actionname]

# ==========================================================================================================================
# OPERATORS
# ==========================================================================================================================

classlist = []

class ExportActionSuper(bpy.types.Operator, ExportHelper):
    armature_name: bpy.props.EnumProperty(
        name='Armature Object', items=Items_GetArmatureObjects, default=0,
        description='Armature object to use for pose matrices'
    )
    
    action_name: bpy.props.EnumProperty(
        name='Action', items=Items_GetActions, default=0,
        description='Action to export',
    )
    
    range_type: bpy.props.EnumProperty(
        name='Range Type', default=0, items=(
            ('ACTION', 'Action Range', 'Export keyframes using set action range'),
            ('SCENE', 'Scene Range', 'Export keyframes from first marker to last'),
            ('KEYFRAME', 'Clamp To Keyframes', 'Export keyframes from starting keyframe to end keyframe'),
            ('MARKER', 'Clamp To Markers', 'Export keyframes from first marker to last'),
            ('CUSTOM', 'Custom Range', 'Define custom frame range'),
        )
    )
    
    float_type: bpy.props.EnumProperty(
        name='Range Type', default=0, items=(
            ('f', "Float32", "Float32"),
            ('d', "Float64", "Float64"),
            ('e', "Float16", "Float16"),
        )
    )
    
    marker_frames_only : bpy.props.BoolProperty(
        name='Marker Frames Only', default=False,
        description="Export pose marker frames only.\n(Good for pose libraries)"
        )
    
    frame_range: bpy.props.IntVectorProperty(
        name='Frame Range', size=2, default=(1, 250),
        description='Range of keyframes to export',
    )
    
    bake_steps: bpy.props.IntProperty(
        name="Bake Steps", default=1, min=-1,
        description="Sample curves so that every nth frame has a vector.\nSet to 0 for no baking."
        +"\nSet to -1 for all frames (Good for Pose Libraries)\nPositive value needed for constraints",
    )
    
    clean_threshold: bpy.props.FloatProperty(
        name="Clean Threshold", default=0.0002, min=0.0, precision=4, step=1,
        description="Threshold to use for cleaning keyframes after baking.\nReduces file size at the cost of quality",
    )
    
    scale: bpy.props.FloatProperty(
        name="Action Scale", default=1.0,
        description="Scales positions of keyframes.",
    )
    
    time_step: bpy.props.FloatProperty(
        name="Time Step", default=1.0,
        description="Speed modifier for track playback.",
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
    
    export_matrices: bpy.props.BoolProperty(
        name="Export Matrices", default=False,
        description="Export matrices to file",
    )
    
    compress_matrices: bpy.props.BoolProperty(
        name="Compress Matrices", default=True,
        description="Store only the non-zero values of matrices.\nSmaller file size but slightly longer read times",
    )
    
    compress_matrices_threshold: bpy.props.FloatProperty(
        name="Matrix Non-zero Threshold", default=0.0001,
        description="Amount to compare matrix values to when storing non-zeroes",
    )
    
    matrix_space: bpy.props.EnumProperty(
        name='Matrix Space', default='EVALUATED', items=Items_ExportSpaceMatrix
    )
    
    export_tracks: bpy.props.BoolProperty(
        name="Export Tracks", default=True,
        description="Export tracks to file",
    )
    
    track_space: bpy.props.EnumProperty(
        name='Track Space', default='LOCAL', items=Items_ExportSpace
    )
    
    write_marker_names: bpy.props.BoolProperty(
        name="Write Marker Names", default=True,
        description="Write names of markers before track data",
    )
    
    deform_only: bpy.props.BoolProperty(
        name="Deform Bones Only", default=True,
        description='Only export bones with the "Deform" box checked',
    )
    
    selected_bones_only: bpy.props.BoolProperty(
        name="Selected Bones Only", default=False,
        description='Only write data for bones that are selected',
    )
    
    compression_level: bpy.props.IntProperty(
        name="Compression Level", default=-1, min=-1, max=9,
        description="Level of zlib compression to apply to export.\n0 for no compression. -1 for zlib default compression",
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

# =============================================================================

class VBM_OT_ExportTRK(ExportActionSuper, ExportHelper):
    bl_idname = "vbm.export_trk"
    bl_label = "Export Action Tracks"
    bl_description = 'Exports action curves as tracks for Location, Rotation, Scale'
    bl_options = {'PRESET'}
    
    filename_ext = ".trk"
    filter_glob: bpy.props.StringProperty(default="*"+filename_ext, options={'HIDDEN'}, maxlen=255)
    
    def draw(self, context):
        layout = self.layout
        
        c = layout.column()
        c.prop(self, 'armature_name')
        c.prop(self, 'action_name')
        
        b = c.box()
        b.prop(self, 'range_type')
        r = b.row()
        if self.range_type == 'CUSTOM':
            r.prop(self, 'frame_range')
        elif self.range_type == 'SCENE':
            r.label(text='Scene Frame Range')
            r = r.row(align=1)
            r.prop(context.scene, 'frame_start', text='')
            r.prop(context.scene, 'frame_end', text='')
        
        cc = b.column()
        cc.prop(self, 'marker_frames_only')
        cc.prop(self, 'bake_steps')
        cc.prop(self, 'clean_threshold')
        r = cc.row(align=1)
        r.prop(self, 'scale', text='Scale')
        r.prop(self, 'time_step')
        
        b = c.box().column(align=0)
        r = b.row()
        r.label(text='Track Space:')
        r.prop(self, 'track_space', text='')
        
        r = b.row()
        r.label(text='Matrix Space:')
        r.prop(self, 'matrix_space', text='')
        r = b.row()
        r.active = self.matrix_space != 'NONE'
        r.label(text="")
        r.prop(self, 'compress_matrices')
        
        b.label(text="Coordinates:")
        r = b.row(align=1)
        r.prop(self, 'up_axis', text='')
        r.prop(self, 'forward_axis', text='')
        
        c.separator();
        c.prop(self, 'write_marker_names')
        c.prop(self, 'deform_only')
        c.prop(self, 'selected_bones_only')
        c.prop(self, 'compression_level')
        
    def execute(self, context):
        path = os.path.realpath(bpy.path.abspath(self.filepath))
        
        if not os.path.exists(os.path.dirname(path)):
            self.report({'WARNING'}, 'Invalid path specified: "%s"' % path)
            return {'FINISHED'}
        
        settings = {
            'float_type': self.float_type,
            'matrix_space': self.matrix_space,
            'track_space': self.track_space,
            'deform_only': self.deform_only,
            'write_marker_names': self.write_marker_names,
            'bake_steps': self.bake_steps,
            'time_step': self.time_step,
            'scale': self.scale,
            'range_type': self.range_type,   
            'mattran': GetCorrectiveMatrix(self, context),
            'selected_bones_only': self.selected_bones_only,
            'frame_range': self.frame_range,
            'marker_frames_only': self.marker_frames_only,
            'compress_matrices': self.compress_matrices,
            'compress_matrices_threshold': self.compress_matrices_threshold,
            'clean_threshold': self.clean_threshold,
        }
        
        if self.lastsimplify == -1:
            self.lastsimplify = context.scene.render.use_simplify
            self.lastsimplifylevels = context.scene.render.simplify_subdivision
            context.scene.render.use_simplify = True
            context.scene.render.simplify_subdivision = 0
        
        # Validation
        sourceobj = [x for x in bpy.data.objects if x.name == self.armature_name]
        if not sourceobj:
            self.info({'WARNING'}, 'No object with name "{}" found'.format(self.armature_name))
            rd.use_simplify = self.lastsimplify
            rd.simplify_subdivision = self.lastsimplifylevels
            return {'FINISHED'}
        sourceobj = sourceobj[0]
        if sourceobj.type != 'ARMATURE':
            self.info({'WARNING'}, '"{}" is not armature'.format(self.armature_name))
            rd.use_simplify = self.lastsimplify
            rd.simplify_subdivision = self.lastsimplifylevels
            return {'FINISHED'}
        
        sourceaction = [x for x in bpy.data.actions if x.name == self.action_name]
        if not sourceaction:
            self.info({'WARNING'}, 'No action with name "{}" found'.format(self.action_name))
            rd.use_simplify = self.lastsimplify
            rd.simplify_subdivision = self.lastsimplifylevels
            return {'FINISHED'}
        sourceaction = sourceaction[0]
        
        # Clear temporary data
        [bpy.data.objects.remove(x) for x in bpy.data.objects if '__temp' in x.name]
        [bpy.data.armatures.remove(x) for x in bpy.data.armatures if '__temp' in x.name]
        [bpy.data.actions.remove(x) for x in bpy.data.actions if '__temp' in x.name]
        
        # Gen TRK Data
        out = GetTRKData(context, sourceobj, sourceaction, settings)
        
        context.scene['LastTRKExport'] = {
            'filepath': self.filepath,
            'armature_name': self.armature_name,
            'action_name': self.action_name,
            'range_type': self.range_type,
            'float_type': self.float_type,
            'marker_frames_only': self.marker_frames_only,
            'frame_range': self.frame_range,
            'bake_steps': self.bake_steps,
            'clean_threshold': self.clean_threshold,
            'scale': self.scale,
            'time_step': self.time_step,
            'forward_axis': self.forward_axis,
            'up_axis': self.up_axis,
            'export_matrices': self.export_matrices,
            'compress_matrices': self.compress_matrices,
            'compress_matrices_threshold': self.compress_matrices_threshold,
            'matrix_space': self.matrix_space,
            'export_tracks': self.export_tracks,
            'track_space': self.track_space,
            'write_marker_names': self.write_marker_names,
            'deform_only': self.deform_only,
            'selected_bones_only': self.selected_bones_only,
            'compression_level': self.compression_level,
        }
        
        # Free Temporary Data
        [bpy.data.objects.remove(x) for x in bpy.data.objects if '__temp' in x.name]
        [bpy.data.armatures.remove(x) for x in bpy.data.armatures if '__temp' in x.name]
        [bpy.data.actions.remove(x) for x in bpy.data.actions if '__temp' in x.name]
        
        # Output to File
        oldlen = len(out)
        
        if self.compression_level != 0:
            out = zlib.compress(out, level=self.compression_level)
        
        file = open(path, 'wb')
        file.write(out)
        file.close()
        
        # Restore State
        if self.lastsimplify > -1:
            context.scene.render.use_simplify = self.lastsimplify
            context.scene.render.simplify_subdivision = self.lastsimplifylevels
        sourceobj.select_set(True)
        context.view_layer.objects.active = sourceobj
        
        report = 'Data written to "%s". (%.2fKB -> %.2fKB) %.2f%%' % \
            (path, oldlen / 1000, len(out) / 1000, 100 * len(out) / oldlen)
        print(report)
        self.report({'INFO'}, report)
        
        print('> Complete')
        
        return {'FINISHED'}
classlist.append(VBM_OT_ExportTRK)

# ---------------------------------------------------------------------------

class VBM_OT_ExportTRK_Repeat(bpy.types.Operator):
    bl_idname = "vbm.export_trk_repeat"
    bl_label = "Re-Export Action Tracks"
    bl_description = "Exports action curves as tracks for Location, Rotation, Scale using last export's settings"
    bl_options = {'REGISTER', 'UNDO'}
    
    def execute(self, context):
        last = context.scene.get('LastTRKExport', None)
        
        bpy.ops.vbm.export_trk(
            filepath = last['filepath'],
            armature_name = last['armature_name'],
            action_name = last['action_name'],
            range_type = last['range_type'],
            float_type = last['float_type'],
            marker_frames_only = last['marker_frames_only'],
            frame_range = last['frame_range'],
            bake_steps = last['bake_steps'],
            clean_threshold = last['clean_threshold'],
            scale = last['scale'],
            time_step = last['time_step'],
            forward_axis = last['forward_axis'],
            up_axis = last['up_axis'],
            export_matrices = last['export_matrices'],
            compress_matrices = last['compress_matrices'],
            compress_matrices_threshold = last['compress_matrices_threshold'],
            matrix_space = last['matrix_space'],
            export_tracks = last['export_tracks'],
            track_space = last['track_space'],
            write_marker_names = last['write_marker_names'],
            deform_only = last['deform_only'],
            selected_bones_only = last['selected_bones_only'],
            compression_level = last['compression_level'],
        )
        
        return {'FINISHED'}
classlist.append(VBM_OT_ExportTRK_Repeat)

# ==========================================================================================================================
# ==========================================================================================================================

def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in classlist[::-1]:
        bpy.utils.unregister_class(c)

