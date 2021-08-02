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

#endif