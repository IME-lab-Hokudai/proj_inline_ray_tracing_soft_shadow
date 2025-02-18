from pathlib import WindowsPath, PosixPath
from falcor import *

def render_graph_ShadowMapping():
    g = RenderGraph('ShadowMapping')
    g.create_pass('ShadowMapFirstPass', 'ShadowMapFirstPass', {})
    g.create_pass('TestPhongModelPass', 'TestPhongModelPass', {})
    g.add_edge('ShadowMapFirstPass.depth', 'TestPhongModelPass.shadowmap')
    g.add_edge('ShadowMapFirstPass.shadowTransform', 'TestPhongModelPass.shadowTransform')
    g.mark_output('TestPhongModelPass.output')
    return g

ShadowMapping = render_graph_ShadowMapping()
try: m.addGraph(ShadowMapping)
except NameError: None
