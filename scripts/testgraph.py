from pathlib import WindowsPath, PosixPath
from falcor import *

def render_graph_TestNewGraph():
    g = RenderGraph('TestNewGraph')
    g.create_pass('ImageLoader', 'ImageLoader', {'outputSize': 'Default', 'outputFormat': 'BGRA8UnormSrgb', 'filename': 'H:\\My Drive\\Research\\Reports\\PhD reports\\slide images\\cast few ray to test umbra.png', 'mips': False, 'srgb': True, 'arrayIndex': 0, 'mipLevel': 0})
    g.create_pass('ToneMapper', 'ToneMapper', {'outputSize': 'Default', 'useSceneMetadata': True, 'exposureCompensation': 0.0, 'autoExposure': False, 'filmSpeed': 100.0, 'whiteBalance': False, 'whitePoint': 6500.0, 'operator': 'Aces', 'clamp': True, 'whiteMaxLuminance': 1.0, 'whiteScale': 11.199999809265137, 'fNumber': 1.0, 'shutter': 1.0, 'exposureMode': 'AperturePriority'})
    g.add_edge('ImageLoader.dst', 'ToneMapper.src')
    g.mark_output('ToneMapper.dst')
    return g

TestNewGraph = render_graph_TestNewGraph()
try: m.addGraph(TestNewGraph)
except NameError: None
