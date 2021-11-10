import bpy
import struct
import zlib
import sys

from bpy_extras.io_utils import ExportHelper
from bpy.props import StringProperty, BoolProperty, EnumProperty, IntProperty
from struct import pack as Pack

PackString = lambda x: b'%c%s' % (len(x), str.encode(x));
PackVector = lambda v: b''.join([struct.pack('<f', x) for x in v]);
PackMatrix = lambda m: b''.join( [struct.pack('<ffff', *x) for x in m.copy().transposed()] );
QuatValid = lambda q: q if q.magnitude != 0.0 else [1.0, 0.0, 0.0, 0.00001];

ANIVERSION = 1;

"""
    header = 'ANI<version>'
    
    flag
        1<<0 = Frames are normalized
    maxframe
    trackcount
    tracknames[trackcount]
    trackdata[trackcount]
        location_framecount
        location_framepositions[location_framecount]
        location_vectors[location_framecount]
            vector[3]
        
        quaternion_framecount
        quaternion_framepositions[quaternion_framecount]
        quaternion_vectors[quaternion_framecount]
            vector[4]
        
        scale_framecount
        scale_framepositions[scale_framecount]
        scale_vectors[scale_framecount]
            vector[3]
    
    markercount
    markernames[markercount]
    markerframepositions[markercount]
    
"""

# =============================================================================

#def ExportAction(settings = {}):
    

classlist = [];

# =============================================================================

class DMR_GM_ExportPose(bpy.types.Operator, ExportHelper):
    """Exports current armature pose"""
    bl_idname = "dmr.gm_export_pose";
    bl_label = "Export Pose";
    
    filename_ext = ".pse"
    filter_glob: StringProperty(default="*.pse", options={'HIDDEN'}, maxlen=255);
    
    def execute(self, context):
        active = bpy.context.view_layer.objects.active;
        settings = {
            'path' : self.filepath,
        };
        ExportPose( FetchArmature(active), settings );
        bpy.context.view_layer.objects.active = active;
        self.report({'INFO'}, 'Data written to "%s"' % self.filepath);
        return {'FINISHED'}
classlist.append(DMR_GM_ExportPose);

# =============================================================================

