from pathlib import WindowsPath, PosixPath
from falcor import *

def render_graph_IRLSSNaive():
    g = RenderGraph('IRLSSNaive')
    g.create_pass('IRLSSNaiveImplement', 'IRLSSNaiveImplement', {})
    g.mark_output('IRLSSNaiveImplement.output')
    return g

IRLSSNaive = render_graph_IRLSSNaive()
try: m.addGraph(IRLSSNaive)
except NameError: None
