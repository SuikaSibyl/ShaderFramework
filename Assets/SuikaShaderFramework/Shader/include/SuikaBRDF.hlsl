#ifndef SUIKA_BRDF
#define SUIKA_BRDF

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

#endif