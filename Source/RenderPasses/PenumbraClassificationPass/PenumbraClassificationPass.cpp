/***************************************************************************
 # Copyright (c) 2015-23, NVIDIA CORPORATION. All rights reserved.
 #
 # Redistribution and use in source and binary forms, with or without
 # modification, are permitted provided that the following conditions
 # are met:
 #  * Redistributions of source code must retain the above copyright
 #    notice, this list of conditions and the following disclaimer.
 #  * Redistributions in binary form must reproduce the above copyright
 #    notice, this list of conditions and the following disclaimer in the
 #    documentation and/or other materials provided with the distribution.
 #  * Neither the name of NVIDIA CORPORATION nor the names of its
 #    contributors may be used to endorse or promote products derived
 #    from this software without specific prior written permission.
 #
 # THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS "AS IS" AND ANY
 # EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 # IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 # PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 # CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 # EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 # PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 # PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 # OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 # (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 # OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 **************************************************************************/
#include "PenumbraClassificationPass.h"

namespace
{
const char kSrc[] = "src";
const char kDst[] = "dst";
//const char kUpscaleDst[] = "upscaleDst";
const char kIntenisyDst[] = "penumbraIntensity";
const char kClassifyPassShaderFile[] = "RenderPasses/PenumbraClassificationPass/PenumbraClassification.cs.slang";
const char kIntensityCalculationShaderFile[] = "RenderPasses/PenumbraClassificationPass/PenumbraIntensity.cs.slang";
//const char kUpscalePassShaderFile[] = "RenderPasses/PenumbraClassificationPass/UpScale.cs.slang";
const char kOutputSize[] = "outputSize";
const char kFixedOutputSize[] = "fixedOutputSize";
} // namespace

extern "C" FALCOR_API_EXPORT void registerPlugin(Falcor::PluginRegistry& registry)
{
    registry.registerClass<RenderPass, PenumbraClassificationPass>();
}

PenumbraClassificationPass::PenumbraClassificationPass(ref<Device> pDevice, const Properties& props) : RenderPass(pDevice)
{
    for (const auto& [key, value] : props)
    {
        if (key == kOutputSize) mOutputSizeSelection = value;
        else if (key == kFixedOutputSize) mFixedOutputSize = value;
    }
    
    //mpSampleGenerator = SampleGenerator::create(mpDevice, SAMPLE_GENERATOR_TINY_UNIFORM);
    //Sampler::Desc linearSamplerDesc;
    //linearSamplerDesc.setFilterMode(TextureFilteringMode::Linear, TextureFilteringMode::Linear, TextureFilteringMode::Linear);

    //mpLinearSampler = mpDevice->createSampler(linearSamplerDesc);
}

Properties PenumbraClassificationPass::getProperties() const
{
    Properties props;
    props[kOutputSize] = mOutputSizeSelection;
    if (mOutputSizeSelection == RenderPassHelpers::IOSize::Fixed)
        props[kFixedOutputSize] = mFixedOutputSize;
    return props;
}

RenderPassReflection PenumbraClassificationPass::reflect(const CompileData& compileData)
{
    // Define the required resources here
    RenderPassReflection reflector;
    const uint2 sz = RenderPassHelpers::calculateIOSize(mOutputSizeSelection, mFixedOutputSize, compileData.defaultTexDims);
    reflector.addInput(kSrc, "Input Vbuffer").format(ResourceFormat::RGBA32Uint);
    reflector.addOutput(kDst, "Masking texture (at lower res half/quarter) classify umbra/penumbra")
                      .bindFlags(ResourceBindFlags::RenderTarget | ResourceBindFlags::UnorderedAccess | ResourceBindFlags::ShaderResource)
                      .format(ResourceFormat::R32Uint)
                      .texture2D(sz.x,sz.y);

    reflector.addOutput(kIntenisyDst, "Shadow intensity")
                      .bindFlags(ResourceBindFlags::RenderTarget | ResourceBindFlags::UnorderedAccess | ResourceBindFlags::ShaderResource)
                      .format(ResourceFormat::R32Float)
                      .texture2D(sz.x,sz.y);
    return reflector;
}

