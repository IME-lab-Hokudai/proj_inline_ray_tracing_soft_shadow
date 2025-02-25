from pathlib import WindowsPath, PosixPath
from falcor import *

def render_graph_testrtpass():
    g = RenderGraph('testrtpass')
    g.create_pass('TestRtProgram', 'TestRtProgram', {'mode': 0})
    g.mark_output('TestRtProgram.output')
    return g

testrtpass = render_graph_testrtpass()
try: m.addGraph(testrtpass)
except NameError: None
