add_plugin(PenumbraClassificationPass)

target_sources(PenumbraClassificationPass PRIVATE
    PenumbraClassificationPassShared.hlsli
    PenumbraClassificationPass.cpp
    PenumbraClassificationPass.h
    PenumbraClassification.cs.slang
    UpScale.cs.slang
	PenumbraIntensity.cs.slang
)

target_copy_shaders(PenumbraClassificationPass RenderPasses/PenumbraClassificationPass)
target_source_group(PenumbraClassificationPass "RenderPasses")
