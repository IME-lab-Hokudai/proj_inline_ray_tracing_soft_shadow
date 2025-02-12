add_plugin(TestPhongModelPass)

target_sources(TestPhongModelPass PRIVATE
    TestPhongModelPass.cpp
    TestPhongModelPass.h
    PhongShader.slang
)

target_copy_shaders(TestPhongModelPass RenderPasses/TestPhongModelPass)
target_source_group(TestPhongModelPass "RenderPasses")
