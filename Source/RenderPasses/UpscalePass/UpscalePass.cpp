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
#include "UpscalePass.h"

namespace
{
const char kSrc[] = "src";
const char kUpscaleDst[] = "upscaleDst";
const char kUpscalePassShaderFile[] = "RenderPasses/UpscalePass/UpScale.cs.slang";
} // namespace

extern "C" FALCOR_API_EXPORT void registerPlugin(Falcor::PluginRegistry& registry)
{
    registry.registerClass<RenderPass, UpscalePass>();
}

UpscalePass::UpscalePass(ref<Device> pDevice, const Properties& props) : RenderPass(pDevice)
{
    Sampler::Desc linearSamplerDesc;
    linearSamplerDesc.setFilterMode(TextureFilteringMode::Linear, TextureFilteringMode::Linear, TextureFilteringMode::Linear);
    mpLinearSampler = mpDevice->createSampler(linearSamplerDesc);
}

Properties UpscalePass::getProperties() const
{
    return {};
}

RenderPassReflection UpscalePass::reflect(const CompileData& compileData)
{
    // Define the required resources here
    RenderPassReflection reflector;
    reflector.addInput(kSrc, "Input texture").format(ResourceFormat::R32Float);
    reflector.addOutput(kUpscaleDst, "Upscale texture")
        .bindFlags(ResourceBindFlags::RenderTarget | ResourceBindFlags::UnorderedAccess | ResourceBindFlags::ShaderResource)
        .format(ResourceFormat::R32Float)
        .texture2D(compileData.defaultTexDims.x, compileData.defaultTexDims.y);
    return reflector;
}

void UpscalePass::execute(RenderContext* pRenderContext, const RenderData& renderData)
{
    if (mpScene)
    {
        // upscale pass
        const auto& input = renderData.getTexture(kSrc);
        const auto& pUpscaleOutput = renderData.getTexture(kUpscaleDst);
        ShaderVar var = mpUpscalePass->getRootVar();
        var["gInput"] = input;
        var["gOutput"] = pUpscaleOutput;
        var["gSampler"] = mpLinearSampler;
        mpUpscalePass->execute(pRenderContext, uint3(pUpscaleOutput->getWidth(), pUpscaleOutput->getHeight(), 1));
    }
}

void UpscalePass::setScene(RenderContext* pRenderContext, const ref<Scene>& pScene)
{
    mpScene = pScene;
    if (mpScene)
    {
        ProgramDesc upscalePassdesc;
        upscalePassdesc.addShaderModules(mpScene->getShaderModules());
        upscalePassdesc.addShaderLibrary(kUpscalePassShaderFile).csEntry("bilinearUpscale");
        upscalePassdesc.addTypeConformances(mpScene->getTypeConformances());

        DefineList upscalePassDefines = mpScene->getSceneDefines();
        mpUpscalePass = ComputePass::create(mpDevice, upscalePassdesc, upscalePassDefines);
    }
}


void UpscalePass::renderUI(Gui::Widgets& widget) {}
