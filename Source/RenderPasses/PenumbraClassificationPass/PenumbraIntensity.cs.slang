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

/**
 * Simple Post FX
 *
 * applies vignette, chromatic aberration, barrel distortion, brightness-dependant (de)saturation, offset/scale/power tint per pixel
 *
 * also applies bloom which is an energy preserving weighted sum of 'gaussians' plus an optional star shape.
 * the bloom is calculated by creating an image pyramid fine to coarse, using a 10x10 binomial kernel (implemented via 5x5 bilinear taps)
 * the downsampling kernel needs to be quite wide to avoid aliasing artefacts
 * after 8 downsampling steps (so that the final PSF is quite wide - at least 64*10 pixels diameter), we upsample coarse to fine,
 * at each level blending a small fraction (the 'bloom amount') of the coarser layer with the 'current' layer.
 * in this way, the final kernel is a blend of gaussians with doubling variance, plus a spike at the middle.
 * optionally, 6 star like lobes are added by brute force line sampling.
 */
#include "Utils/HostDeviceShared.slangh"
#include "Utils/Math/MathConstants.slangh"

import Scene.RaytracingInline;
import Utils.Math.Ray;

cbuffer PerFrameCB
{
    uint lightRepresentMeshID;
};

Texture2D<PackedHitInfo> vbuffer;//packed vbuffer
Texture2D<uint32_t> penumbraMask;
RWTexture2D<float32_t> penumbraIntensity; //0 is lit/background | 1 is umbra | (0,1) is penumbra
static const int kNumLightSamples = 32;

static float3 getPosW(const float3 orig, const float3 dir, const HitInfo hit)
{
    switch (hit.getType())
    {
    case HitType::Triangle:
        return gScene.getVertexData(hit.getTriangleHit()).posW;
    case HitType::DisplacedTriangle:
        return gScene.getVertexData(hit.getDisplacedTriangleHit(), -dir).posW;
    case HitType::Curve:
        return gScene.getVertexDataFromCurve(hit.getCurveHit()).posW;
    case HitType::SDFGrid:
        {
        return gScene.getVertexDataFromSDFGrid(hit.getSDFGridHit(), orig, dir).posW;
    }
    default:
        // Should not happen. Return the origin.
        return orig;
    }
}

float3 getRectSampleOffset(uint index)
{
    float3 offsets[32] = {
        float3(-0.4375f, 0.0f, 0.3750f),
    float3(-0.3125f, 0.0f, 0.3750f),
    float3(-0.1875f, 0.0f, 0.3750f),
        float3(-0.0625f, 0.0f, 0.3750f),
    float3(0.0625f, 0.0f, 0.3750f),
    float3(0.1875f, 0.0f, 0.3750f),
        float3(0.3125f, 0.0f, 0.3750f),
    float3(0.4375f, 0.0f, 0.3750f),

        float3(-0.4375f, 0.0f, 0.1250f),
    float3(-0.3125f, 0.0f, 0.1250f),
    float3(-0.1875f, 0.0f, 0.1250f),
        float3(-0.0625f, 0.0f, 0.1250f),
    float3(0.0625f, 0.0f, 0.1250f),
    float3(0.1875f, 0.0f, 0.1250f),
        float3(0.3125f, 0.0f, 0.1250f),
    float3(0.4375f, 0.0f, 0.1250f),

        float3(-0.4375f, 0.0f, -0.1250f),
    float3(-0.3125f, 0.0f, -0.1250f),
    float3(-0.1875f, 0.0f, -0.1250f),
        float3(-0.0625f, 0.0f, -0.1250f),
    float3(0.0625f, 0.0f, -0.1250f),
    float3(0.1875f, 0.0f, -0.1250f),
        float3(0.3125f, 0.0f, -0.1250f),
    float3(0.4375f, 0.0f, -0.1250f),

        float3(-0.4375f, 0.0f, -0.3750f),
    float3(-0.3125f, 0.0f, -0.3750f),
    float3(-0.1875f, 0.0f, -0.3750f),
        float3(-0.0625f, 0.0f, -0.3750f),
    float3(0.0625f, 0.0f, -0.3750f),
    float3(0.1875f, 0.0f, -0.3750f),
        float3(0.3125f, 0.0f, -0.3750f),
    float3(0.4375f, 0.0f, -0.3750f),
    };
    return offsets[index];
}

[numthreads(16, 16, 1)]
void main(uint3 dispatchThreadId: SV_DispatchThreadID)
{
    uint2 pixel = dispatchThreadId.xy;
    uint2 frameDim;
    penumbraMask.GetDimensions(frameDim.x, frameDim.y);
    if (any(pixel >= frameDim))
        return;

    penumbraIntensity[pixel] = 0.f; //to clear previous frame value

    if (penumbraMask[pixel] == 0) { // lit or background
        penumbraIntensity[pixel] = 0.f; // lit or background
        return;
    }
    if (penumbraMask[pixel] == 1) { // umbra
        penumbraIntensity[pixel] = 1.f;
        return;
    }

    //*** casting rays for penumbra
    HitInfo hit;
    hit = unpackHitInfo(vbuffer[pixel]);
    uint32_t mask = 0; // 0 is lit or back ground | 1 is umbra | 2 is penumbra
    if (hit.isValid())
    {
        Ray ray;
        VertexData vertexData = gScene.getVertexData(hit.getTriangleHit());
        ray.origin = vertexData.posW;
        LightData light = gScene.getLight(0);
        SceneRayQuery<false> sceneRayQuery;
        if (light.type == (uint)LightType::Rect) {
            int blockedRayCounter = 0;
            [unroll]
            for (int i = 0; i < kNumLightSamples; i++) {
                float3 lightPos = mul(light.transMat, float4(getRectSampleOffset(i), 1.f)).xyz;
                float3 toLightDir = lightPos - vertexData.posW;
              
                ray.dir = normalize(toLightDir);
                ray.tMin = 0.001;
                ray.tMax = length(toLightDir) - 0.01;
                
                bool isVisible = sceneRayQuery.traceVisibilityRay(ray);
                if (!isVisible) {
                    blockedRayCounter++;
                }
            }
            penumbraIntensity[pixel] = (float)blockedRayCounter / kNumLightSamples;
        }
    }
}