class DMR_GM_ExportAction(bpy.types.Operator, ExportHelper):
    """Exports all poses in active object's Action/Pose Library"""
    bl_idname = "dmr.gm_export_action";
    bl_label = "Export Action";
    bl_options = {'PRESET'};
    
    filename_ext = ".trk";
    filter_glob: StringProperty(default="*"+filename_ext, options={'HIDDEN'}, maxlen=255);
    
    bakesamples: IntProperty(
        name="Bake Steps",
        description="Sample curves so that every nth frame has a vector.\nSet to 0 for no baking",
        default=5, min=-1
    );
    
    startfromzero: BoolProperty(
        name="Trim Empty Leading",
        description='Start writing from first keyframe instead of from "Frame Start"',
        default=True,
    );
    
    writemarkernames: BoolProperty(
        name="Write Marker Names",
        description="Write names of markers before track data",
        default=True,
    );
    
    normalizeframes: BoolProperty(
        name="Normalize Frames",
        description="Convert Frames to [0-1] range",
        default=True,
    );
    
    makestartframe: BoolProperty(
        name="Starting Keyframe",
        description="Insert a keyframe at the start of the animation",
        default=True,
    );
    
    makeendframe: BoolProperty(
        name="Ending Keyframe",
        description="Insert a keyframe at the end of the animation",
        default=False,
    );
    
    lastsimplify = -1;
    
    def invoke(self, context, event):
        context.window_manager.fileselect_add(self);
        self.lastsimplify = context.scene.render.use_simplify;
        context.scene.render.use_simplify = True;
        return {'RUNNING_MODAL'}
    
    def cancel(self, context):
        context.scene.render.use_simplify = self.lastsimplify;
        return {'FINISHED'}
    
    def draw(self, context):
        layout = self.layout;
        layout.prop(self, 'bakesamples');
        layout.prop(self, 'startfromzero');
        layout.prop(self, 'writemarkernames');
        layout.prop(self, 'normalizeframes');
        layout.prop(self, 'makestartframe');
        layout.prop(self, 'makeendframe');
        
    def execute(self, context):
        # Find Armature
        object = bpy.context.object;
        if not object:
            self.report({'WARNING'}, 'No object selected');
            return {'FINISHED'}
        if object.type != 'ARMATURE':
            self.report({'WARNING'}, 'Active object "%s" is not an armature' % object.name);
            return {'FINISHED'}
        
        # Find Last Action
        poselibonly = 0;
        if not (object.animation_data and object.animation_data.action):
            lastaction = None;
            poselibonly = 1;
        else:
            lastaction = object.animation_data.action;
        if not lastaction:
            lastaction = object.pose_library;
        if not lastaction:
            self.report({'WARNING'}, '"%s" has no active Action' % object.name);
            context.scene.render.use_simplify = self.lastsimplify;
            return {'FINISHED'}
        
        bones = object.data.bones;
        prepose = [b.matrix_basis.copy() for b in object.pose.bones];
        
        # Get sampled action
        if self.bakesamples > 0 and 0:
            print('> Baking animation...');
            
            contexttype = bpy.context.area.type
            bpy.context.area.type = "DOPESHEET_EDITOR"
            
            bpy.ops.nla.bake(
                frame_start=lastaction.frame_range[0], frame_end=lastaction.frame_range[1], 
                step=self.bakesamples,
                only_selected=False, 
                visual_keying=False, 
                clear_constraints=False, 
                clear_parents=False, 
                use_current_action=False, 
                clean_curves=True, 
                bake_types={'POSE'}
                );
            
            #bpy.ops.action.clean(channels=True); # Remove untouched channels
            #bpy.ops.action.clean(channels=False); # Simplify Animation
            
            bpy.context.area.type = contexttype;
            action = object.animation_data.action;
            action.name = lastaction.name + '__temp';
            object.animation_data.action = lastaction;
            
            print('> Animation ready');
        else:
            if object.animation_data and object.animation_data.action:
                action = object.animation_data.action;
            else:
                action = object.pose_library;
        
        fcurves = action.fcurves;
        framerange = action.frame_range;
        frameoffset = -framerange[0] if self.startfromzero else 0;
        framemax = framerange[1] + frameoffset;
        
        transformnames = ['location', 'rotation_quaternion', 'scale'];
        entryoffset = {'location': 0, 'rotation_quaternion': 3, 'scale': 7};
        bonecurvemap = { b.name: [None] * 10 for b in bones };
        
        # Grab all curves and sort by bone name
        for c in fcurves:
            pth = c.data_path;
            bonename = pth[pth.find('"')+1 : pth.rfind('"')];
            if bonename in bonecurvemap.keys():
                transformname = pth[pth.rfind('.')+1:];
                if transformname in entryoffset.keys():
                    bonecurvemap[bonename][entryoffset[transformname] + c.array_index] = c;
        
        # Make a snapshot of pose bones for every frame
        posebones = object.pose.bones;
        posesnap = {};
        
        SnapPose = lambda : {
            #pb.name: (pb.location[:], pb.rotation_quaternion[:], pb.scale[:])
            pb.name: object.convert_space(
                pose_bone=pb, matrix=pb.matrix, from_space='POSE', to_space='LOCAL').decompose()
                for pb in posebones
            };
        
        if not poselibonly:
            for f in range(int(framerange[0]), int(framerange[1])):
                context.scene.frame_set(f);
                bpy.context.view_layer.update();
                posesnap[f] = SnapPose();
        else:
            lastobjectmode = bpy.context.active_object.mode;
            bpy.ops.object.mode_set(mode = 'POSE'); # Update selected
            
            selected = [b for b in bones if b.select];
            hidden = [b for b in bones if b.hide];
            for b in hidden:
                b.hide = False;
            
            markers = action.pose_markers;
            bpy.ops.pose.select_all(action='SELECT');
            for m in markers:
                print(m.name);
                bpy.ops.poselib.apply_pose(pose_index=m.frame);
                posesnap[m.frame] = SnapPose();
            bpy.ops.pose.select_all(action='DESELECT');
            
            for b in hidden:
                b.hide = True;
            for b in selected:
                b.select = True;
            
            bpy.ops.object.mode_set(mode = lastobjectmode);
            
        
        # Compose data ------------------------------------------------------
        print('> Composing data...');
        
        out = b'';
        
        out += b'TRK' + Pack('B', ANIVERSION);
        
        # Flag
        flag = 0;
        if self.normalizeframes:
            flag |= 1<<0;
        out += Pack('B', flag);
        
        render = context.scene.render;
        view_layer = bpy.context.view_layer;
        view_layer.update();
        scene = context.scene;
        
        for obj in scene.objects:
            if obj.type == 'MESH':
                obj.data.update();
        
        out += Pack('f', render.fps); # Animation Framerate
        out += Pack('H', int(framemax) ); # Max animation frame
        out += Pack('H', len(bones)); # Bone Count
        
        # Write Track Names
        out += b''.join( [PackString(b.name) for b in bones] );
        
        # Track Data
        if poselibonly:
            print("> Pose library only");
        print('Action = "%s", Range: %s' % (action.name, framerange));
        print('> Writing Tracks...');
        
        frame_map_old = render.frame_map_old;
        #render.frame_map_old = render.frame_map_new / 10;
        
        # Settings
        samples = self.bakesamples;
        if samples < 0:
            samples = framerange[1]-framerange[0];
        makestartframe = self.makestartframe;
        makeendframe = self.makeendframe;
        
        for b in bones: # For each bone (track)
            outchunk = b'';
            transcurves = bonecurvemap[b.name];
            posebone = object.pose.bones[b.name];
            #print(b.name);
            
            transformtype = 0;
            
            # For each transform (location[3], quat[4], scale[3])
            for vectorindices in [ [0,1,2], [3,4,5,6], [7,8,9] ]:
                # Grab transform curves using trackindices
                curveset = transcurves[vectorindices[0]:vectorindices[-1]+1];
                
                # Merge keyframe positions for each track in transform
                # [location[0].frames + location[1].frames + location[2].frames]
                trackframes = set([
                    k.co[0]
                    for curve in curveset
                    for k in (curve.keyframe_points if curve else [])
                ]);
                
                if makestartframe:
                    trackframes.add(framerange[0]);
                if makeendframe:
                    trackframes.add(framerange[1]);
                    
                trackframes = list(trackframes);
                trackframes.sort();
                
                # Manual Sampling
                #"""
                if samples > 0 and len(trackframes) > 1:
                    newpts = [];
                    for i in range(0, len(trackframes)-1):
                        p1 = trackframes[i];
                        p2 = trackframes[i+1];
                        step = (p2-p1) / samples;
                        while p1 < p2:
                            newpts.append(p1);
                            p1 += step;
                        newpts.append(p2);
                    newpts = list(set([round(x) for x in newpts]));
                    newpts.sort();
                    trackframes = newpts;
                #"""
                outchunk += Pack('H', len(trackframes)); # Frame count
                
                # Write Frame Positions
                if self.normalizeframes: # Frame Positions are [0-1] range
                    outchunk += b''.join( Pack('f', (frame+frameoffset)/framemax) for frame in trackframes );
                else: # Frame positions are unchanged
                    outchunk += b''.join( Pack('f', frame+frameoffset) for frame in trackframes );
                
                # For each frame in track
                for f in trackframes:
                    if f not in posesnap.keys():
                        scene.frame_set(f);
                        view_layer.update()
                        posesnap[f] = {
                            #pb.name: (pb.location[:], pb.rotation_quaternion[:], pb.scale[:])
                            pb.name: object.convert_space(pose_bone=pb, matrix=pb.matrix, from_space='POSE', to_space='LOCAL').decompose()
                            for pb in posebones
                        };
                    
                    # Write Vector
                    outchunk += PackVector( posesnap[f][b.name][transformtype] );
                
                transformtype += 1;
                 
            # Add chunk to output
            out += outchunk;
        
        render.frame_map_old = frame_map_old;
        
        # Write Marker Data
        if self.writemarkernames:
            print('> Writing Marker Data...');
            
            markers = [m for m in lastaction.pose_markers];
            #markers.sort(key = lambda m: m.frame);
            
            out += Pack('H', len(markers));
            # Write Marker Names
            out += b''.join( [PackString(m.name) for m in markers] );
            # Write Marker Frame Positions
            if self.normalizeframes:
                out += b''.join( [Pack('f', (m.frame+frameoffset)/framemax) for m in markers] );
                for m in markers:
                    print("<%s: %.4f>" % (m.name, (m.frame+frameoffset)/framemax))
            else:
                out += b''.join( [Pack('f', m.frame+frameoffset) for m in markers] );
                for m in markers:
                    print("<%s: %.4f>" % (m.name, m.frame+frameoffset))
        else:
            out += Pack('H', 0);
        
        # Restore Previous State
        for i in range(0, len(object.pose.bones)):
            object.pose.bones[i].matrix_basis = prepose[i];
        #if poselibonly:
            #object.animation_data = None;
        render.use_simplify = self.lastsimplify;
        
        # Output to File
        oldlen = len(out);
        out = zlib.compress(out);
        
        file = open(self.filepath, 'wb');
        file.write(out);
        file.close();
        
        report = 'Data written to "%s". (%.2fKB -> %.2fKB) %.2f%%' % \
            (self.filepath, oldlen / 1000, len(out) / 1000, 100 * len(out) / oldlen);
        print(report);
        self.report({'INFO'}, report);
        return {'FINISHED'}
