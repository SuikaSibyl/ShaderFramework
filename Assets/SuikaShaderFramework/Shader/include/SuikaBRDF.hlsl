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
half3 HairLighting(
    SuikaSurfaceData surfaceData,
    SuikaMaterialData materialData,
    Light light, half3 tangent)
{
    float Area = 1;

    // Fetch important infos
    half  ClampedRoughness = materialData.roughness;
    half3 V = surfaceData.viewDirWS;
    half3 L = light.direction;
    half3 N = tangent;
    half3 H = normalize(L + V);
    float dotTH = dot(N, L);
    float sinTH = sqrt(1.0 - dotTH * dotTH);
    float dirAtten = smoothstep(-1.0, 0.0, dot(N, H));
    float res = dirAtten * pow(sinTH, 200);
    float3 ress = float3(dotTH,dotTH,dotTH);

	// N is the vector parallel to hair pointing toward root
	const float VoL       = dot(V,L);
	const float SinThetaL = dot(N,L);
	const float SinThetaV = dot(N,V);
	float CosThetaD = cos( 0.5 * abs( asin( SinThetaV ) - asin( SinThetaL ) ) );

	//CosThetaD = abs( CosThetaD ) < 0.01 ? 0.01 : CosThetaD;

	const float3 Lp = L - SinThetaL * N;
	const float3 Vp = V - SinThetaV * N;
	const float CosPhi = dot(Lp,Vp) * rsqrt( dot(Lp,Lp) * dot(Vp,Vp) + 1e-4 );
	const float CosHalfPhi = sqrt( saturate( 0.5 + 0.5 * CosPhi ) );
	//const float Phi = acosFast( CosPhi );
	
	// 下面很多初始化的值都是基于上面给出的表格获得
	float n = 1.55; // 毛发的折射率
	//float n_prime = sqrt( n*n - 1 + Pow2( CosThetaD ) ) / CosThetaD;
	float n_prime = 1.19 / CosThetaD + 0.36 * CosThetaD;
	
	// 对应R、TT、TRT的longitudinal shift
	float Shift = 0.035;
	float Alpha[] =
	{
		-Shift * 2,
		Shift,
		Shift * 4,
	};
	// 对应R、TT、TRT的longitudinal width
    float pow2rough = pow(2, ClampedRoughness);
	float B[] =
	{
		Area + ( pow2rough ),
		Area + ( pow2rough ) / 2,
		Area + ( pow2rough ) * 2,
	};

	half3 S = 0;
	
	// 下面各分量中的Mp是纵向散射函数，Np是方位角散射函数，Fp是菲涅尔函数，Tp是吸收函数
	
	// // 反射（R）分量
	// if(1)
	// {
	// 	const float sa = sin( Alpha[0] );
	// 	const float ca = cos( Alpha[0] );
	// 	float Shift = 2*sa* ( ca * CosHalfPhi * sqrt( 1 - SinThetaV * SinThetaV ) + sa * SinThetaV );

	// 	float Mp = Hair_g( B[0] * sqrt(2.0) * CosHalfPhi, SinThetaL + SinThetaV - Shift );
	// 	float Np = 0.25 * CosHalfPhi;
	// 	float Fp = Hair_F( sqrt( saturate( 0.5 + 0.5 * VoL ) ) );
	// 	S += Mp * Np * Fp * ( GBuffer.Specular * 2 ) * lerp( 1, Backlit, saturate(-VoL) );
	// }

	// // 透射（TT）分量
	// if(1)
	// {
	// 	float Mp = Hair_g( B[1], SinThetaL + SinThetaV - Alpha[1] );

	// 	float a = 1 / n_prime;
	// 	//float h = CosHalfPhi * rsqrt( 1 + a*a - 2*a * sqrt( 0.5 - 0.5 * CosPhi ) );
	// 	//float h = CosHalfPhi * ( ( 1 - Pow2( CosHalfPhi ) ) * a + 1 );
	// 	float h = CosHalfPhi * ( 1 + a * ( 0.6 - 0.8 * CosPhi ) );
	// 	//float h = 0.4;
	// 	//float yi = asinFast(h);
	// 	//float yt = asinFast(h / n_prime);
		
	// 	float f = Hair_F( CosThetaD * sqrt( saturate( 1 - h*h ) ) );
	// 	float Fp = Pow2(1 - f);
	// 	//float3 Tp = pow( GBuffer.BaseColor, 0.5 * ( 1 + cos(2*yt) ) / CosThetaD );
	// 	//float3 Tp = pow( GBuffer.BaseColor, 0.5 * cos(yt) / CosThetaD );
	// 	float3 Tp = pow( GBuffer.BaseColor, 0.5 * sqrt( 1 - Pow2(h * a) ) / CosThetaD );

	// 	//float t = asin( 1 / n_prime );
	// 	//float d = ( sqrt(2) - t ) / ( 1 - t );
	// 	//float s = -0.5 * PI * (1 - 1 / n_prime) * log( 2*d - 1 - 2 * sqrt( d * (d - 1) ) );
	// 	//float s = 0.35;
	// 	//float Np = exp( (Phi - PI) / s ) / ( s * Pow2( 1 + exp( (Phi - PI) / s ) ) );
	// 	//float Np = 0.71 * exp( -1.65 * Pow2(Phi - PI) );
	// 	float Np = exp( -3.65 * CosPhi - 3.98 );
		
	// 	// Backlit是背光度，由材质提供。
	// 	S += Mp * Np * Fp * Tp * Backlit;
	// }

	// // 次反射（TRT）分量
	// if(1)
	// {
	// 	float Mp = Hair_g( B[2], SinThetaL + SinThetaV - Alpha[2] );
		
	// 	//float h = 0.75;
	// 	float f = Hair_F( CosThetaD * 0.5 );
	// 	float Fp = Pow2(1 - f) * f;
	// 	//float3 Tp = pow( GBuffer.BaseColor, 1.6 / CosThetaD );
	// 	float3 Tp = pow( GBuffer.BaseColor, 0.8 / CosThetaD );

	// 	//float s = 0.15;
	// 	//float Np = 0.75 * exp( Phi / s ) / ( s * Pow2( 1 + exp( Phi / s ) ) );
	// 	float Np = exp( 17 * CosPhi - 16.78 );

	// 	S += Mp * Np * Fp * Tp;
	// }

	// if(1)
	// {
	// 	// Use soft Kajiya Kay diffuse attenuation
	// 	float KajiyaDiffuse = 1 - abs( dot(N,L) );

	// 	float3 FakeNormal = normalize( V - N * dot(V,N) );
	// 	//N = normalize( DiffuseN + FakeNormal * 2 );
	// 	N = FakeNormal;

	// 	// Hack approximation for multiple scattering.
	// 	float Wrap = 1;
	// 	float NoL = saturate( ( dot(N, L) + Wrap ) / Square( 1 + Wrap ) );
	// 	float DiffuseScatter = (1 / PI) * lerp( NoL, KajiyaDiffuse, 0.33 ) * GBuffer.Metallic;
	// 	float Luma = Luminance( GBuffer.BaseColor );
	// 	float3 ScatterTint = pow( GBuffer.BaseColor / Luma, 1 - Shadow );
	// 	S += sqrt( GBuffer.BaseColor ) * DiffuseScatter * ScatterTint;
	// }

	// S = -min(-S, 0.0);

	return ress;

}


#endif