#ifndef SUIKA_BRDF
#define SUIKA_BRDF

#include "SuikaCommon.hlsl"
#include "SuikaBRDFTerms.hlsl"

// =============================================================
// =============================================================
//                      Suika BRDF
// -------------------------------------------------------------
// It's the 3 layer of Suika Shaderframework.
// In this layer, we handle a single light, by defining the BSDF.
// We give a BSDF Handler to response a fragment & a light.
// -------------------------------------------------------------
// prev: SuikaLighting.shader          next: SuikaBRDFTerms.hlsl
// =============================================================
// =============================================================


///////////////////////////////////////////////////////////////////////////////
//                                Basic BRDF                                 //
///////////////////////////////////////////////////////////////////////////////
half SpecularTermWithoutF(
    half3 L, half3 V, half3 N, 
    half roughness)
{
    // Specular Part
    // -----------------------------------
    half3   halfDir = SafeNormalize(L + V);
    float   NdotH = saturate(dot(N, halfDir));
    half    LdotH = saturate(dot(L, halfDir));
    
    // GGX法线分布函数D项分母（没有算平方）
    float roughness2 = roughness * roughness;
    float roughness2MinusOne = roughness2 - 1;
    float normalizationTerm = roughness * 4.0 + 2.0;
    float d = NdotH * NdotH * roughness2MinusOne + 1.00001f;
    // CookTorrance可见性V项的分母
    half LdotH2 = LdotH * LdotH;
    // 最终高光项
    half specularTerm = roughness2 / ((d * d) * max(0.1h, LdotH2) * normalizationTerm);
    specularTerm = specularTerm - HALF_MIN;
    specularTerm = clamp(specularTerm, 0.0, 100.0);
    return specularTerm;
}

half3 PhysicalBasedLighting(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData,
    Light light)
{
    // Get Radiance part
    // -----------------------------
    half NdotL = saturate(dot(surfaceData.normalWS, light.direction));
    half lightAttenuation = light.distanceAttenuation * light.shadowAttenuation;
    half3 radiance = light.color * lightAttenuation * NdotL;

    // Get BRDF part
    // -----------------------------
    // Diffuse Term
    half3 brdf = materialData.diffuse;
    // Specular Term
    half SpecularTerm = SpecularTermWithoutF(
        light.direction, surfaceData.viewDirWS, 
        surfaceData.normalWS, materialData.roughness);
    brdf += SpecularTerm * materialData.specular;
    
    // Return Irradiance, namely radiance x brdf
    // -----------------------------
    return radiance * brdf;
}

///////////////////////////////////////////////////////////////////////////////
//                                 BTDF                                      //
///////////////////////////////////////////////////////////////////////////////
// ------------------------------------
// BTDF Lighting
// ------------------------------------
half3 BTDFLighting(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData,
    Light light,
    half thickness,
    half ambientStrength,
    half attenuationSpeed,
    half distortion,
    half scaling)
{
    // -----------------------------
    half NdotL = saturate(dot(surfaceData.normalWS, light.direction));
    half lightAttenuation = light.distanceAttenuation;
    half3 LTLight = light.direction + surfaceData.normalWS * distortion;
    half  fLTDot = pow(saturate(dot(surfaceData.viewDirWS, - LTLight)), attenuationSpeed) * scaling;
    half3 fLT = lightAttenuation * (fLTDot + ambientStrength) * thickness;
    // -----------------------------
    return light.color * fLT * materialData.diffuse;
}

///////////////////////////////////////////////////////////////////////////////
//                               Hair Handler                                //
///////////////////////////////////////////////////////////////////////////////

inline float Pow2(float x)
{
	return (x*x);
}

float Hair_g(float B, float Theta)
{
	return exp(-0.5 * Pow2(Theta) / (B * B)) / (sqrt(2 * 3.1415926) * B);
}

float Hair_F(float CosTheta)
{
	const float n = 1.55;
	const float F0 = Pow2((1 - n) / (1 + n));
	return F0 + (1 - F0) * pow(1 - CosTheta, 5);
}

half3 HairLighting(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData,
    Light light, half3 tangent, half3 binormal)
{
    // Fetch important infos
    half3 V = surfaceData.viewDirWS;

	half3 diffuseOut;
	half3 specularOut;
	bool lighted;

	// Use GGX Anisotropy Model from Sketchfab
	// --------------------------------------------
	half3 normalWS = surfaceData.normalWS;
	half3 dotNL = dot(normalWS, light.direction);
	float anisotropy = 1;
	half4 PrecomputeGGX = precomputeGGX(normalWS, V, max(0.045, materialData.roughness));

	// materialData.specular = half3(1,1,1);
	float materialF90 = clamp(50.0 * materialData.specular.g, 0.0, 1.0);
	computeLightLambertGGXAnisotropy(
		normalWS, V, dotNL, 
		PrecomputeGGX, materialData.diffuse, materialData.specular, 
		light.distanceAttenuation, light.color, light.direction, 
		materialF90, tangent, binormal, anisotropy, 
		diffuseOut, specularOut, lighted);
	half shadow = light.shadowAttenuation;

	// Shadow would effect diffuse
	diffuseOut  *= shadow;
	specularOut *= shadow * surfaceData.occlusion;

	// Add effect of transmittance
	half uSubsurfaceTranslucencyThicknessFactor = 0;
	half3 uSubsurfaceTranslucencyColor = half3(1, 0.4120, 0.0465);
	half uSubsurfaceTranslucencyFactor = 1;
	half shadowDistance = light.shadowAttenuation;
	diffuseOut += computeLightSSS(dotNL, light.distanceAttenuation,
		uSubsurfaceTranslucencyThicknessFactor, uSubsurfaceTranslucencyColor, uSubsurfaceTranslucencyFactor,
		shadowDistance, materialData.diffuse, light.color);


	return diffuseOut + specularOut;
}


half3 SkinLighting(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData,
    Light light, half4 skinmap, sampler2D lutmap)
{
	// Get translucent
	half materialTranslucency = skinmap.r;
	half shadowDistance = light.shadowAttenuation;
	half dotNL = dot(surfaceData.normalWS, light.direction);
	half3 uSubsurfaceTranslucencyColor = half3(1, 0.1199, 0.0637);
	half uSubsurfaceTranslucencyThicknessFactor = 3.9992;
	half3 translucent = computeLightSSS(dotNL, light.distanceAttenuation, 
		uSubsurfaceTranslucencyThicknessFactor, uSubsurfaceTranslucencyColor, 
		materialTranslucency, shadowDistance, materialData.diffuse, light.color);

	// Get Lut
	dotNL = dotNL * 0.5 + 0.5;
	half3 lut = tex2D(lutmap, half2(dotNL, 1 - skinmap.r));

	// Get Radiance part
    // -----------------------------
    half lightAttenuation = light.distanceAttenuation * light.shadowAttenuation;
    half3 radiance = light.color * lightAttenuation * lut;

    // Get BRDF part
    // -----------------------------
    // Diffuse Term
    half3 brdf = materialData.diffuse;
    // Specular Term
    half SpecularTerm = SpecularTermWithoutF(
        light.direction, surfaceData.viewDirWS, 
        surfaceData.normalWS, materialData.roughness + 0.2);
    brdf += SpecularTerm * materialData.specular;
    
    // Return Irradiance, namely radiance x brdf
    // -----------------------------
    return radiance * brdf + translucent;
}

#endif