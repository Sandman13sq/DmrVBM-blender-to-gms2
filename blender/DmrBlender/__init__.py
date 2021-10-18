bl_info = {
    'name': 'Dmr Blender Tools',
    'category': 'All',
    'version': (0, 0, 1),
    'blender': (2, 9, 0)
}
 
modulesNames = [
    'utilities',
    'dmr_hotmenu',
    'dmr_misc_op',
    
    'dmr_vcolor_panel',
    'dmr_vcolor_op',
    'dmr_vgroup_panel',
    'dmr_vgroup_op',
    'dmr_pose_panel',
    'dmr_pose_op',
    'dmr_vertex_op',
    'dmr_sculpt_op',
    ]
 
import sys
import importlib

print('> Loading %s...' % bl_info['name']);
 
modulesFullNames = {}
for currentModuleName in modulesNames:
    if 'DEBUG_MODE' in sys.argv:
        modulesFullNames[currentModuleName] = ('{}'.format(currentModuleName))
    else:
        modulesFullNames[currentModuleName] = ('{}.{}'.format(__name__, currentModuleName))

for i in [0, 0]:
    for currentModuleFullName in modulesFullNames.values():
        if currentModuleFullName in sys.modules:
            importlib.reload(sys.modules[currentModuleFullName])
        else:
            globals()[currentModuleFullName] = importlib.import_module(currentModuleFullName)
            setattr(globals()[currentModuleFullName], 'modulesNames', modulesFullNames)
 
def register():
    for currentModuleName in modulesFullNames.values():
        if currentModuleName in sys.modules:
            if hasattr(sys.modules[currentModuleName], 'register'):
                sys.modules[currentModuleName].register()
 
def unregister():
    for currentModuleName in modulesFullNames.values():
        if currentModuleName in sys.modules:
            if hasattr(sys.modules[currentModuleName], 'unregister'):
                sys.modules[currentModuleName].unregister()
 
if __name__ == "__main__":
    register()

print(modulesNames)