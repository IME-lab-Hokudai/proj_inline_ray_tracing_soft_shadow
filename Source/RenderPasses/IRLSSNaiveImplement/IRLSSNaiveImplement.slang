import Scene.Raster; // Imports defaultVS.
import Scene.RaytracingInline;
import Rendering.Lights.LightHelpers;

SamplerState gSampler;
static const int kNumLightSamples = 32;

cbuffer PerFrameCB
{
    
};

VSOut vsMain(VSIn vIn)
{
    VSOut vsOut = defaultVS(vIn);
    return vsOut;
}

//---------------------------------------------------------------------------------------
// Transforms a normal map sample to world space.
//---------------------------------------------------------------------------------------
float3 NormalSampleToWorldSpace(float3 normalMapSample, float3 unitNormalW, float3 tangentW)
{
    // Uncompress each component from [0,1] to [-1,1].
    float3 normalT = 2.0f * normalMapSample - 1.0f;

    // Build orthonormal basis.
    float3 N = unitNormalW;
    float3 T = normalize(tangentW - dot(tangentW, N) * N);
    float3 B = cross(N, T);

    float3x3 TBN = float3x3(T, B, N);

    // Transform from tangent space to world space.
    float3 bumpedNormalW = mul(normalT, TBN);

    return bumpedNormalW;
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

float4 psMain(VSOut vsOut, uint triangleIndex: SV_PrimitiveID) : SV_TARGET
{
    float3 viewDir = normalize(gScene.camera.getPosition() - vsOut.posW);
    ShadingData shadingData = prepareShadingData(vsOut, triangleIndex, viewDir);
    BasicMaterialData baseColorMat = gScene.materials.getBasicMaterialData(vsOut.materialID);
    float4 baseColorSample = float4(0, 0, 0, 1);
    float4 emissiveSample = float4(0, 0, 0, 1);
    float4 specularSample = float4(0, 0, 0, 1);
    float3 normalSample;
    float3 normalSampleW;
    if (baseColorMat.texBaseColor.getMode() == TextureHandle::Mode::Texture) {
        baseColorSample = gScene.materials.sampleTexture(baseColorMat.texBaseColor, gSampler, vsOut.texC, 0.f);
        emissiveSample = gScene.materials.sampleTexture(baseColorMat.texEmissive, gSampler, vsOut.texC, 0.f);
        specularSample = gScene.materials.sampleTexture(baseColorMat.texSpecular, gSampler, vsOut.texC, 0.f);
        normalSample = gScene.materials.sampleTexture(baseColorMat.texNormalMap, gSampler, vsOut.texC, 0.f).rgb;
        normalSampleW = NormalSampleToWorldSpace(normalSample, normalize(vsOut.normalW), vsOut.tangentW.rgb);
    }
    else {
        baseColorSample = (float4)baseColorMat.baseColor;
        emissiveSample = float4(baseColorMat.emissive,1);
        specularSample = baseColorMat.specular;
        normalSample = normalize(vsOut.normalW);
        normalSampleW = normalSample;
    }

    LightData light = gScene.getLight(0);

    // The light vector aims opposite the direction the light rays travel.
    // float3 lightVec = -dirLightData.dirW;
    float3 lightPos = mul(light.transMat, float4(0, 0, 0, 1.f)).xyz;
    float3 toLightDir = normalize(lightPos - vsOut.posW);

    // ambient
    float3 ambientColor = 0.1 * baseColorSample.rgb;

    // diffuse calculation
    float ndotl = max(dot(toLightDir, normalSampleW), 0.0f);
    float3 diffuseColor = ndotl * baseColorSample.rgb * light.intensity;
    //float3 diffuseColor = baseColorSample.rgb * light.intensity;

    // specular calculation
    const float shininess = 32.f;
    float3 halfVec = normalize(viewDir + toLightDir);
    float ndoth = max(dot(halfVec, normalSampleW), 0.0f);
    float3 specular = pow(ndoth, shininess) * specularSample.rgb * light.intensity;

    // shadow intensity
    int blockedRayCounter = 0;
    Ray ray;
    SceneRayQuery<false> sceneRayQuery;
    ray.origin = vsOut.posW;
    [unroll]
    for (int i = 0; i < kNumLightSamples; i++) {

        float3 lightPos = mul(light.transMat, float4(getRectSampleOffset(i), 1.f)).xyz;
        float3 toLightDir = lightPos - vsOut.posW;
        float3 normToLightDir = normalize(toLightDir);

        ray.dir = normalize(toLightDir);
        ray.tMin = 0.001;
        ray.tMax = length(toLightDir) - 0.01;

        bool isVisible = sceneRayQuery.traceVisibilityRay(ray);
        if (!isVisible) {
            blockedRayCounter++;
        }
    }
     float shadowIntensity = (float)blockedRayCounter / kNumLightSamples;
    //float shadowIntensity = 0.f;
    float3 litColor = ambientColor + (1 - shadowIntensity)*(diffuseColor + specular) + emissiveSample.rgb;
    return float4(litColor,1.0f);
}
