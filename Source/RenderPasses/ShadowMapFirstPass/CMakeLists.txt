add_plugin(ShadowMapFirstPass)

target_sources(ShadowMapFirstPass PRIVATE
    ShadowMapFirstPass.cpp
    ShadowMapFirstPass.h
    ShadowMapFirstPass.slang
)

target_copy_shaders(ShadowMapFirstPass RenderPasses/ShadowMapFirstPass)
target_source_group(ShadowMapFirstPass "RenderPasses")
