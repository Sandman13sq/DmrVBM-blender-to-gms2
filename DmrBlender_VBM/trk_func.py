import bpy
import os
import struct
import zlib
import sys
import mathutils

from struct import pack as Pack

TRKVERSION = 2

FL_TRK_SPARSE = 1<<1
FL_TRK_FLOAT16 = 1<<2
FL_TRK_FLOAT64 = 1<<3

# TRK format
'''
    'TRK' (3B)
    TRK Version (1B)
    
    flags (1B)
    
    fps (1f)
    framecount (1I)
    numtracks (1I)
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
        numframes (1I)
        framepositions[numframes]
            position (1f)
        framevectors[numframes]
            vector[3]
                value (1f)
    
    nummarkers (1I)
    markernames[nummarkers]
        namelength (1B)
        namechars[namelength]
            char (1B)
    markerpositions[nummarkers]
        position (1f)
    
'''

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

# =============================================================================

def GetTRKData(context, sourceobj, sourceaction, settings, workingobj=None):
    # Settings
    float_type = settings["float_type"]
    track_space = settings["track_space"]
    matrix_space = settings["matrix_space"]
    deform_only = settings["deform_only"]
    write_marker_names = settings["write_marker_names"]
    bakesteps = settings["bake_steps"]
    timestep = settings["time_step"]
    scale = settings["scale"]
    range_type = settings["range_type"]
    mattran = settings["mattran"]
    selected_bones_only = settings["selected_bones_only"]
    marker_frames_only = settings["marker_frames_only"]
    compress_matrices = settings["compress_matrices"]
    compress_matrices_threshold = settings["compress_matrices_threshold"]
    clean_threshold = settings["clean_threshold"]
    
    compress_matrices_threshold *= compress_matrices_threshold
    
    vl = context.view_layer
    sc = context.scene
    rd = sc.render
    
    if range_type == 'CUSTOM':
        actionrange = settings['frame_range']
    elif range_type == 'KEYFRAME':
        positions = [int(k.co[0]) for fc in sourceaction.fcurves for k in fc.keyframe_points]
        actionrange = (min(positions), max(positions))
    elif range_type == 'MARKER' and sourceaction.pose_markers:
        positions = [m.frame for m in sourceaction.pose_markers]
        actionrange = (min(positions), max(positions))
    elif range_type == 'ACTION':
        actionrange = (sc.frame_start, sc.frame_end)
    else:
        actionrange = (sourceaction.frame_start, sourceaction.frame_end)
    
    if range_type == 'MARKER' and not sourceaction.pose_markers:
        print('> WARNING: No markers found for action "%s". Defaulting to scene range.' % sourceaction.name)
    
    if marker_frames_only:
        actionrange = (
            max(actionrange[0], min([m.frame for m in sourceaction.pose_markers])),
            min(actionrange[1], max([m.frame for m in sourceaction.pose_markers]))
            )
    
    print('> Beginning export for "{}"...'.format(sourceaction.name));
    
    # Create working data ----------------------------------------------------------------
    workingarmature = sourceobj.data.copy()
    workingobj = sourceobj.copy()
    
    workingobj.data = workingarmature
    workingobj.name = sourceobj.name + '__temp'
    workingarmature.name = sourceobj.data.name + '__temp'
    sc.collection.objects.link(workingobj)
    
    sourceobj.select_set(False)
    workingobj.select_set(True)
    vl.objects.active = workingobj
    bpy.ops.object.mode_set(mode='OBJECT')
    
    action = sourceaction
    workingobj.animation_data.action = action
    sc.frame_set(sc.frame_current)
    vl.update()
    
    workingobj.data.pose_position = 'POSE'
    
    # Baking ----------------------------------------------------------------
    if bakesteps > 0:
        print('> Baking animation...');
        
        contexttype = bpy.context.area.type
        bpy.context.area.type = "DOPESHEET_EDITOR"
        
        dataactions = set([x for x in bpy.data.actions])
        lastaction = sourceaction
        
        # Bake keyframes
        bpy.ops.nla.bake(
            frame_start=actionrange[0], 
            frame_end=actionrange[1], 
            step=max(1, bakesteps),
            only_selected=False, 
            visual_keying=True,
            clear_constraints=True, 
            clear_parents=True, 
            use_current_action=False, 
            clean_curves=False, 
            bake_types={'POSE'}
            );
        
        # Clean keyframes
        if clean_threshold > 0.0:
            for b in workingobj.data.bones:
                b.select = True
            
            bpy.context.area.ui_type = 'FCURVES'
            bpy.ops.graph.clean(threshold = clean_threshold, channels=True)
        
        bpy.context.area.type = contexttype
        
        dataactions = list(set([x for x in bpy.data.actions]) - dataactions)
        for x in dataactions:
            x.name += '__temp'
        action = dataactions[-1]
        action.name = lastaction.name + '__temp'
    
    # Relink armature (Rigify)
    bpy.ops.object.select_all(action='DESELECT')
    workingobj.select_set(True)
    
    bpy.ops.object.mode_set(mode='EDIT')
    
    ebones = workingobj.data.edit_bones
    deformebones = [b for b in ebones if b.use_deform]
    nondeformebones = [b for b in ebones if not b.use_deform]
    
    def FindFirstDeform(b, usedbones=[]):
        if not b.parent:
            return None
        
        usedbones.append(b)
        basename = b.name[b.name.find("-")+1:]
        
        nextdeforms = [x for x in deformebones 
            if (x not in usedbones and x.name[-len(basename):] == basename and x.use_deform)]
        
        if nextdeforms:
            return nextdeforms[0]
        if b.use_deform:
            return b
        return FindFirstDeform(b.parent)
    
    for b in deformebones:
        if not b.parent:
            continue
        
        if b.parent not in deformebones:
            b.parent = FindFirstDeform(b.parent, [b])
    
    bpy.ops.armature.layers_show_all()
    bpy.ops.armature.reveal()
    for eb in workingobj.data.edit_bones:
        eb.select = not eb.use_deform
    bpy.ops.armature.delete()
    
    bpy.ops.object.mode_set(mode='OBJECT')
    
    bones = {b.name: b for b in workingobj.data.bones}
    
    # Make dict of selected bones
    if selected_bones_only:
        bones = {b.name: b for b in bones.values() if b.select}
    
    boneparents = {b: b.parent for b in bones.values()}
    pbones = [workingobj.pose.bones[b.name] for b in bones.values()]
    
    # Make dict of deform bones
    if deform_only:
        pbones = {x.name: x for x in pbones if bones[x.name].use_deform}
        pboneparents = {pbones[b.name]: pbones[boneparents[b].name] if boneparents[b] else None for b in bones.values() if b.use_deform}
    # Make dict of all bones
    else:
        pbones = {x.name: x for x in pbones}
        pboneparents = {pbones[b.name]: pbones[boneparents[b].name] if boneparents[b] else None for b in bones.values()}
    
    bonecurves = {pbones[x]: [ [(),(),()], [(),(),(),()], [(),(),()] ] for x in pbones}
    pboneslist = [x for x in pbones.values()]
    pbonesnames = [x.name for x in pboneslist]
    bonenames = [x for x in pbones.keys()]
    
    # Action Details
    workingobj.animation_data.action = action
    
    fcurves = action.fcurves
    netframes = []
    netpositions = []
    markerframes = [m.frame for m in sourceaction.pose_markers]
    
    duration = actionrange[1]-actionrange[0]
    pnormalize = 1.0/max(1, duration)
    foffset = -actionrange[0]*pnormalize # Frame offset
    
    # Parse curve positions ----------------------------------------------------------------
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
                    
                    if not marker_frames_only:
                        keyframes = tuple([
                            ((k.co[0]), k.co[1]) 
                            for k in fc.keyframe_points if (k.co[0] >= actionrange[0] and k.co[0] <= actionrange[1])
                            ])
                    else:
                        keyframes = tuple([
                            ((k.co[0]), k.co[1]) 
                            for k in fc.keyframe_points if round(k.co[0]) in markerframes
                            ])
                    bonecurves[pbones[bonename]][transformtype][vecvalueindex] = keyframes
                    netframes += [k[0] for k in keyframes]
    # Fill for all positions ----------------------------------------------------------------
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
                        [(x, 0) for x in poslist if (x >= actionrange[0] and x <= actionrange[1])]
                        )
                    bonecurves[pbones[bonename]][transformtype][vecvalueindex] = keyframes
                    netframes += [k[0] for k in keyframes]
    
    # Only Markers' Frames
    if marker_frames_only:
        netframes = tuple([m.frame for m in sourceaction.pose_markers if (m.frame >= actionrange[0] and m.frame <= actionrange[1])])
        duration = len(netframes)
    
    if len(netframes) == 0:
        netframes = [actionrange[0]]
    netframes = list(set(netframes))
    netframes.sort()
    netframes = tuple(netframes)
    netframes = [int(x) for x in netframes]
    netframesmod = 1.0/max(1, max(netframes)-min(netframes))
    
    dg = context.evaluated_depsgraph_get()
    
    # Output ================================================================================
    outtrk = b''
    
    # Header
    outtrk += b'TRK' + Pack('B', TRKVERSION)    # Signature
    
    flags = 0
    if compress_matrices:
        flags |= FL_TRK_SPARSE
    if float_type == 'e':
        flags |= FL_TRK_FLOAT16
    if float_type == 'd':
        flags |= FL_TRK_FLOAT64
    
    outtrk += Pack('B', flags)     # Flags
    
    outtrk += Pack('f', rd.fps)     # fps
    outtrk += Pack('I', len(netframes) ) # Frame Count
    outtrk += Pack('I', len(bonenames) ) # Num tracks
    outtrk += Pack('f', duration*scale ) # Duration
    outtrk += Pack('f', timestep/(max(1, duration)*scale) ) # Position Step
    
    print('Length:', (duration+1)*scale)
    
    outtrk += b''.join([Pack('B', len(x)) + Pack('B'*len(x), *[ord(c) for c in x]) for x in bonenames]) # Track Names
    
    # Matrices ----------------------------------------------------------------------
    outtrk += Pack('B', SpaceID[matrix_space])
    
    if matrix_space != 'NONE':
        print('> Writing Matrices...');
        
        # Use convert_space() --------------------------------------------------------------------
        if matrix_space != 'EVALUATED':
            evalbones = [x for x in workingobj.pose.bones if x.name in pbonesnames]
            pbonesenumerated = enumerate(pboneslist)
            pbonesrange = range(0, len(pboneslist))
            outtrkchunk = b''
            
            for f in netframes:
                sc.frame_set(f)
                
                if compress_matrices:
                    outtrkchunk += b''.join(
                        Pack('B', (len([x for vec in m for x in vec if x*x > compress_matrices_threshold]) << 4) | int(c*4+r) )+Pack(float_type, x)
                        
                        for i in pbonesrange
                        for m in tuple(workingobj.convert_space(
                            pose_bone=evalbones[i], matrix=mattran @ evalbones[i].matrix, from_space='WORLD', to_space=matrix_space
                            ))
                        for r, vec in enumerate(m)
                        for c, x in enumerate(vec) if x*x > compress_matrices_threshold
                        )
                else:
                    outtrkchunk += b''.join(
                        Pack(float_type, x)
                        
                        for i in pbonesrange
                        for vec in workingobj.convert_space(
                            pose_bone=evalbones[i], matrix=mattran @ evalbones[i].matrix, from_space='WORLD', to_space=matrix_space
                            ).transposed()
                        for x in vec
                        )
            outtrk += outtrkchunk
        
        # Evaluate final transforms --------------------------------------------------------------------
        else:
            bmatrix = {b: (mattran @ b.matrix_local.copy()) for b in bones.values()}
            bmatlocal = {
                pbones[b.name]: (bmatrix[boneparents[b]].inverted() @ bmatrix[b] if boneparents[b] else bmatrix[b])
                for b in bones.values() if b.name in pbones.keys()
            }
            bmatinverse = {
                pbones[b.name]: bmatrix[b].inverted()
                for b in bones.values() if b.name in pbones.keys()
            }
            
            for f in netframes:
                outtrkchunk = b''
                
                sc.frame_set(f)
                dg = context.evaluated_depsgraph_get()
                evaluatedobj = workingobj.evaluated_get(dg)
                evalbones = [x for x in evaluatedobj.pose.bones if x.name in pbonesnames]
                
                localtransforms = {
                    pb: bmatlocal[pb] @ workingobj.convert_space(
                        pose_bone=evalbones[i], matrix=evalbones[i].matrix, from_space='WORLD', to_space='LOCAL'
                        )
                    for i, pb in enumerate(pboneslist)
                }
                
                bonetransforms = {}
                for pb in pboneslist:
                    bonetransforms[pb] = bonetransforms[pboneparents[pb]]@localtransforms[pb] if pboneparents[pb] else localtransforms[pb]
                
                finaltransforms = {
                    pb: bonetransforms[pb] @ bmatinverse[pb]
                    for pb in pboneslist
                }
                
                if compress_matrices:
                    outtrk += b''.join(
                        Pack('B', (len([x for vec in m for x in vec if x*x > compress_matrices_threshold]) << 4) | int(c*4+r) )+Pack(float_type, x)
                        
                        for pb in pboneslist
                        for m in [finaltransforms[pb]]
                        for r,vec in enumerate(m)
                        for c,x in enumerate(vec) if x*x > compress_matrices_threshold
                        )
                else:
                    outtrk += b''.join(
                        Pack(float_type, x)
                        
                        for pb in pboneslist
                        for v in (finaltransforms[pb]).transposed()
                        for x in v
                        )
    
    # Tracks -------------------------------------------------------------------
    outtrk += Pack('B', SpaceID[track_space])
    
    if track_space != 'NONE':
        print('> Writing Tracks...');
        posesnap = {}
        
        for pb in pboneslist:
            thisbonecurves = bonecurves[pb]
            
            outtrkchunk = b''
            
            # Transform components
            for tindex in (0, 1, 2):
                targetvecs = thisbonecurves[tindex]
                veckeyframes = list(set(k for v in targetvecs for k in v))
                vecpositions = list(set(int(x[0]) for x in veckeyframes))
                vecpositions.sort(key=lambda x: x)
                vecpositions = tuple(vecpositions)
                
                outtrkchunk += Pack('I', len(vecpositions)) # Num Frames
                outtrkchunk += b''.join([Pack(float_type, (p-actionrange[0])*netframesmod) for p in vecpositions]) # Frame Positions 
                
                # Vectors
                for f in vecpositions:
                    # Generate pose snap of matrices
                    if f not in posesnap:
                        sc.frame_set(f)
                        dg = context.evaluated_depsgraph_get()
                        evaluatedobj = workingobj.evaluated_get(dg)
                        evalbones = [x for x in evaluatedobj.pose.bones if x.name in pbonesnames]
                        
                        posesnap[f] = {
                            x: workingobj.convert_space(
                                pose_bone=evalbones[i], matrix=evalbones[i].matrix, from_space='WORLD', to_space=track_space
                            ).decompose()
                            for i, x in enumerate(pbones.values())
                        }
                    # Write vector values
                    outtrkchunk += b''.join( Pack(float_type, x) for x in posesnap[f][pb][tindex][:] ) # Vector Values
            outtrk += outtrkchunk
    
    # Markers ----------------------------------------------------------------
    if write_marker_names:
        print('> Writing Markers...');
        
        if marker_frames_only:
            markers = [(x.name, i/max(1, duration)) for i,x in enumerate(sourceaction.pose_markers)]
        else:
            markers = [(x.name, (x.frame-actionrange[0])*scale*netframesmod) for x in sourceaction.pose_markers]
        
        outtrk += Pack('I', len(markers))
        outtrk += b''.join([Pack('B', len(x[0])) + Pack('B'*len(x[0]), *[ord(c) for c in x[0]]) for x in markers]) # Names
        outtrk += b''.join([Pack(float_type, x[1]) for x in markers]) # Frames
    else:
        outtrk += Pack('I', 0)
    
    return outtrk;
