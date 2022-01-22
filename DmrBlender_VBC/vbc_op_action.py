import bpy
import struct
import zlib
import sys
import mathutils

from bpy_extras.io_utils import ExportHelper
from struct import pack as Pack

PackString = lambda x: b'%c%s' % (len(x), str.encode(x))
PackVector = lambda v: b''.join([struct.pack('<f', x) for x in v])
PackMatrix = lambda m: b''.join( [struct.pack('<ffff', *x) for x in m.copy().transposed()] )
QuatValid = lambda q: q if q.magnitude != 0.0 else [1.0, 0.0, 0.0, 0.00001]

TRKVERSION = 1

# TRK format
'''
    'TRK' (3B)
    TRK Version (1B)
    
    flags (1B)
    fps (1f)
    animationlength (1f)
    positionstep (1f)
    
    numtracks (4B)
    tracknames[numtracks]
        namelength (1B)
        namechars[namelength]
            char (1B)
    
    trackdata[numtracks]
        numframes (4B)
        framepositions[numframes]
            position (1f)
        framevectors[numframes]
            vector[3]
                value (1f)
    
    nummarkers (4B)
    markernames[nummarkers]
        namelength (1B)
        namechars[namelength]
            char (1B)
    markerpositions[nummarkers]
        position (1f)
    
'''

# =============================================================================

def Items_GetActions(self, context):
    return [
        (a.name, a.name, 'Export "%s"' % a.name, 'ACTION', i)
        for i, a in enumerate(bpy.data.actions)
    ]

def Items_GetArmatureObjects(self, context):
    return [
        (a.name, a.name, '%s' % a.name, 'ARMATURE_DATA', i)
        for i, a in enumerate(bpy.data.objects) if a.type == 'ARMATURE'
    ]

def ChooseAction(self, context):
    action = bpy.data.actions[self.actionname]

# =============================================================================

classlist = []

# =============================================================================

