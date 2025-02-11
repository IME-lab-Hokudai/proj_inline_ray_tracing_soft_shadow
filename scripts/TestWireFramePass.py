from pathlib import WindowsPath, PosixPath
from falcor import *

def render_graph_TestWireFramePass():
    g = RenderGraph('TestWireFramePass')
    g.create_pass('TestWireFramePass', 'TestWireFramePass', {})
    g.mark_output('TestWireFramePass.output')
    return g

TestWireFramePass = render_graph_TestWireFramePass()
try: m.addGraph(TestWireFramePass)
except NameError: None
