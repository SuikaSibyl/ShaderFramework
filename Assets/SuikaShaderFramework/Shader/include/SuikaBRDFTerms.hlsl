#ifndef _SUIKA_BRDF_TERMS_
#define _SUIKA_BRDF_TERMS_

// =============================================================
// =============================================================
//                      Suika BRDF Terms
// -------------------------------------------------------------
// It's the 4 layer of Suika Shaderframework.
// In this layer, we write some functions to support BSDFs
// -------------------------------------------------------------
// prev: SuikaBRDF.shader                               next: -
// =============================================================
// =============================================================

half3 fresnelSchlick(float cosTheta, half3 F0)
{
    return F0 + (1.0 - F0) * pow(1.0 - cosTheta, 5.0);
}

half DistributionGGX(half3 N, half3 H, float roughness)
{
    half a      = roughness*roughness;
    half a2     = a*a;
    half NdotH  = max(dot(N, H), 0.0);
    half NdotH2 = NdotH*NdotH;

    half nom   = a2;
    half denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = 3.141592653 * denom * denom;

    return nom / denom;
}

half GeometrySchlickGGX(half NdotV, half roughness)
{
    half r = (roughness + 1.0);
    half k = (r*r) / 8.0;

    half nom   = NdotV;
    half denom = NdotV * (1.0 - k) + k;

    return nom / denom;
}

half GeometrySmith(half3 N, half3 V, half3 L, half roughness)
{
    half NdotV = max(dot(N, V), 0.0);
    half NdotL = max(dot(N, L), 0.0);
    half ggx2  = GeometrySchlickGGX(NdotV, roughness);
    half ggx1  = GeometrySchlickGGX(NdotL, roughness);

    return ggx1 * ggx2;
}

///////////////////////////////////////////////////////////////////////////////
//                              Hair Terms                                   //
///////////////////////////////////////////////////////////////////////////////
half4 precomputeGGX(const in half3 normal, const in half3 eyeVector, const in half roughness) {
    float NoV = clamp(dot(normal, eyeVector), 0., 1.);
    float r2 = roughness * roughness;
    return half4(r2, r2 * r2, NoV, NoV * (1.0 - r2));
}

half D_GGX_Anisotropic(const half at, const half ab, const half ToH, const half BoH, const half NoH)
{
    half a2 = at * ab;
    half3 d = half3(ab * ToH, at * BoH, a2 * NoH);
    half x = a2 / dot(d, d);
    return a2 * (x * x) / 3.141593;
}

half V_SmithGGXCorrelated_Anisotropic(half at, half ab, half ToV, half BoV, half ToL, half BoL, half NoV, half NoL)
{
    half lambdaV = NoL * length(half3(at * ToV, ab * BoV, NoV));
    half lambdaL = NoV * length(half3(at * ToL, ab * BoL, NoL));
    return 0.5 / (lambdaV + lambdaL);
}

half3 F_Schlick(const half3 f0, const float f90, const in float VoH) {
    float VoH5 = pow(1.0 - VoH, 5.0);
    return f90 * VoH5 + (1.0 - VoH5) * f0;
}

half3 anisotropicLobe(
const half4 precomputeGGX, const half3 normal, const half3 eyeVector, 
const half3 eyeLightDir, const half3 specular, const half NoL, const float f90, 
const in half3 anisotropicT, const in half3 anisotropicB, const in half anisotropy) {
    half3 H = normalize(eyeVector + eyeLightDir);
    float NoH = clamp(dot(normal, H), 0., 1.);
    float NoV = clamp(dot(normal, eyeVector), 0., 1.);
    float VoH = clamp(dot(eyeLightDir, H), 0., 1.);
    float ToV = dot(anisotropicT, eyeVector);
    float BoV = dot(anisotropicB, eyeVector);
    float ToL = dot(anisotropicT, eyeLightDir);
    float BoL = dot(anisotropicB, eyeLightDir);
    float ToH = dot(anisotropicT, H);
    float BoH = dot(anisotropicB, H);
    float aspect = sqrt(1.0 - abs(anisotropy) * 0.9);
    if (anisotropy > 0.0) aspect = 1.0 / aspect;
    float at = precomputeGGX.x * aspect;
    float ab = precomputeGGX.x / aspect;
    float D = D_GGX_Anisotropic(at, ab, ToH, BoH, NoH);
    float V = V_SmithGGXCorrelated_Anisotropic(at, ab, ToV, BoV, ToL, BoL, NoV, NoL);
    half3 F = F_Schlick(specular, f90, VoH);
    return (D * V * 3.141593) * F;
}

void computeLightLambertGGXAnisotropy(
const in half3 normal, const in half3 eyeVector, const in half NoL, 
const in half4 precomputeGGX, const in half3 diffuse, const in half3 specular, 
const in float attenuation, const in half3 lightColor, const in half3 eyeLightDir, 
const in float f90, const in half3 anisotropicT, const in half3 anisotropicB,  const in float anisotropy, 
out half3 diffuseOut, out half3 specularOut, out bool lighted) 
{
    lighted = NoL > 0.0;
    if (lighted == false) {
        specularOut = diffuseOut = half3(0.0, 0.0, 0.0);
        return;
    }
    half3 colorAttenuate = attenuation * NoL * lightColor;
    specularOut = colorAttenuate * anisotropicLobe(precomputeGGX, normal, eyeVector, eyeLightDir, specular, NoL, f90, anisotropicT, anisotropicB, anisotropy);
    diffuseOut = colorAttenuate * diffuse;
}

half3 computeLightSSS(
const in float dotNL, const in float attenuation, const in float thicknessFactor, 
const in half3 translucencyColor, const in float translucencyFactor, 
const in float shadowDistance, const in half3 diffuse, const in half3 lightColor) {
    float wrap = clamp(0.3 - dotNL, 0., 1.);
    float thickness = max(0.0, shadowDistance / max(0.001, thicknessFactor));
          thickness = 2;
    float finalAttenuation = translucencyFactor * attenuation * wrap;
    return finalAttenuation * lightColor * diffuse * exp(-thickness / max(translucencyColor, half3(0.001,0.001,0.001)));
}
#endif