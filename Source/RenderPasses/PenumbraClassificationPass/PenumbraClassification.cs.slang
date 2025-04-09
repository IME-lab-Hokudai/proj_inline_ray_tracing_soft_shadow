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

Texture2D<PackedHitInfo> vbuffer;//packed vbuffer
RWTexture2D<uint32_t> penumbraMask;

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

[numthreads(16, 16, 1)]
void main(uint3 dispatchThreadId: SV_DispatchThreadID)
{
    uint2 pixel = dispatchThreadId.xy;
    // Trace primary ray.
    //const Ray ray = gScene.camera.computeRayPinhole(pixel, params.frameDim);
    HitInfo hit;
    float hitT = 1e30f;
    hit = unpackHitInfo(vbuffer[pixel]);
    uint32_t mask = 0;//0 is lit or back ground | 1 is umbra | 2 is penumbra
    if (hit.isValid())
    {
        float3 posW = gScene.getVertexData(hit.getTriangleHit()).posW;
       // LightData light = gScene.getLight[0];
    }
    penumbraMask[dispatchThreadId.xy] = 1;
}
