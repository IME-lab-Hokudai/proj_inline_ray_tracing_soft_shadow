from pathlib import WindowsPath, PosixPath
from falcor import *

def render_graph_TestPhongModel():
    g = RenderGraph('TestPhongModel')
    g.create_pass('TestPhongModelPass', 'TestPhongModelPass', {})
    g.mark_output('TestPhongModelPass.output')
    return g

TestPhongModel = render_graph_TestPhongModel()
try: m.addGraph(TestPhongModel)
except NameError: None
