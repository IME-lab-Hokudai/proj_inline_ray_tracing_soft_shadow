add_plugin(TestWireFramePass)

target_sources(TestWireFramePass PRIVATE
    TestWireFramePass.cpp
    TestWireFramePass.h
    WireFrameShader.slang
)

target_copy_shaders(TestWireFramePass RenderPasses/TestWireFramePass)
target_source_group(TestWireFramePass "RenderPasses")
