#ifndef SUIKA_LIGHT_HELPER
#define SUIKA_LIGHT_HELPER

#include "SuikaCommon.hlsl"

///////////////////////////////////////////////////////////////////////////////
//                          Light Helpers                                    //
///////////////////////////////////////////////////////////////////////////////

// ------------------------------------
// Get Main Light
// ------------------------------------
Light GetMainLight(v2f i)
{
    float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
    Light  mainLight = GetMainLight(i.shadowCoord);
    return mainLight;
}

// ------------------------------------
// Get Global Illumination
// ------------------------------------
half3 GlobalIllumination(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData)
{
    half occlusion= 1;
    half3 indirectDiffuse = surfaceData.bakedGI * occlusion;
    half3 irradiance = materialData.diffuse * indirectDiffuse;

    return irradiance;
}

#endif