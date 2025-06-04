add_plugin(RayTracingShadow)

target_sources(RayTracingShadow PRIVATE
    RayTracingShadow.cpp
    RayTracingShadow.h
    RayTracingShadow.rt.slang
)
target_copy_shaders(RayTracingShadow RenderPasses/RayTracingShadow)
target_source_group(RayTracingShadow "RenderPasses")