class ExportActionSuper(bpy.types.Operator, ExportHelper):
    armature_object: bpy.props.EnumProperty(
        name='Armature Object', items=Items_GetArmatureObjects, default=0,
        description='Armature object to use for pose matrices'
    )
    
    action_name: bpy.props.EnumProperty(
        name='Action', items=Items_GetActions, default=0,
        description='Action to export',
    )
    
    range_type: bpy.props.EnumProperty(
        name='Range Type', default=0, items=(
            ('SCENE', 'Scene Range', 'Export keyframes from first marker to last'),
            ('KEYFRAME', 'Clamp To Keyframes', 'Export keyframes from starting keyframe to end keyframe'),
            ('MARKER', 'Clamp To Markers', 'Export keyframes from first marker to last'),
            ('CUSTOM', 'Custom Range', 'Define custom frame range'),
        )
    )
    
    frame_range: bpy.props.IntVectorProperty(
        name='Frame Range', size=2, default=(1, 250),
        description='Range of keyframes to export',
    )
    
    bake_steps: bpy.props.IntProperty(
        name="Bake Steps", default=1, min=-1,
        description="Sample curves so that every nth frame has a vector.\nSet to 0 for no baking.\nSet to -1 for all frames (Good for Pose Libraries)",
    )
    
    scale: bpy.props.FloatProperty(
        name="Action Scale", default=1.0,
        description="Scales positions of keyframes.",
    )
    
    time_step: bpy.props.FloatProperty(
        name="Time Step", default=1.0,
        description="Speed modifier for track playback.",
    )
    
    space: bpy.props.EnumProperty(
        name='Space', default=0, items=(
            ('LOCAL', 'Local Space', "Bone matrices are relative to bone's parent"),
            ('POSE', 'Pose Space', 'Bone matrices are relative to armature origin'),
            ('WORLD', 'World Space', 'Bone matrices are relative to world origin'),
        )
    )
    
    write_marker_names: bpy.props.BoolProperty(
        name="Write Marker Names", default=True,
        description="Write names of markers before track data",
    )
    
    normalize_frames: bpy.props.BoolProperty(
        name="Normalize Frames", default=True,
        description="Convert Frames to [0-1] range",
    )
    
    deform_only: bpy.props.BoolProperty(
        name="Deform Bones Only", default=True,
        description='Only export bones with the "Deform" box checked',
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
                    self.armature_object = o.name
                    self.action_name = o.animation_data.action.name
                    break
                elif o.pose_library:
                    self.armature_object = o.name
                    self.action_name = o.pose_library.name
            
        context.window_manager.fileselect_add(self)
        
        return {'RUNNING_MODAL'}
    
    def cancel(self, context):
        context.scene.render.use_simplify = self.lastsimplify
        context.scene.render.simplify_subdivision = self.lastsimplifylevels

# =============================================================================

class DMR_OP_VBC_ExportActionTracks(ExportActionSuper, ExportHelper):
    bl_idname = "dmr.vbc_export_action_tracks"
    bl_label = "Export Action Tracks"
    bl_description = 'Exports action curves as tracks for Location, Rotation, Scale'
    bl_options = {'PRESET'}
    
    filename_ext = ".trk"
    filter_glob: bpy.props.StringProperty(default="*"+filename_ext, options={'HIDDEN'}, maxlen=255)
    
    def draw(self, context):
        layout = self.layout
        
        c = layout.column()
        c.prop(self, 'armature_object')
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
        c.prop(self, 'bake_steps')
        r = c.row(align=1)
        r.prop(self, 'scale', text='Scale')
        r.prop(self, 'time_step')
        c.prop(self, 'space')
        c.separator();
        c.prop(self, 'write_marker_names')
        c.prop(self, 'normalize_frames')
        c.prop(self, 'deform_only')
        c.prop(self, 'compression_level')
        
    def execute(self, context):
        # Settings
        normalize_frames = self.normalize_frames
        deform_only = self.deform_only
        write_marker_names = self.write_marker_names
        bakesteps = self.bake_steps
        timestep = self.time_step
        scale = self.scale
        space = self.space
        
        # Clear temporary data
        [bpy.data.objects.remove(x) for x in bpy.data.objects if '__temp' in x.name]
        [bpy.data.armatures.remove(x) for x in bpy.data.armatures if '__temp' in x.name]
        [bpy.data.actions.remove(x) for x in bpy.data.actions if '__temp' in x.name]
        
        vl = context.view_layer
        sc = context.scene
        rd = sc.render
        
        # Validation
        sourceobj = [x for x in bpy.data.objects if x.name == self.armature_object]
        if not sourceobj:
            self.info({'WARNING', 'No object with name "{}" found'.format(self.armature_object)})
            rd.use_simplify = self.lastsimplify
            rd.simplify_subdivision = self.lastsimplifylevels
            return {'FINISHED'}
        sourceobj = sourceobj[0]
        if sourceobj.type != 'ARMATURE':
            self.info({'WARNING'}, '"{}" is not armature'.format(self.armature_object))
            rd.use_simplify = self.lastsimplify
            rd.simplify_subdivision = self.lastsimplifylevels
            return {'FINISHED'}
        
        sourceaction = [x for x in bpy.data.actions if x.name == self.action_name]
        if not sourceaction:
            self.info({'WARNING', 'No action with name "{}" found'.format(self.action_name)})
            rd.use_simplify = self.lastsimplify
            rd.simplify_subdivision = self.lastsimplifylevels
            return {'FINISHED'}
        sourceaction = sourceaction[0]
        
        if self.range_type == 'CUSTOM':
            actionrange = (self.frame_range[0], self.frame_range[1])
        elif self.range_type == 'KEYFRAME':
            positions = [k.co[0] for fc in sourceaction.fcurves for k in fc.keyframe_points]
            actionrange = (min(positions), max(positions))
        elif self.range_type == 'MARKER':
            positions = [m.frame for m in sourceaction.pose_markers]
            actionrange = (min(positions), max(positions)+1)
        else:
            actionrange = (sc.frame_start, sc.frame_end)
        
        # Create working data
        workingarmature = sourceobj.data.copy()
        workingobj = sourceobj.copy()
        
        workingobj.data = workingarmature
        workingobj.name = sourceobj.name + '__temp'
        workingarmature.name = sourceobj.data.name + '__temp'
        sc.collection.objects.link(workingobj)
        
        sourceobj.select_set(False)
        workingobj.select_set(True)
        vl.objects.active = workingobj
        
        action = sourceaction
        
        if bakesteps > 0:
            print('> Baking animation...');
            
            contexttype = bpy.context.area.type
            bpy.context.area.type = "DOPESHEET_EDITOR"
            
            dataactions = set([x for x in bpy.data.actions])
            lastaction = sourceaction
            
            bpy.ops.nla.bake(
                frame_start=actionrange[0], frame_end=actionrange[1], 
                step=max(1, bakesteps),
                only_selected=False, 
                visual_keying=True,
                clear_constraints=False, 
                clear_parents=False, 
                use_current_action=False, 
                clean_curves=False, 
                bake_types={'POSE'}
                );
            
            bpy.context.area.type = contexttype
            
            dataactions = list(set([x for x in bpy.data.actions]) - dataactions)
            for x in dataactions:
                x.name += '__temp'
            action = dataactions[0]
            action.name = lastaction.name + '__temp'
            print([lastaction.name, action.name])
            
        workingobj.animation_data.action = action
        
        fcurves = action.fcurves
        
        bones = workingobj.data.bones
        pbones = workingobj.pose.bones
        if deform_only:
            pbones = {x.name: x for x in pbones if bones[x.name].use_deform}
        bonenames = [x for x in pbones.keys()]
        bonecurves = {pbones[x]: [ [(),(),()], [(),(),(),()], [(),(),()] ] for x in pbones}
        
        netframes = ()
        
        duration = actionrange[1]-actionrange[0]
        pmod = 1.0/duration if normalize_frames else 1.0
        
        # Parse curves
        if bakesteps >= 0:
            for fc in fcurves:
                dp = fc.data_path
                bonename = dp[dp.find('"')+1:dp.rfind('"')]
                
                if bonename in bonenames:
                    transformstring = dp[dp.rfind('.')+1:]
                    transformtype = -1
                    
                    if transformstring == 'location':
                        transformtype = 0
                    elif transformstring == 'rotation_quaternion':
                        transformtype = 1
                    elif transformstring == 'scale':
                        transformtype = 2
                    
                    if transformtype >= 0:
                        vecvalueindex = fc.array_index
                        keyframes = tuple(
                            [(x.co[0]*pmod, x.co[1]) for x in fc.keyframe_points if (x.co[0] >= actionrange[0] and x.co[0] <= actionrange[1])]
                            )
                        bonecurves[pbones[bonename]][transformtype][vecvalueindex] = keyframes
                        netframes += tuple(x[0] for x in keyframes)
        # Fill for all positions
        else:
            poslist = [x for x in range(actionrange[0], actionrange[1]+1)]
            for fc in fcurves:
                dp = fc.data_path
                bonename = dp[dp.find('"')+1:dp.rfind('"')]
                
                if bonename in bonenames:
                    transformstring = dp[dp.rfind('.')+1:]
                    transformtype = -1
                    
                    if transformstring == 'location':
                        transformtype = 0
                    elif transformstring == 'rotation_quaternion':
                        transformtype = 1
                    elif transformstring == 'scale':
                        transformtype = 2
                    
                    if transformtype >= 0:
                        vecvalueindex = fc.array_index
                        keyframes = tuple(
                            [(x*pmod, 0) for x in poslist if (x >= actionrange[0] and x <= actionrange[1])]
                            )
                        bonecurves[pbones[bonename]][transformtype][vecvalueindex] = keyframes
                        netframes += tuple(x[0] for x in keyframes)
        
        netframes = list(set(netframes))
        netframes.sort()
        
        # Output ---------------------------------------------------------------
        out = b''
        
        # Header
        out += b'TRK' + Pack('B', TRKVERSION)    # Signature
        out += Pack('B', 1)     # Flags
        out += Pack('f', rd.fps)     # fps
        out += Pack('f', duration*scale ) # Frame Count
        out += Pack('f', timestep/(duration*scale) ) # Position Step
        
        print('Length:', duration*scale)
        
        out += Pack('I', len(pbones) ) # Num tracks
        out += b''.join([Pack('B', len(x)) + Pack('B'*len(x), *[ord(c) for c in x]) for x in bonenames]) # Names
        
        posesnap = {}
        
        foffset = -actionrange[0]*pmod # Frame offset
        
        # Bone loop
        for pb in pbones.values():
            thisbonecurves = bonecurves[pb]
            
            outchunk = b''
            
            # Transform components
            for tindex in (0, 1, 2):
                targetvecs = thisbonecurves[tindex]
                veckeyframes = list(set(k for v in targetvecs for k in v))
                vecpositions = list(set(x[0] for x in veckeyframes))
                vecpositions.sort(key=lambda x: x)
                vecpositions = tuple(vecpositions)
                
                outchunk += Pack('I', len(vecpositions)) # Num Frames
                outchunk += b''.join([Pack('f', x*scale+foffset) for x in vecpositions]) # Frame Positions 
                
                # Vectors
                for f in vecpositions:
                    # Generate pose snap of matrices
                    if f not in posesnap:
                        sc.frame_set(int(f/pmod))
                        vl.update()
                        posesnap[f] = {
                            x: workingobj.convert_space(
                                pose_bone=x, matrix=x.matrix, from_space='WORLD', to_space=space
                            ).decompose() 
                            for x in pbones.values()
                        }
                    outchunk += b''.join( Pack('f', x) for x in posesnap[f][pb][tindex][:] ) # Vector Values
            out += outchunk
        
        # Markers
        if write_marker_names:
            markers = [(x.name, x.frame*scale*pmod) for x in sourceaction.pose_markers]
            #markers.sort(key=lambda x: x[0])
            out += Pack('I', len(markers))
            out += b''.join([Pack('B', len(x[0])) + Pack('B'*len(x[0]), *[ord(c) for c in x[0]]) for x in markers]) # Names
            out += b''.join([Pack('f', x[1]+foffset) for x in markers]) # Frames
        else:
            out += Pack('I', 0)
        
        # Restore State
        [bpy.data.objects.remove(x) for x in bpy.data.objects if '__temp' in x.name]
        [bpy.data.armatures.remove(x) for x in bpy.data.armatures if '__temp' in x.name]
        [bpy.data.actions.remove(x) for x in bpy.data.actions if '__temp' in x.name]
        
        rd.use_simplify = self.lastsimplify
        rd.simplify_subdivision = self.lastsimplifylevels
        sourceobj.select_set(True)
        vl.objects.active = sourceobj
        
        # Output to File
        oldlen = len(out)
        out = zlib.compress(out, level=self.compression_level)
        
        file = open(self.filepath, 'wb')
        file.write(out)
        file.close()
        
        report = 'Data written to "%s". (%.2fKB -> %.2fKB) %.2f%%' % \
            (self.filepath, oldlen / 1000, len(out) / 1000, 100 * len(out) / oldlen)
        print(report)
        self.report({'INFO'}, report)
        
        print('> Complete')
        
        return {'FINISHED'}
classlist.append(DMR_OP_VBC_ExportActionTracks)

# =============================================================================
def register():
    for c in classlist:
        bpy.utils.register_class(c)

def unregister():
    for c in reversed(classlist):
        bpy.utils.unregister_class(c)
