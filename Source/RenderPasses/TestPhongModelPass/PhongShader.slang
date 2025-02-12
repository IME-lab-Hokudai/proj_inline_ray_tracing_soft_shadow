import Scene.Raster; // Imports defaultVS.

SamplerState gSampler;

cbuffer PerFrameCB
{
    float4 gColor;
};

VSOut vsMain(VSIn vIn)
{
    return defaultVS(vIn);
}

float4 psMain(VSOut vsOut, uint triangleIndex: SV_PrimitiveID) : SV_TARGET
{
    float3 viewDir = normalize(gScene.camera.getPosition() - vsOut.posW);
    //ShadingData shadingData = prepareShadingData(vsOut, triangleIndex, viewDir);
    BasicMaterialData baseColor = gScene.materials.getBasicMaterialData(vsOut.materialID);
    float4 color = gScene.materials.sampleTexture(baseColor.texBaseColor, gSampler, vsOut.texC, 0.f);
    return color;
}
