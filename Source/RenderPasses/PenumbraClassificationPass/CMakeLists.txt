add_plugin(PenumbraClassificationPass)

target_sources(PenumbraClassificationPass PRIVATE
    PenumbraClassificationPass.cpp
    PenumbraClassificationPass.h
)

target_copy_shaders(PenumbraClassificationPass RenderPasses/PenumbraClassificationPass)
target_source_group(PenumbraClassificationPass "RenderPasses")