classlist.append(DMR_GM_ExportAction);

# =============================================================================

class DMR_GM_ExportPoseMatrix(bpy.types.Operator, ExportHelper):
    """Exports all poses in active object's Action/Pose Library"""
    bl_idname = "dmr.gm_export_posematrix";
    bl_label = "Export Action";
    
    filename_ext = ".pse";
    filter_glob: StringProperty(default="*"+filename_ext, options={'HIDDEN'}, maxlen=255);
    
    def execute(self, context):
        # Find Armature ----------------------------------------------------
        object = bpy.context.object;
        if not object:
            self.report({'WARNING'}, 'No object selected');
            return {'FINISHED'}
        if object.type != 'ARMATURE':
            self.report({'WARNING'}, 'Active object "%s" is not an armature' % object.name);
            return {'FINISHED'}
        
        # Setup Vars ----------------------------------------------------
        object = bpy.context.object;
        bones = object.data.bones;
        pbones = object.pose.bones;
        prepose = [b.matrix_basis.copy() for b in pbones];
        
        action = object.pose_library;
        markers = action.pose_markers;
        print([(m.name, m.frame) for m in action.pose_markers])
        keyframes = [m.frame for m in action.pose_markers];
        #keyframes.sort(key = lambda x : x[1]);
        keyframes.sort();
        
        # Get Poses ----------------------------------------------------
        out = b'';
        
        out += Pack('<I', len(bones));
        out += Pack('<I', len(keyframes));
        
        # Store State
        lastobjectmode = bpy.context.active_object.mode;
        bpy.ops.object.mode_set(mode = 'POSE'); # Update selected
        selected = [b for b in bones if b.select];
        hidden = [b for b in bones if b.hide];
        
        for b in hidden: b.hide = False;
        bpy.ops.pose.select_all(action='SELECT');
        
        # Pose iteration ===============================================
        for i in range(0, len(markers)):
            # Set pose
            bpy.ops.poselib.apply_pose(pose_index=i);
            chunk = b'';
            # Write matrix data
            for pb in pbones:
                chunk += PackMatrix(pb.matrix_channel);
            out += chunk;
            
        # Restore State ------------------------------------------------
        bpy.ops.pose.select_all(action='DESELECT');
        for b in selected: b.select = True;
        for b in hidden: b.hide = True;
        for i in range(0, len(pbones)):
            pbones[i].matrix_basis = prepose[i];
        bpy.ops.object.mode_set(mode = lastobjectmode);
        
        # Output to File ===============================================
        oldlen = len(out);
        out = zlib.compress(out);
        
        file = open(self.filepath, 'wb');
        file.write(out);
        file.close();
        
        report = 'Data written to "%s". (%.2fKB -> %.2fKB) %.2f%%' % \
            (self.filepath, oldlen / 1000, len(out) / 1000, 100 * len(out) / oldlen);
        print(report);
        self.report({'INFO'}, report);
        
        return {'FINISHED'}
classlist.append(DMR_GM_ExportPoseMatrix);      

def register():
    for c in classlist:
        bpy.utils.register_class(c)
    #bpy.ops.dmr.gm_export_action('INVOKE_DEFAULT');

def unregister():
    for c in classlist:
        bpy.utils.unregister_class(c)
