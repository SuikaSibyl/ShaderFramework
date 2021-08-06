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
    half3 L = light.direction;
    half3 T = normalize(tangent);
	half3 N = T;
    half3 H = normalize(L + V);
    float dotTH = dot(T, H);
    float sinTH = sqrt(1.0 - dotTH * dotTH);
    float dirAtten = smoothstep(-1.0, 0.0, dot(T, H));
    float res = dirAtten * pow(sinTH, 2000);
    float3 ress = float3(res,res,res);

	float materialF90 = clamp(50.0 * materialData.specular.g, 0.0, 1.0);

	half3 diffuseOut;
	half3 specularOut;
	bool lighted;

	half3 normalWS = true? surfaceData.normalWS:-surfaceData.normalWS;
	half3 dotNL = dot(normalWS, light.direction);
	float anisotropy = 1;
	half4 PrecomputeGGX = precomputeGGX(N, V, materialData.roughness);
	computeLightLambertGGXAnisotropy(
		normalWS, V, dotNL, 
		PrecomputeGGX, materialData.diffuse, materialData.specular, 
		light.distanceAttenuation, light.color, light.direction, 
		materialF90, tangent, binormal,  anisotropy, 
		diffuseOut, specularOut, lighted);
	half shadow = light.shadowAttenuation;
	half uSubsurfaceTranslucencyThicknessFactor = 0;
	half3 uSubsurfaceTranslucencyColor = half3(1, 0.4120, 0.0465);
	half uSubsurfaceTranslucencyFactor = 1;
	half shadowDistance = 1;
	half3 sss = computeLightSSS(dotNL, light.distanceAttenuation,
		uSubsurfaceTranslucencyThicknessFactor, uSubsurfaceTranslucencyColor, uSubsurfaceTranslucencyFactor,
		shadowDistance, materialData.diffuse, light.color);
	return (diffuseOut + specularOut) * shadow;

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
	
	// UE's approximation of Marschner model
	// Use Gaussian distribution to approximate Mp Term.
	// The Alpha shift values used for three cases are different.
	// Here are the longitudinal shifts for R、TT、TRT:
	float Shift = 0.035;
	float Alpha[] =
	{
		-Shift * 2,
		Shift,
		Shift * 4,
	};

	// Also, Beta values are also different
	// And it's related to roughness.
	// 对应R、TT、TRT的longitudinal width
    float Area = 0;
	half  ClampedRoughness = materialData.roughness;
    float pow2roughness = ClampedRoughness * ClampedRoughness;
	float B[] =
	{
		Area + ( pow2roughness ),
		Area + ( pow2roughness ) / 2,
		Area + ( pow2roughness ) * 2,
	};

	half3 S = 0;
	
	// 下面各分量中的Mp是纵向散射函数，Np是方位角散射函数，Fp是菲涅尔函数，Tp是吸收函数
		//const float3 DiffuseN	= OctahedronToUnitVector( GBuffer.CustomData.xy * 2 - 1 );
	// const float Backlit	= min(InBacklit, HairTransmittance.bUseBacklit ? GBuffer.CustomData.z : 1);
	float Backlit = 0;

	// ------------------------------------
	// Case 1 : R
	// ------------------------------------
	{
		const float sa = sin(Alpha[0]);
		const float ca = cos(Alpha[0]);
		float Shift = 2*sa* ( ca * CosHalfPhi * sqrt( 1 - SinThetaV * SinThetaV ) + sa * SinThetaV );
		float BScale = sqrt(2.0) * CosHalfPhi;
		float Mp = Hair_g(B[0] * BScale, SinThetaL + SinThetaV - Shift);
		// Np is the N term
		float Np = 0.25 * CosHalfPhi;
		// Fp is the Fresnel Term 
		float Fp = Hair_F(sqrt(saturate(0.5 + 0.5 * VoL)));
		S +=  Fp * (materialData.specular * 2) * lerp(1, Backlit, saturate(-VoL));
	}

	// 透射（TT）分量
	if(1)
	{
		float Mp = Hair_g( B[1], SinThetaL + SinThetaV - Alpha[1] );

		float a = 1 / n_prime;
		//float h = CosHalfPhi * rsqrt( 1 + a*a - 2*a * sqrt( 0.5 - 0.5 * CosPhi ) );
		//float h = CosHalfPhi * ( ( 1 - Pow2( CosHalfPhi ) ) * a + 1 );
		float h = CosHalfPhi * ( 1 + a * ( 0.6 - 0.8 * CosPhi ) );
		//float h = 0.4;
		//float yi = asinFast(h);
		//float yt = asinFast(h / n_prime);
		
		float f = Hair_F( CosThetaD * sqrt( saturate( 1 - h*h ) ) );
		float Fp = Pow2(1 - f);
		//float3 Tp = pow( GBuffer.BaseColor, 0.5 * ( 1 + cos(2*yt) ) / CosThetaD );
		//float3 Tp = pow( GBuffer.BaseColor, 0.5 * cos(yt) / CosThetaD );
		float3 Tp = pow( materialData.albedo, 0.5 * sqrt( 1 - Pow2(h * a) ) / CosThetaD );

		//float t = asin( 1 / n_prime );
		//float d = ( sqrt(2) - t ) / ( 1 - t );
		//float s = -0.5 * PI * (1 - 1 / n_prime) * log( 2*d - 1 - 2 * sqrt( d * (d - 1) ) );
		//float s = 0.35;
		//float Np = exp( (Phi - PI) / s ) / ( s * Pow2( 1 + exp( (Phi - PI) / s ) ) );
		//float Np = 0.71 * exp( -1.65 * Pow2(Phi - PI) );
		float Np = exp( -3.65 * CosPhi - 3.98 );
		
		// Backlit是背光度，由材质提供。
		S += Mp * Np * Fp * Tp * Backlit;
	}

	// 次反射（TRT）分量
	if(1)
	{
		float Mp = Hair_g( B[2], SinThetaL + SinThetaV - Alpha[2] );
		
		//float h = 0.75;
		float f = Hair_F( CosThetaD * 0.5 );
		float Fp = Pow2(1 - f) * f;
		//float3 Tp = pow( GBuffer.BaseColor, 1.6 / CosThetaD );
		float3 Tp = pow( materialData.albedo, 0.8 / CosThetaD );

		//float s = 0.15;
		//float Np = 0.75 * exp( Phi / s ) / ( s * Pow2( 1 + exp( Phi / s ) ) );
		float Np = exp( 17 * CosPhi - 16.78 );

		S += Mp * Np * Fp * Tp;
	}


	// // Diffuse Term
	// // ----------------------
	// // {
	// 	// Use soft Kajiya Kay diffuse attenuation
	// 	float KajiyaDiffuse = 1 - abs( dot(N,L) );

	// 	float3 FakeNormal = normalize( V - N * dot(V,N) );
	// 	// //N = normalize( DiffuseN + FakeNormal * 2 );
	// 	N = FakeNormal;

	// 	// Hack approximation for multiple scattering.
	// 	float Wrap = 1;
	// 	float NoL = saturate( ( dot(N, L) + Wrap ) / ( (1 + Wrap)*(1 + Wrap) ) );
	// 	float DiffuseScatter = (1. / 3.1415926) * lerp( NoL, KajiyaDiffuse, 0.33 ) * 0.5;
	// 	float Luma = Luminance( materialData.albedo );
	// 	// // *******************
	// 	float Shadow = 1;
	// 	float3 ScatterTint = pow( materialData.albedo / Luma, 1 - Shadow );
	// 	S += sqrt( materialData.albedo ) * DiffuseScatter * ScatterTint;
	// // }

	S = max(S, 0.0);

	return diffuseOut + S * light.color;

}


#endif