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
RWTexture2D<uint32_t> penumbraMask;
static const int kNumLightSamples = 9;
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
    // Each cell = 1/3 → half cell = 1/6 ≈ 0.1667
    // First sample center at -0.5 + 1/6 = -0.333...
    float3 offsets[9] = {
        float3(-0.3333f, 0.0f, 0.3333f),
        float3(0.0000f, 0.0f, 0.3333f),
        float3(0.3333f, 0.0f, 0.3333f),
        float3(-0.3333f, 0.0f, 0.0000f),
        float3(0.0000f, 0.0f, 0.0000f),
        float3(0.3333f, 0.0f, 0.0000f),
        float3(-0.3333f, 0.0f, -0.3333f),
        float3(0.0000f, 0.0f, -0.3333f),
        float3(0.3333f, 0.0f, -0.3333f),
    };

    return offsets[index];
}

bool IsValidScreenCoord(uint2 pixelCoord, uint2 frameDim) {
    return !any(pixelCoord >= frameDim);
}

[numthreads(16, 16, 1)]
void main(uint3 dispatchThreadId: SV_DispatchThreadID)
{
    uint2 pixel = dispatchThreadId.xy;
    uint2 frameDim;
    penumbraMask.GetDimensions(frameDim.x, frameDim.y);
    //if (any(pixel >= frameDim))
    //    return;
    if (!IsValidScreenCoord(pixel, frameDim))
        return;
    // Trace primary ray.
    //const Ray ray = gScene.camera.computeRayPinhole(pixel, frameDim);
    HitInfo hit;
    hit = unpackHitInfo(vbuffer[pixel]);
    uint32_t mask = 0; // 0 is lit or back ground | 1 is umbra | 2 is penumbra
    penumbraMask[dispatchThreadId.xy] = 0;//clear default to background
    if (hit.isValid())
    {
        Ray ray;
        VertexData vertexData = gScene.getVertexData(hit.getTriangleHit());
        ray.origin = vertexData.posW;
        LightData light = gScene.getLight(0);
        SceneRayQuery<false> sceneRayQuery;
        if (light.type == (uint)LightType::Rect) {
            GeometryInstanceID instanceID = hit.getInstanceID();
            float3 lightWorldNormal = normalize(mul(light.transMatIT, float4(0.f, 1.f, 0.f, 0.f))).xyz;
            int blockedRayCounter = 0;
            [unroll]
            for (int i = 0; i < kNumLightSamples; i++) {
                float3 lightPos = mul(light.transMat, float4(getRectSampleOffset(i), 1.f)).xyz;
                float3 toLightDir = lightPos - vertexData.posW;
                float3 normToLightDir = normalize(toLightDir);
                
                float NdotL = dot(-normToLightDir, lightWorldNormal);
                if (NdotL <= 0) { // point that not facing the light is umbra
                    if (gScene.getGeometryInstance(instanceID).geometryID == lightRepresentMeshID) //except rect mesh used for light representing
                        break;
                    blockedRayCounter = kNumLightSamples;
                    break;
                }

                ray.dir = normalize(toLightDir);
                ray.tMin = 0.001;
                ray.tMax = length(toLightDir) - 0.01;
                
                bool isVisible = sceneRayQuery.traceVisibilityRay(ray);
                if (!isVisible) {
                    blockedRayCounter++;
                }
            }

            if (blockedRayCounter > 0) {
                //penumbraMask[dispatchThreadId.xy] = (blockedRayCounter < kNumLightSamples) ? 2 : 1;
                if (blockedRayCounter < kNumLightSamples) { // penumbra
                    // Simple 3x3 splat to neighboring pixels
                    for (int dy = -1; dy <= 1; ++dy) {
                        for (int dx = -1; dx <= 1; ++dx)
                        {
                            int2 neighbor = pixel + int2(dx, dy);
                            if (!IsValidScreenCoord(neighbor, frameDim)) continue;

                            // Threadsafely mark as penumbra
                            InterlockedMax(penumbraMask[neighbor], 2u);
                        }
                    }
                }
                else penumbraMask[dispatchThreadId.xy] = 1;
            }
        }
    }
}
