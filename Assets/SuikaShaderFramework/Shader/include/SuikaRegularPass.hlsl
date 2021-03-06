#ifndef SUIKA_REGULAR_PASS
#define SUIKA_REGULAR_PASS

#include "include/SuikaCommon.hlsl"
#include "include/SuikaLitInput.hlsl"
#include "include/SuikaLighting.hlsl"

// =============================================================
// =============================================================
//                      Suika Lighting
// -------------------------------------------------------------
// It's the 1.5 layer of Suika Shaderframework.
// In this layer, we define the Basic Regular Pass HLSL Funcs
// -------------------------------------------------------------
// prev: SuikaXXX.shader                    next: SuikaBRDF.hlsl
// =============================================================
// =============================================================

v2f VertexReguluarLit (appdata v)
{
    v2f o;
    RegularVertexInit(v, o);
    return o;
}

half4 FragmentRegularLit (v2f i) : SV_Target
{
    // Data Initialization
    SuikaSurfaceData  surfaceData  = InitializeSuikaSurfaceData(i);
    SuikaMaterialData materialData = InitializeSuikaMaterialData(i);
    // Use the standard way to get irradiance
    half3 irradiance = StandardLitIrradiance(surfaceData, materialData, i);
    return half4(irradiance, 1.0);
}

#endif