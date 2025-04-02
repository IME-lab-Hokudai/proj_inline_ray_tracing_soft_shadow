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
const char kShaderFile[] = "RenderPasses/PenumbraClassificationPass/PenumbraClassification.cs.slang";
} // namespace

extern "C" FALCOR_API_EXPORT void registerPlugin(Falcor::PluginRegistry& registry)
{
    registry.registerClass<RenderPass, PenumbraClassificationPass>();
}

PenumbraClassificationPass::PenumbraClassificationPass(ref<Device> pDevice, const Properties& props) : RenderPass(pDevice) {}

Properties PenumbraClassificationPass::getProperties() const
{
    return {};
}

RenderPassReflection PenumbraClassificationPass::reflect(const CompileData& compileData)
{
    // Define the required resources here
    RenderPassReflection reflector;
   if (compileData.connectedResources.getFieldCount() > 0)
   {
       const RenderPassReflection::Field* edge = compileData.connectedResources.getField(kSrc);
        uint32_t srcWidth = edge->getWidth();
        uint32_t srcHeight = edge->getHeight();
        ResourceFormat fmt = edge->getFormat();
        reflector.addOutput(kDst, "Masking texture classify umbra/penumbra")
            .bindFlags(ResourceBindFlags::RenderTarget | ResourceBindFlags::UnorderedAccess | ResourceBindFlags::ShaderResource)
            .format(ResourceFormat::R32Uint)
            .texture2D(srcWidth, srcHeight);
        reflector.addInput(kSrc, "Input Vbuffer")
            .format(fmt)
            .texture2D(srcWidth, srcHeight);
   }
   else
   {
       reflector.addInput(kSrc, "Vbuffer");
       reflector.addOutput(kDst, "Masking texture classify umbra/penumbra");
   }
    return reflector;
}

void PenumbraClassificationPass::execute(RenderContext* pRenderContext, const RenderData& renderData)
{
    // renderData holds the requested resources
    // auto& pTexture = renderData.getTexture("src");
}

void PenumbraClassificationPass::renderUI(Gui::Widgets& widget) {}
