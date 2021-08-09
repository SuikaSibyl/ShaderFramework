#ifndef SUIKA_LIGHTING
#define SUIKA_LIGHTING

#include "SuikaLightHelper.hlsl"
#include "SuikaBRDF.hlsl"

// =============================================================
// =============================================================
//                      Suika Lighting
// -------------------------------------------------------------
// It's the 2 layer of Suika Shaderframework.
// In this layer, we use Light X BSDFHandler, to get irradiance.
// We could call different BSDFHandler for different lights.
// -------------------------------------------------------------
// prev: SuikaXXX.shader                    next: SuikaBRDF.hlsl
// =============================================================
// =============================================================


///////////////////////////////////////////////////////////////////////////////
//                            Suika Lighting                                 //
///////////////////////////////////////////////////////////////////////////////

// ------------------------------------
// Standard Lit Irradiance
// ------------------------------------
half3 StandardLitIrradiance(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData,
    v2f i)
{
    // Init irradiance with GI
    // -----------------------------
    half3 irradiance = GlobalIllumination(surfaceData, materialData);

    // Update irradiance with Emission Lights
    // -----------------------------
    irradiance += surfaceData.emission;

    // Update irradiance with Main Light
    // -----------------------------
    Light mainLight = GetMainLight(i);
    irradiance += PhysicalBasedLighting(surfaceData, materialData, mainLight);

    // Update irradiance with Additional Lights
    // -----------------------------
    half4 shadowMask = unity_ProbesOcclusion;
    uint additionalLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < additionalLightCount; lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, i.positionWS, shadowMask);
        irradiance += PhysicalBasedLighting(surfaceData, materialData, light);
    }

    return irradiance;
}

///////////////////////////////////////////////////////////////////////////////
//                            Suika Lighting                                 //
///////////////////////////////////////////////////////////////////////////////
// ------------------------------------
// BTDF Lit Irradiance
// ------------------------------------
half3 BTDFIrradiance(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData,
    v2f i,
    half thickness,
    half ambientStrength,
    half attenuationSpeed,
    half distortion,
    half scaling)
{
    // Init irradiance with GI
    // -----------------------------
    half3 irradiance = half3(0, 0, 0);

    // Update irradiance with Main Light
    // -----------------------------
    Light mainLight = GetMainLight(i);
    irradiance += BTDFLighting(surfaceData, materialData, mainLight, thickness,
                    ambientStrength, attenuationSpeed, distortion, scaling);

    // Update irradiance with Additional Lights
    // -----------------------------
    half4 shadowMask = unity_ProbesOcclusion;
    uint additionalLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < additionalLightCount; lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, i.positionWS, shadowMask);
        irradiance += BTDFLighting(surfaceData, materialData, light, thickness,
                    ambientStrength, attenuationSpeed, distortion, scaling);
    }

    return irradiance;
}

///////////////////////////////////////////////////////////////////////////////
//                            Suika Lighting                                 //
///////////////////////////////////////////////////////////////////////////////

// ------------------------------------
// Hair Irradiance
// ------------------------------------
half3 HairIrradiance(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData,
    v2f i, half3 tangent, half3 bitangent)
{
    // Init irradiance with GI
    // -----------------------------
    half3 irradiance = GlobalIllumination(surfaceData, materialData);

    // Update irradiance with Emission Lights
    // -----------------------------
    irradiance += surfaceData.emission;

    // Update irradiance with Main Light
    // -----------------------------
    Light mainLight = GetMainLight(i);
    irradiance += HairLighting(surfaceData, materialData, mainLight, tangent, bitangent);

    // Update irradiance with Additional Lights
    // -----------------------------
    half4 shadowMask = unity_ProbesOcclusion;
    uint additionalLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < additionalLightCount; lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, i.positionWS, shadowMask);
        irradiance += HairLighting(surfaceData, materialData, light, tangent, bitangent);
    }

    return irradiance;
}

///////////////////////////////////////////////////////////////////////////////
//                            Suika Lighting                                 //
///////////////////////////////////////////////////////////////////////////////
// ------------------------------------
// Hair Irradiance
// ------------------------------------
half3 SkinIrradiance(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData,
    v2f i, half4 skinmap, sampler2D lutmap)
{
    // Init irradiance with GI
    // -----------------------------
    half3 irradiance = GlobalIllumination(surfaceData, materialData);

    // Update irradiance with Emission Lights
    // -----------------------------
    irradiance += surfaceData.emission;

    // Update irradiance with Main Light
    // -----------------------------
    Light mainLight = GetMainLight(i);
    irradiance += SkinLighting(surfaceData, materialData, mainLight, skinmap, lutmap);

    // Update irradiance with Additional Lights
    // -----------------------------
    half4 shadowMask = unity_ProbesOcclusion;
    uint additionalLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < additionalLightCount; lightIndex++)
    {
        Light light = GetAdditionalLight(lightIndex, i.positionWS, shadowMask);
        irradiance += SkinLighting(surfaceData, materialData, light, skinmap, lutmap);
    }

    return irradiance;
}

#endif