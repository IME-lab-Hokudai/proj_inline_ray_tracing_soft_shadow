from pathlib import WindowsPath, PosixPath
from falcor import *

def render_graph_ShadowMapFirstPass():
    g = RenderGraph('ShadowMapFirstPass')
    g.create_pass('ShadowMapFirstPass', 'ShadowMapFirstPass', {})
    g.mark_output('ShadowMapFirstPass.depth')
    return g

ShadowMapFirstPass = render_graph_ShadowMapFirstPass()
try: m.addGraph(ShadowMapFirstPass)
except NameError: None
