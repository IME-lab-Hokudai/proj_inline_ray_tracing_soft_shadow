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

Texture2D<uint32_t> gInput;    // penumbra mask texture
RWTexture2D<uint32_t> gOutput; // upscale mask texture

[numthreads(16, 16, 1)]
void maxPoolingBasedUpscale(uint3 dispatchThreadId: SV_DispatchThreadID)
{
    uint2 inputRes, outputRes, scale;
    gInput.GetDimensions(inputRes.x, inputRes.y);
    gOutput.GetDimensions(outputRes.x, outputRes.y);
    scale = outputRes / inputRes;

    uint2 upscalePixelCoord = dispatchThreadId.xy;
    uint2 inputPixelCoord = upscalePixelCoord / scale;

    // Clamp inputPixel and its neighbors to stay in bounds
    uint2 ip0 = clamp(inputPixelCoord, uint2(0, 0), inputRes - 1);
    uint2 ip1 = clamp(inputPixelCoord + uint2(1, 0), uint2(0, 0), inputRes - 1);
    uint2 ip2 = clamp(inputPixelCoord + uint2(0, 1), uint2(0, 0), inputRes - 1);
    uint2 ip3 = clamp(inputPixelCoord + uint2(1, 1), uint2(0, 0), inputRes - 1);

    // Sample 2x2 neighborhood
    uint v0 = gInput[ip0];
    uint v1 = gInput[ip1];
    uint v2 = gInput[ip2];
    uint v3 = gInput[ip3];

    // Max pooling: output is 1 if any neighbor is 1
    uint result = max(max(v0, v1), max(v2, v3));
    gOutput[upscalePixelCoord] = result;
}
