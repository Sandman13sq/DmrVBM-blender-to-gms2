bl_info = {
    'name': 'DmrVBM Vertex Buffer Model Export',
    'category': 'Import-Export',
    'version': (1, 1),
    'blender': (3, 0, 0)
}
 
modulesNames = [
    'utilities',
    'vbm_func',
    'vbm_presets',
    'vbm_op',
    'vbm_op_action',
    'vbm_panel',
    'vbm_exportlist',
    ]

import sys
import importlib

print('> Loading %s...' % bl_info['name'])
 
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

# =============================================================================

def register():
    for currentModuleName in modulesFullNames.values():
        if currentModuleName in sys.modules:
            if hasattr(sys.modules[currentModuleName], 'register'):
                sys.modules[currentModuleName].register()
 
def unregister():
    for currentModuleName in reversed(modulesFullNames.values()):
        if currentModuleName in sys.modules:
            if hasattr(sys.modules[currentModuleName], 'unregister'):
                sys.modules[currentModuleName].unregister()
 
if __name__ == "__main__":
    register()
