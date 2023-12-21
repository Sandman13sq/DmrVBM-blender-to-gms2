bl_info = {
    'name': 'DmrVBM Vertex Buffer Model Export',
    'description': 'Export tools to export data to Game Maker Studio 2',
    'author': 'Sandman13sq',
    'category': 'Import-Export',
    'version': (1, 3, 0),
    'blender': (3, 0, 0),
    'support': 'COMMUNITY',
    'doc_url': 'https://github.com/Sandman13sq/DmrVBM-blender-to-gms2',
}
 
modulesNames = [
    'vbm_addon',
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
    for currentModuleName in list(modulesFullNames.values())[::-1]:
        if currentModuleName in sys.modules:
            if hasattr(sys.modules[currentModuleName], 'unregister'):
                sys.modules[currentModuleName].unregister()
 
if __name__ == "__main__":
    register()