void PenumbraClassificationPass::compile(RenderContext* pRenderContext, const CompileData& compileData)
{
   
}

void PenumbraClassificationPass::execute(RenderContext* pRenderContext, const RenderData& renderData)
{
    if (mpScene)
    {
        // renderData holds the requested resources
        const auto& pCoarseClassifyOutput = renderData.getTexture(kDst);
        const auto& pVBuffer = renderData.getTexture(kSrc);

        //coarse classification pass
        ShaderVar var = mpCoarseClassificationPass->getRootVar();
        var["vbuffer"] = pVBuffer;
        var["penumbraMask"] = pCoarseClassifyOutput;
        var["PerFrameCB"]["lightRepresentMeshID"] = mpRectLight->getMeshID();
        mpScene->bindShaderDataForRaytracing(pRenderContext, var["gScene"]);
        mpCoarseClassificationPass->execute(pRenderContext, uint3(pCoarseClassifyOutput->getWidth(), pCoarseClassifyOutput->getHeight(), 1));

        //intensity pass
        const auto& pPenumbraIntensityOutput = renderData.getTexture(kIntenisyDst);
        var = mpIntensityCalculationPass->getRootVar();
        var["vbuffer"] = pVBuffer;
        var["penumbraMask"] = pCoarseClassifyOutput;
        var["penumbraIntensity"] = pPenumbraIntensityOutput;
        mpScene->bindShaderDataForRaytracing(pRenderContext, var["gScene"]);
        mpIntensityCalculationPass->execute(
            pRenderContext, uint3(pPenumbraIntensityOutput->getWidth(), pPenumbraIntensityOutput->getHeight(), 1)
        );

    }
}

void PenumbraClassificationPass::renderUI(Gui::Widgets& widget)
{
    // Controls for output size.var["gScene"]
    // When output size requirements change, we'll trigger a graph recompile to update the render pass I/O sizes.
    if (widget.dropdown("Output size", mOutputSizeSelection))
        requestRecompile();
    if (mOutputSizeSelection == RenderPassHelpers::IOSize::Fixed)
    {
        if (widget.var("Size in pixels", mFixedOutputSize, 32u, 16384u))
            requestRecompile();
    }
}

void PenumbraClassificationPass::setScene(RenderContext* pRenderContext, const ref<Scene>& pScene)
{
    mpScene = pScene;
    if (mpScene)
    {
        // Prepare our programs for the scene.
        ProgramDesc classifyPassDesc;
        classifyPassDesc.addShaderModules(mpScene->getShaderModules());
        classifyPassDesc.addShaderLibrary(kClassifyPassShaderFile).csEntry("main");
        classifyPassDesc.addTypeConformances(mpScene->getTypeConformances());
        //classifyPassDesc.compilerFlags = SlangCompilerFlags::DumpIntermediates;
        DefineList classifyPassDefines = mpScene->getSceneDefines();
        mpCoarseClassificationPass = ComputePass::create(mpDevice, classifyPassDesc, classifyPassDefines);

        ProgramDesc intensityPassdesc;
        intensityPassdesc.addShaderModules(mpScene->getShaderModules());
        intensityPassdesc.addShaderLibrary(kIntensityCalculationShaderFile).csEntry("main");
        intensityPassdesc.addTypeConformances(mpScene->getTypeConformances());

        DefineList intensityPassDefines = mpScene->getSceneDefines();
        mpIntensityCalculationPass = ComputePass::create(mpDevice, intensityPassdesc, intensityPassDefines);

        mpRectLight = static_ref_cast<AnalyticAreaLight>(mpScene->getLight(0));
    }
}
